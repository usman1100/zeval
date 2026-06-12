defmodule ZevalWeb.TupleController do
  use ZevalWeb, :controller

  alias ZevalCore.Tuples
  alias ZevalCore.Tuples.{Tuple, Parser}
  alias ZevalCore.Expand

  @max_tuples_per_request 500

  def write(conn, %{"tuples" => raw_tuples}) when is_list(raw_tuples) do
    cond do
      length(raw_tuples) > @max_tuples_per_request ->
        ZevalWeb.JsonHelpers.bad_request(
          conn,
          "max #{@max_tuples_per_request} tuples per request"
        )

      true ->
        with {:ok, parsed} <- parse_all(raw_tuples),
             {:ok, result} <- Tuples.write(conn.assigns.tenant_id, parsed) do
          json(conn, %{written: result.written, zookie: result.zookie})
        else
          {:error, :parse, reason} -> ZevalWeb.JsonHelpers.bad_request(conn, reason)
          {:error, _reason} -> ZevalWeb.JsonHelpers.bad_request(conn, "could not write tuples")
        end
    end
  end

  def write(conn, _) do
    ZevalWeb.JsonHelpers.bad_request(conn, "tuples array is required")
  end

  def delete(conn, %{"tuples" => raw_tuples}) when is_list(raw_tuples) do
    with {:ok, parsed} <- parse_all(raw_tuples),
         {:ok, result} <- Tuples.delete(conn.assigns.tenant_id, parsed) do
      json(conn, %{deleted: result.deleted, zookie: result.zookie})
    else
      {:error, :parse, reason} -> ZevalWeb.JsonHelpers.bad_request(conn, reason)
      {:error, _reason} -> ZevalWeb.JsonHelpers.bad_request(conn, "could not delete tuples")
    end
  end

  def delete(conn, _) do
    ZevalWeb.JsonHelpers.bad_request(conn, "tuples array is required")
  end

  def read(conn, params) do
    tenant_id = conn.assigns.tenant_id
    filter = build_filter(params)
    opts = if params["zookie"], do: [consistency: params["zookie"]], else: []

    results = Tuples.read(tenant_id, filter, opts)

    json(conn, %{
      tuples: Enum.map(results, &format_tuple/1),
      zookie: params["zookie"]
    })
  end

  def expand(conn, %{"namespace" => ns, "object_id" => oid, "relation" => rel}) do
    tenant_id = conn.assigns.tenant_id
    opts = if conn.params["zookie"], do: [consistency: conn.params["zookie"]], else: []

    tree = Expand.expand(tenant_id, ns, oid, rel, opts)
    json(conn, %{tree: tree})
  end

  def expand(conn, _) do
    ZevalWeb.JsonHelpers.bad_request(conn, "namespace, object_id, and relation are required")
  end

  # -- Parameter parsing --

  # Parses every raw tuple, short-circuiting on the first parse error so
  # malformed input is rejected with a 400 rather than silently dropped.
  defp parse_all(raw_tuples) do
    Enum.reduce_while(raw_tuples, {:ok, []}, fn raw, {:ok, acc} ->
      case parse_tuple_params(raw) do
        {:ok, tuple} -> {:cont, {:ok, [tuple | acc]}}
        {:error, reason} -> {:halt, {:error, :parse, reason}}
      end
    end)
    |> case do
      {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
      other -> other
    end
  end

  defp parse_tuple_params(%{
         "namespace" => ns,
         "object_id" => oid,
         "relation" => rel,
         "subject" => subject
       }) do
    case parse_subject(subject) do
      {:ok, s} ->
        case Parser.parse("#{ns}:#{oid}##{rel}@placeholder") do
          {:ok, _} -> {:ok, %Tuple{namespace: ns, object_id: oid, relation: rel, subject: s}}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_tuple_params(%{"shorthand" => shorthand}), do: Parser.parse(shorthand)

  defp parse_tuple_params(_),
    do: {:error, "tuple must include namespace, object_id, relation, subject (or shorthand)"}

  defp parse_subject(subject) when is_binary(subject) do
    # Validate via the shorthand parser (handles both user and userset forms).
    case Parser.parse("ns:obj#rel@#{subject}") do
      {:ok, %Tuple{subject: s}} -> {:ok, s}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_subject(%{"type" => "user", "id" => uid}) when is_binary(uid),
    do: {:ok, {:user, uid}}

  defp parse_subject(%{
         "type" => "userset",
         "namespace" => ns,
         "object_id" => oid,
         "relation" => rel
       }),
       do: {:ok, {:userset, ns, oid, rel}}

  defp parse_subject(_), do: {:error, "invalid subject"}

  defp build_filter(params) do
    %{}
    |> maybe_put(:namespace, params)
    |> maybe_put(:object_id, params)
    |> maybe_put(:relation, params)
    |> maybe_put_subject(params)
  end

  defp maybe_put(acc, key, params) do
    if v = params[to_string(key)], do: Map.put(acc, key, v), else: acc
  end

  defp maybe_put_subject(acc, params) do
    cond do
      s = params["subject"] -> Map.put(acc, :subject, s)
      s = params["user_id"] -> Map.put(acc, :subject, {:user, s})
      true -> acc
    end
  end

  defp format_tuple(%Tuple{namespace: ns, object_id: oid, relation: rel, subject: {:user, uid}}) do
    %{namespace: ns, object_id: oid, relation: rel, subject: uid}
  end

  defp format_tuple(%Tuple{
         namespace: ns,
         object_id: oid,
         relation: rel,
         subject: {:userset, us_ns, us_oid, us_rel}
       }) do
    %{namespace: ns, object_id: oid, relation: rel, subject: "#{us_ns}:#{us_oid}##{us_rel}"}
  end
end
