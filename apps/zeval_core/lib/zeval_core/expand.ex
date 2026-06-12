defmodule ZevalCore.Expand do
  @moduledoc """
  Resolves the full set of subjects that have a given relation on an object.

  Unlike `Check`, which answers a boolean for a specific subject, Expand
  returns **everyone** who has access. The result is a tree that mirrors
  the namespace's rewrite rules.

  Useful for "who has access to this doc?" queries and the playground's
  debug view.
  """

  alias ZevalCore.Namespace
  alias ZevalCore.Tuples

  @max_depth 25

  @type expand_tree :: map()

  @doc """
  Expands the full set of subjects who have `relation` on `object_id`
  within `namespace` for the given `tenant_id`.

  Returns a tree whose leaves contain the direct user IDs.
  """
  @spec expand(binary(), String.t(), String.t(), String.t(), keyword()) :: expand_tree()
  def expand(tenant_id, namespace, object_id, relation, opts \\ []) do
    state = %{
      tenant_id: tenant_id,
      zookie: Keyword.get(opts, :consistency),
      visited: Keyword.get(opts, :visited, MapSet.new()),
      depth: 0
    }

    do_expand(state, namespace, object_id, relation)
  end

  # ============================================================================
  # Recursive expander
  # ============================================================================

  defp do_expand(state, namespace, object_id, relation) do
    key = {namespace, object_id, relation}

    if MapSet.member?(state.visited, key) do
      # Cycle detected — return empty leaf
      %{
        relation: relation,
        object: "#{namespace}:#{object_id}",
        type: :leaf,
        users: []
      }
    else
      state = %{state | visited: MapSet.put(state.visited, key)}

      if state.depth >= @max_depth do
        %{
          relation: relation,
          object: "#{namespace}:#{object_id}",
          type: :leaf,
          users: []
        }
      else
        state = %{state | depth: state.depth + 1}

        case Namespace.get(state.tenant_id, namespace) do
          {:ok, config} ->
            rule = get_relation_rule(config.config, relation)

            case rule do
              nil ->
                %{
                  relation: relation,
                  object: "#{namespace}:#{object_id}",
                  type: :leaf,
                  users: []
                }

              validated_rule ->
                expand_rule(validated_rule, state, namespace, object_id, relation)
            end

          {:error, :not_found} ->
            %{
              relation: relation,
              object: "#{namespace}:#{object_id}",
              type: :leaf,
              users: []
            }
        end
      end
    end
  end

  # ============================================================================
  # Rule expansion
  # ============================================================================

  # -- this -------------------------------------------------------------------

  defp expand_rule(%{"this" => _}, state, ns, obj, rel) do
    filter = %{namespace: ns, object_id: obj, relation: rel}
    opts = zookie_opts(state)
    tuples = Tuples.read(state.tenant_id, filter, opts)

    users =
      tuples
      |> Enum.filter(fn t -> subject_type(t) == :user end)
      |> Enum.map(fn t -> user_id(t) end)
      |> Enum.uniq()

    %{
      relation: rel,
      object: "#{ns}:#{obj}",
      type: :leaf,
      users: users
    }
  end

  # -- computed_userset -------------------------------------------------------

  defp expand_rule(%{"computed_userset" => %{"relation" => target_rel}}, state, ns, obj, _rel) do
    do_expand(state, ns, obj, target_rel)
  end

  # -- tuple_to_userset -------------------------------------------------------

  defp expand_rule(
         %{
           "tuple_to_userset" => %{
             "tupleset_relation" => ts_rel,
             "computed_userset_relation" => cu_rel
           }
         },
         state,
         ns,
         obj,
         _rel
       ) do
    filter = %{namespace: ns, object_id: obj, relation: ts_rel}
    opts = zookie_opts(state)
    parent_tuples = Tuples.read(state.tenant_id, filter, opts)

    children =
      parent_tuples
      |> Enum.filter(fn t -> subject_type(t) == :userset end)
      |> Enum.reduce([], fn t, acc ->
        {:userset, parent_ns, parent_obj, _parent_rel} = subject_tuple(t)

        child_tree = do_expand(state, parent_ns, parent_obj, cu_rel)
        [child_tree | acc]
      end)
      |> Enum.reverse()

    # Collect direct user tuples on the tupleset_relation too
    direct_users =
      parent_tuples
      |> Enum.filter(fn t -> subject_type(t) == :user end)
      |> Enum.map(fn t -> user_id(t) end)
      |> Enum.uniq()

    all_users = merge_user_lists(children, direct_users)

    %{
      relation: cu_rel,
      object: "#{ns}:#{obj}",
      type: :union,
      users: all_users,
      children: children
    }
  end

  # -- union ------------------------------------------------------------------

  defp expand_rule(%{"union" => children}, state, ns, obj, rel) do
    results =
      children
      |> Enum.map(fn child_rule ->
        expand_rule(child_rule, state, ns, obj, rel)
      end)

    all_users =
      results
      |> Enum.flat_map(fn tree -> flatten_users(tree) end)
      |> Enum.uniq()

    %{
      relation: rel,
      object: "#{ns}:#{obj}",
      type: :union,
      users: all_users,
      children: results
    }
  end

  # -- intersection -----------------------------------------------------------

  defp expand_rule(%{"intersection" => children}, state, ns, obj, rel) do
    results =
      children
      |> Enum.map(fn child_rule ->
        expand_rule(child_rule, state, ns, obj, rel)
      end)

    case results do
      [] ->
        %{relation: rel, object: "#{ns}:#{obj}", type: :intersection, users: [], children: []}

      [first | rest] ->
        common_users =
          rest
          |> Enum.reduce(MapSet.new(flatten_users(first)), fn child_tree, acc ->
            MapSet.intersection(acc, MapSet.new(flatten_users(child_tree)))
          end)
          |> MapSet.to_list()

        %{
          relation: rel,
          object: "#{ns}:#{obj}",
          type: :intersection,
          users: common_users,
          children: results
        }
    end
  end

  # -- exclusion --------------------------------------------------------------

  defp expand_rule(
         %{"exclusion" => %{"base" => base, "subtract" => subtract}},
         state,
         ns,
         obj,
         rel
       ) do
    base_tree = expand_rule(base, state, ns, obj, rel)
    subtract_tree = expand_rule(subtract, state, ns, obj, rel)

    base_users = MapSet.new(flatten_users(base_tree))
    subtract_users = MapSet.new(flatten_users(subtract_tree))

    remaining = MapSet.difference(base_users, subtract_users) |> MapSet.to_list()

    %{
      relation: rel,
      object: "#{ns}:#{obj}",
      type: :exclusion,
      users: remaining,
      children: [base_tree, subtract_tree]
    }
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

  defp subject_type(%{subject: {:user, _}}), do: :user
  defp subject_type(%{subject: {:userset, _, _, _}}), do: :userset
  defp subject_type(_), do: :unknown

  defp user_id(%{subject: {:user, uid}}), do: uid
  defp user_id(_), do: nil

  defp subject_tuple(%{subject: {:userset, ns, oid, rel}}), do: {:userset, ns, oid, rel}
  defp subject_tuple(_), do: nil

  # Flatten all user IDs from a tree (recurses into children)
  defp flatten_users(tree) do
    direct = Map.get(tree, :users, [])
    children = Map.get(tree, :children, [])

    child_users = Enum.flat_map(children, &flatten_users/1)
    direct ++ child_users
  end

  # Merge users from children trees + direct users, deduplicated
  defp merge_user_lists(children_trees, direct_users) do
    child_users = Enum.flat_map(children_trees, &flatten_users/1)
    (child_users ++ direct_users) |> Enum.uniq()
  end
end
