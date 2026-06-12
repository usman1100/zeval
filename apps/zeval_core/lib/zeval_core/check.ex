defmodule ZevalCore.Check do
  @moduledoc """
  The check engine — the heart of Zeval.

  Determines whether a subject has a particular relation on an object by
  recursively evaluating the namespace's rewrite rules against the tuple
  store.

  Returns a resolution path showing every step taken and whether each
  rule allowed or denied access.
  """

  alias ZevalCore.Namespace
  alias ZevalCore.Tuples

  @max_depth 25

  @type result :: %{allowed: boolean(), path: list()}
  @type resolution_step :: map()

  @doc """
  Checks whether `subject` has `relation` on `object_id` within `namespace`
  for the given `tenant_id`.

  ## Options

    * `:consistency` — a zookie token for read-your-writes consistency
    * `:visited` — an initial MapSet for cycle detection (used internally)

  Returns `%{allowed: boolean(), path: [resolution_step()]}`.
  """
  @spec check(binary(), String.t(), String.t(), String.t(), term(), keyword()) :: result()
  def check(tenant_id, namespace, object_id, relation, subject, opts \\ []) do
    start = System.monotonic_time()

    state = %{
      tenant_id: tenant_id,
      zookie: Keyword.get(opts, :consistency),
      visited: Keyword.get(opts, :visited, MapSet.new()),
      path: [],
      depth: 0,
      # Per-request memo of tuple reads keyed by filter. The zookie is fixed
      # for the request, so reads are stable — this collapses the repeated
      # lookups that union/intersection branches would otherwise each issue.
      reads: %{}
    }

    result =
      case do_check(state, namespace, object_id, relation, subject) do
        {allowed, final_state} ->
          %{allowed: allowed, path: final_state.path |> Enum.reverse()}
      end

    duration = System.monotonic_time() - start

    :telemetry.execute(
      [:zeval, :check, :stop],
      %{duration: duration},
      %{
        tenant_id: tenant_id,
        namespace: namespace,
        object_id: object_id,
        relation: relation,
        allowed: result.allowed,
        depth: state.depth
      }
    )

    result
  end

  # ============================================================================
  # Recursive resolver
  # ============================================================================

  defp do_check(state, namespace, object_id, relation, subject) do
    key = {namespace, object_id, relation, subject}

    if MapSet.member?(state.visited, key) do
      # Cycle detected — deny this branch
      step = %{
        rule: "cycle",
        relation: relation,
        allowed: false,
        namespace: namespace,
        object: object_id
      }

      {false, append_path(state, step)}
    else
      state = %{state | visited: MapSet.put(state.visited, key)}

      if state.depth >= @max_depth do
        step = %{
          rule: "max_depth_exceeded",
          depth: state.depth,
          allowed: false
        }

        {false, append_path(state, step)}
      else
        state = %{state | depth: state.depth + 1}

        case Namespace.get(state.tenant_id, namespace) do
          {:ok, config} ->
            rule = get_relation_rule(config.config, relation)

            case rule do
              nil ->
                step = %{
                  rule: "undefined_relation",
                  relation: relation,
                  allowed: false,
                  namespace: namespace,
                  object: object_id
                }

                {false, append_path(state, step)}

              validated_rule ->
                eval_rule(validated_rule, state, namespace, object_id, relation, subject)
            end

          {:error, :not_found} ->
            step = %{
              rule: "undefined_namespace",
              namespace: namespace,
              object: object_id,
              relation: relation,
              allowed: false
            }

            {false, append_path(state, step)}
        end
      end
    end
  end

  # ============================================================================
  # Rule evaluation
  # ============================================================================

  # -- this -------------------------------------------------------------------

  defp eval_rule(%{"this" => _}, state, ns, obj, rel, subject) do
    filter = %{namespace: ns, object_id: obj, relation: rel, subject: subject}
    {found, state} = cached_read(state, filter)
    allowed = found != []

    step = %{
      rule: "this",
      namespace: ns,
      object: obj,
      relation: rel,
      allowed: allowed
    }

    {allowed, append_path(state, step)}
  end

  # -- computed_userset -------------------------------------------------------

  defp eval_rule(
         %{"computed_userset" => %{"relation" => target_rel}},
         state,
         ns,
         obj,
         _rel,
         subject
       ) do
    {allowed, final_state} = do_check(state, ns, obj, target_rel, subject)

    step = %{
      rule: "computed_userset",
      namespace: ns,
      object: obj,
      relation: target_rel,
      allowed: allowed
    }

    {allowed, append_path(final_state, step)}
  end

  # -- tuple_to_userset --------------------------------------------------------

  defp eval_rule(
         %{
           "tuple_to_userset" => %{
             "tupleset_relation" => ts_rel,
             "computed_userset_relation" => cu_rel
           }
         },
         state,
         ns,
         obj,
         _rel,
         subject
       ) do
    # Step 1: find all tuples linking this object to parents via ts_rel
    filter = %{namespace: ns, object_id: obj, relation: ts_rel}
    {parent_tuples, state} = cached_read(state, filter)

    # Step 2: for each parent tuple that is a userset, check cu_rel on that parent
    {allowed, final_state} =
      Enum.reduce_while(parent_tuples, {false, state}, fn parent_tuple,
                                                          {_acc_allowed, acc_state} ->
        case parent_tuple.subject do
          {:userset, parent_ns, parent_obj, _parent_rel} ->
            {child_allowed, child_state} =
              do_check(acc_state, parent_ns, parent_obj, cu_rel, subject)

            child_step = %{
              rule: "tuple_to_userset_child",
              namespace: parent_ns,
              object: parent_obj,
              relation: cu_rel,
              via_relation: ts_rel,
              allowed: child_allowed
            }

            updated_state = append_path(child_state, child_step)

            if child_allowed do
              {:halt, {true, updated_state}}
            else
              {:cont, {false, updated_state}}
            end

          _ ->
            # Skip non-userset subjects (direct user tuples on a tupleset_relation
            # don't make sense here)
            {:cont, {false, acc_state}}
        end
      end)

    step = %{
      rule: "tuple_to_userset",
      namespace: ns,
      object: obj,
      relation: cu_rel,
      via_relation: ts_rel,
      allowed: allowed,
      parents_found: length(parent_tuples)
    }

    {allowed, append_path(final_state, step)}
  end

  # -- union ------------------------------------------------------------------

  defp eval_rule(%{"union" => children}, state, ns, obj, rel, subject) do
    {allowed, final_state, child_steps} =
      Enum.reduce_while(children, {false, state, []}, fn child_rule,
                                                         {_acc_allowed, acc_state, acc_children} ->
        {child_allowed, child_state} = eval_rule(child_rule, acc_state, ns, obj, rel, subject)

        child_step = %{
          rule: child_rule_type(child_rule),
          allowed: child_allowed
        }

        if child_allowed do
          {:halt, {true, child_state, [child_step | acc_children]}}
        else
          {:cont, {false, child_state, [child_step | acc_children]}}
        end
      end)

    step = %{
      rule: "union",
      relation: rel,
      allowed: allowed,
      children: Enum.reverse(child_steps)
    }

    {allowed, append_path(final_state, step)}
  end

  # -- intersection -----------------------------------------------------------

  defp eval_rule(%{"intersection" => children}, state, ns, obj, rel, subject) do
    {all_allowed, final_state, child_steps} =
      Enum.reduce(children, {true, state, []}, fn child_rule,
                                                  {acc_allowed, acc_state, acc_children} ->
        {child_allowed, child_state} = eval_rule(child_rule, acc_state, ns, obj, rel, subject)

        child_step = %{
          rule: child_rule_type(child_rule),
          allowed: child_allowed
        }

        {acc_allowed && child_allowed, child_state, [child_step | acc_children]}
      end)

    step = %{
      rule: "intersection",
      relation: rel,
      allowed: all_allowed,
      children: Enum.reverse(child_steps)
    }

    {all_allowed, append_path(final_state, step)}
  end

  # -- exclusion --------------------------------------------------------------

  defp eval_rule(
         %{"exclusion" => %{"base" => base, "subtract" => subtract}},
         state,
         ns,
         obj,
         rel,
         subject
       ) do
    {base_allowed, state_after_base} = eval_rule(base, state, ns, obj, rel, subject)

    {subtract_allowed, final_state} = eval_rule(subtract, state_after_base, ns, obj, rel, subject)

    allowed = base_allowed and not subtract_allowed

    step = %{
      rule: "exclusion",
      relation: rel,
      allowed: allowed,
      children: [
        %{rule: "base", allowed: base_allowed},
        %{rule: "subtract", allowed: subtract_allowed}
      ]
    }

    {allowed, append_path(final_state, step)}
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp get_relation_rule(config, relation) when is_map(config) do
    case config do
      %{"relations" => %{^relation => rule}} -> rule
      _ -> nil
    end
  end

  defp get_relation_rule(_, _), do: nil

  defp zookie_opts(state) do
    case state.zookie do
      nil -> []
      token -> [consistency: token]
    end
  end

  # Read-through memo: identical filters within one check resolve to one query.
  defp cached_read(state, filter) do
    case Map.fetch(state.reads, filter) do
      {:ok, cached} ->
        {cached, state}

      :error ->
        result = Tuples.read(state.tenant_id, filter, zookie_opts(state))
        {result, %{state | reads: Map.put(state.reads, filter, result)}}
    end
  end

  defp append_path(state, step) do
    %{state | path: [step | state.path]}
  end

  defp child_rule_type(%{"this" => _}), do: "this"
  defp child_rule_type(%{"computed_userset" => _}), do: "computed_userset"
  defp child_rule_type(%{"tuple_to_userset" => _}), do: "tuple_to_userset"
  defp child_rule_type(%{"union" => _}), do: "union"
  defp child_rule_type(%{"intersection" => _}), do: "intersection"
  defp child_rule_type(%{"exclusion" => _}), do: "exclusion"
  defp child_rule_type(_), do: "unknown"
end
