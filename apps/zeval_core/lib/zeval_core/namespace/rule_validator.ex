defmodule ZevalCore.Namespace.RuleValidator do
  @moduledoc """
  Recursive structural validator for namespace rewrite rules.

  Six rule types are supported:

    - `this` — direct relation tuple lookup
    - `computed_userset` — recursive check via another relation
    - `tuple_to_userset` — traverse userset links then check
    - `union` — any child rule passes
    - `intersection` — all child rules must pass
    - `exclusion` — base passes, subtract does not pass

  Also detects circular computed_userset chains.
  """

  @type rule :: %{required(String.t()) => term()}
  @type validation_result :: {:ok, rule()} | {:error, String.t()}

  @doc """
  Validates a single rewrite rule. Returns `{:ok, rule}` or `{:error, reason}`.
  """
  @spec validate(map()) :: validation_result()
  def validate(%{} = rule) when map_size(rule) == 0, do: {:error, "empty rule"}

  def validate(%{"this" => %{}}), do: {:ok, %{"this" => %{}}}
  def validate(%{"this" => _}), do: {:error, "\"this\" rule expects an empty object: {}"}

  def validate(%{"computed_userset" => %{"relation" => rel}}) when is_binary(rel) do
    {:ok, %{"computed_userset" => %{"relation" => rel}}}
  end

  def validate(%{"computed_userset" => _}) do
    {:error, "\"computed_userset\" expects {\"relation\": \"<name>\"}"}
  end

  def validate(%{
        "tuple_to_userset" => %{
          "tupleset_relation" => ts_rel,
          "computed_userset_relation" => cu_rel
        }
      })
      when is_binary(ts_rel) and is_binary(cu_rel) do
    {:ok,
     %{
       "tuple_to_userset" => %{
         "tupleset_relation" => ts_rel,
         "computed_userset_relation" => cu_rel
       }
     }}
  end

  def validate(%{"tuple_to_userset" => _}) do
    {:error,
     "\"tuple_to_userset\" expects {\"tupleset_relation\": \"...\", \"computed_userset_relation\": \"...\"}"}
  end

  def validate(%{"union" => []}), do: {:error, "\"union\" requires at least one child rule"}

  def validate(%{"union" => children}) when is_list(children) do
    validate_children(children, "union")
  end

  def validate(%{"union" => _}) do
    {:error, "\"union\" expects a list of child rules"}
  end

  def validate(%{"intersection" => []}),
    do: {:error, "\"intersection\" requires at least one child rule"}

  def validate(%{"intersection" => children}) when is_list(children) do
    validate_children(children, "intersection")
  end

  def validate(%{"intersection" => _}) do
    {:error, "\"intersection\" expects a list of child rules"}
  end

  def validate(%{"exclusion" => %{"base" => base, "subtract" => subtract}}) do
    with {:ok, base} <- validate(base),
         {:ok, subtract} <- validate(subtract) do
      {:ok, %{"exclusion" => %{"base" => base, "subtract" => subtract}}}
    end
  end

  def validate(%{"exclusion" => _}) do
    {:error, "\"exclusion\" expects {\"base\": <rule>, \"subtract\": <rule>}"}
  end

  def validate(%{}) do
    {:error, "unknown or malformed rewrite rule"}
  end

  def validate(_), do: {:error, "rule must be a JSON object"}

  # -- helpers --

  defp validate_children(children, type) when is_list(children) do
    case Enum.reduce_while(children, {:ok, []}, fn child, {:ok, acc} ->
           case validate(child) do
             {:ok, validated} -> {:cont, {:ok, [validated | acc]}}
             {:error, reason} -> {:halt, {:error, "#{type}: #{reason}"}}
           end
         end) do
      {:ok, reversed} -> {:ok, %{type => Enum.reverse(reversed)}}
      {:error, _} = err -> err
    end
  end

  @doc """
  Validates an entire namespace config and also checks for circular
  computed_userset chains between relations.
  """
  @spec validate_config(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_config(%{"name" => name, "relations" => relations})
      when is_binary(name) and is_map(relations) do
    with {:ok, validated_relations} <- validate_relations(relations),
         :ok <- detect_cycles(name, validated_relations) do
      {:ok, %{"name" => name, "relations" => validated_relations}}
    end
  end

  def validate_config(_),
    do: {:error, "config must have \"name\" (string) and \"relations\" (object)"}

  defp validate_relations(relations) when is_map(relations) do
    Enum.reduce_while(relations, {:ok, %{}}, fn {rel_name, rule}, {:ok, acc} ->
      with {:ok, validated} <- validate(rule) do
        {:cont, {:ok, Map.put(acc, rel_name, validated)}}
      else
        {:error, reason} -> {:halt, {:error, "relation \"#{rel_name}\": #{reason}"}}
      end
    end)
  end

  # Cycle detection: DFS over computed_userset edges.
  # If any relation's computed_userset chain loops back to itself, reject.
  defp detect_cycles(_config_name, relations) do
    # Build adjacency: relation_name -> [target relations via computed_userset]
    edges =
      Enum.reduce(relations, %{}, fn {rel_name, rule}, acc ->
        targets = computed_userset_targets(rule)
        Map.put(acc, rel_name, targets)
      end)

    visited = %{}

    case dfs_cached(edges, visited, Enum.map(relations, &elem(&1, 0))) do
      {:cycle, cycle_path} ->
        cycle_str = Enum.join(cycle_path, " -> ")
        {:error, "circular computed_userset reference detected: #{cycle_str}"}

      :ok ->
        :ok
    end
  end

  defp computed_userset_targets(%{"computed_userset" => %{"relation" => rel}}), do: [rel]

  defp computed_userset_targets(%{"union" => children}),
    do: Enum.flat_map(children, &computed_userset_targets/1)

  defp computed_userset_targets(%{"intersection" => children}),
    do: Enum.flat_map(children, &computed_userset_targets/1)

  defp computed_userset_targets(%{"exclusion" => %{"base" => b, "subtract" => s}}),
    do: computed_userset_targets(b) ++ computed_userset_targets(s)

  defp computed_userset_targets(_), do: []

  defp dfs_cached(_edges, _visited, []), do: :ok

  defp dfs_cached(edges, visited, [node | rest]) do
    if Map.has_key?(visited, node) do
      dfs_cached(edges, visited, rest)
    else
      case dfs_visit(edges, visited, node, [node]) do
        {:cycle, _} = cycle ->
          cycle

        new_visited ->
          dfs_cached(edges, new_visited, rest)
      end
    end
  end

  defp dfs_visit(edges, visited, node, path) do
    targets = Map.get(edges, node, [])

    Enum.reduce_while(targets, {:ok, visited}, fn target, {:ok, vis} ->
      if target in path do
        {:halt, {:cycle, Enum.reverse([target | path])}}
      else
        if Map.has_key?(vis, target) do
          {:cont, {:ok, vis}}
        else
          case dfs_visit(edges, vis, target, [target | path]) do
            {:cycle, _} = cycle -> {:halt, cycle}
            new_vis -> {:cont, {:ok, new_vis}}
          end
        end
      end
    end)
    |> case do
      {:cycle, _} = cycle -> cycle
      {:ok, new_visited} -> Map.put(new_visited, node, true)
    end
  end
end
