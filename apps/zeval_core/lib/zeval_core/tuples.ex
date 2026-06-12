defmodule ZevalCore.Tuples do
  @moduledoc """
  Public API for managing relation tuples.

  Every operation is scoped to a tenant. Writes and deletes return a
  zookie (consistency token) that can be used for read-your-writes
  semantics on subsequent reads.
  """

  import Ecto.Query, warn: false
  alias ZevalCore.Repo
  alias ZevalCore.Tuples.{Tuple, RelationTuple, Zookie}

  require Logger

  @default_limit 1_000
  @max_limit 10_000

  @doc """
  Writes one or more relation tuples. Accepts `%Tuple{}` structs or
  raw maps. Returns `{:ok, zookie}` with the number of written tuples
  in metadata.

  Silently skips tuples that already exist (inserted_at set, deleted_at
  null) — this is an idempotent write operation.
  """
  @spec write(binary(), [Tuple.t() | map()]) :: {:ok, map()} | {:error, term()}
  def write(tenant_id, tuples) when is_list(tuples) do
    Repo.transaction(fn ->
      count =
        tuples
        |> Enum.map(&to_relation_tuple_attrs/1)
        |> Enum.reduce(0, fn attrs, acc ->
          full_attrs = Map.put(attrs, :tenant_id, tenant_id)

          # on_conflict: :nothing makes writes idempotent against the partial
          # unique indexes — a duplicate active tuple inserts 0 rows.
          case Repo.insert_all(RelationTuple, [full_attrs], on_conflict: :nothing) do
            {1, _} -> acc + 1
            _ -> acc
          end
        end)

      {:ok, zookie} = Zookie.mint(tenant_id)

      # Emit telemetry for Watch endpoint
      :telemetry.execute([:zeval, :tuples, :written], %{count: count}, %{tenant_id: tenant_id})

      %{written: count, zookie: zookie.token}
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Soft-deletes tuples matching the given filters. Accepts `%Tuple{}`
  structs or maps. Only active tuples (deleted_at IS NULL) are affected.

  Returns `{:ok, zookie}` with the count of deleted tuples.
  """
  @spec delete(binary(), [Tuple.t() | map()]) :: {:ok, map()} | {:error, term()}
  def delete(tenant_id, tuples) when is_list(tuples) do
    Repo.transaction(fn ->
      now = DateTime.utc_now()

      count =
        tuples
        |> Enum.map(&to_relation_tuple_attrs/1)
        |> Enum.reduce(0, fn attrs, acc ->
          query = build_delete_query(tenant_id, attrs)

          {n, _} =
            Repo.update_all(query, set: [deleted_at: now])

          acc + n
        end)

      {:ok, zookie} = Zookie.mint(tenant_id)

      # Emit telemetry for Watch endpoint
      :telemetry.execute([:zeval, :tuples, :deleted], %{count: count}, %{tenant_id: tenant_id})

      %{deleted: count, zookie: zookie.token}
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Reads relation tuples matching the given filter.

  ## Filter

  The filter is a map with optional keys: `:namespace`, `:object_id`,
  `:relation`, `:subject`. Omitted keys are not filtered.

  The `:subject` value can be:
    * A string — matched against `user_id`
    * A tuple `{:userset, ns, obj, rel}` — matched against the userset columns
    * A `%Tuple{}` struct — matched against all subject fields

  ## Options

    * `:consistency` — a zookie token string. When provided, only tuples
      inserted at or before the zookie's snapshot time are returned
      (and deleted tuples from after that snapshot are still visible).
    * `:limit` — maximum rows to return (default #{@default_limit},
      capped at #{@max_limit}). Reads are always bounded so a single call
      can't load an unbounded result set.

  Returns a list of `%Tuple{}` structs.
  """
  @spec read(binary(), map(), keyword()) :: [Tuple.t()]
  def read(tenant_id, filter \\ %{}, opts \\ []) do
    query = from(t in RelationTuple, where: t.tenant_id == ^tenant_id)

    query = apply_filter(query, filter)

    query =
      case Keyword.get(opts, :consistency) do
        nil ->
          # No consistency token: only show active tuples
          from(t in query, where: is_nil(t.deleted_at))

        token ->
          # Zookie consistency: show tuples that existed at snapshot time
          snap = Zookie.snapshot_at(token, tenant_id)

          if snap do
            from(t in query,
              where:
                t.inserted_at <= ^snap and
                  (is_nil(t.deleted_at) or t.deleted_at > ^snap)
            )
          else
            # Zookie not found (or belongs to another tenant) — active-only
            from(t in query, where: is_nil(t.deleted_at))
          end
      end

    limit = resolve_limit(Keyword.get(opts, :limit))

    query
    |> order_by([t], asc: t.inserted_at, asc: t.id)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.map(&to_tuple/1)
  end

  defp resolve_limit(nil), do: @default_limit
  defp resolve_limit(n) when is_integer(n) and n > 0, do: min(n, @max_limit)
  defp resolve_limit(_), do: @default_limit

  # -- Filter building --

  defp apply_filter(query, filter) when is_map(filter) do
    query
    |> apply_namespace_filter(filter)
    |> apply_object_id_filter(filter)
    |> apply_relation_filter(filter)
    |> apply_subject_filter(filter)
  end

  defp apply_filter(query, _), do: query

  defp apply_namespace_filter(query, %{namespace: ns}) when is_binary(ns),
    do: from(t in query, where: t.namespace == ^ns)

  defp apply_namespace_filter(query, _), do: query

  defp apply_object_id_filter(query, %{object_id: oid}) when is_binary(oid),
    do: from(t in query, where: t.object_id == ^oid)

  defp apply_object_id_filter(query, _), do: query

  defp apply_relation_filter(query, %{relation: rel}) when is_binary(rel),
    do: from(t in query, where: t.relation == ^rel)

  defp apply_relation_filter(query, _), do: query

  defp apply_subject_filter(query, %{subject: subject}) do
    case subject do
      {:user, uid} when is_binary(uid) ->
        from(t in query, where: t.subject_type == "user" and t.user_id == ^uid)

      {:userset, ns, oid, rel} ->
        from(t in query,
          where:
            t.subject_type == "userset" and
              t.userset_namespace == ^ns and
              t.userset_object_id == ^oid and
              t.userset_relation == ^rel
        )

      %Tuple{subject: inner_subject} ->
        apply_subject_filter(query, %{subject: inner_subject})

      uid when is_binary(uid) ->
        from(t in query, where: t.subject_type == "user" and t.user_id == ^uid)

      _ ->
        query
    end
  end

  defp apply_subject_filter(query, _), do: query

  # -- Delete query building --

  defp build_delete_query(tenant_id, attrs) do
    query =
      from(t in RelationTuple,
        where: t.tenant_id == ^tenant_id and is_nil(t.deleted_at)
      )

    query =
      if attrs[:namespace],
        do: from(t in query, where: t.namespace == ^attrs[:namespace]),
        else: query

    query =
      if attrs[:object_id],
        do: from(t in query, where: t.object_id == ^attrs[:object_id]),
        else: query

    query =
      if attrs[:relation],
        do: from(t in query, where: t.relation == ^attrs[:relation]),
        else: query

    # The subject MUST be narrowed to the specific subject being deleted.
    # Falling through to the unscoped query here would soft-delete every
    # tuple matching (namespace, object_id, relation), not just this subject.
    case attrs[:subject_type] do
      "user" ->
        from(t in query,
          where: t.subject_type == "user" and t.user_id == ^attrs[:user_id]
        )

      "userset" ->
        from(t in query,
          where:
            t.subject_type == "userset" and
              t.userset_namespace == ^attrs[:userset_namespace] and
              t.userset_object_id == ^attrs[:userset_object_id] and
              t.userset_relation == ^attrs[:userset_relation]
        )
    end
  end

  # -- Conversion helpers --

  defp to_relation_tuple_attrs(%Tuple{
         namespace: ns,
         object_id: oid,
         relation: rel,
         subject: {:user, uid}
       }) do
    %{
      namespace: ns,
      object_id: oid,
      relation: rel,
      subject_type: "user",
      user_id: uid
    }
  end

  defp to_relation_tuple_attrs(%Tuple{
         namespace: ns,
         object_id: oid,
         relation: rel,
         subject: {:userset, userset_ns, userset_oid, userset_rel}
       }) do
    %{
      namespace: ns,
      object_id: oid,
      relation: rel,
      subject_type: "userset",
      userset_namespace: userset_ns,
      userset_object_id: userset_oid,
      userset_relation: userset_rel
    }
  end

  defp to_relation_tuple_attrs(%{namespace: ns, object_id: oid, relation: rel, subject: subject}) do
    to_relation_tuple_attrs(%Tuple{
      namespace: ns,
      object_id: oid,
      relation: rel,
      subject: subjectify(subject)
    })
  end

  defp subjectify({:user, _} = s), do: s
  defp subjectify({:userset, _, _, _} = s), do: s
  defp subjectify(uid) when is_binary(uid), do: {:user, uid}

  defp to_tuple(%RelationTuple{
         namespace: ns,
         object_id: oid,
         relation: rel,
         subject_type: "user",
         user_id: uid
       }) do
    %Tuple{namespace: ns, object_id: oid, relation: rel, subject: {:user, uid}}
  end

  defp to_tuple(%RelationTuple{
         namespace: ns,
         object_id: oid,
         relation: rel,
         subject_type: "userset",
         userset_namespace: us_ns,
         userset_object_id: us_oid,
         userset_relation: us_rel
       }) do
    %Tuple{
      namespace: ns,
      object_id: oid,
      relation: rel,
      subject: {:userset, us_ns, us_oid, us_rel}
    }
  end
end
