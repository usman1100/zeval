defmodule ZevalWeb.TupleController do
  use ZevalWeb, :controller

  alias ZevalCore.Tuples
  alias ZevalCore.Tuples.{Tuple, Parser}
  alias ZevalCore.Expand

  @max_tuples_per_request 500

  def write(conn, %{"tuples" => raw_tuples}) when is_list(raw_tuples) do
    if length(raw_tuples) > @max_tuples_per_request do
      ZevalWeb.JsonHelpers.bad_request(conn, "max #{@max_tuples_per_request} tuples per request")
    else
      tenant_id = conn.assigns.tenant_id
      parsed = Enum.map(raw_tuples, &parse_tuple_params/1)

      case Tuples.write(tenant_id, parsed) do
        {:ok, result} ->
          json(conn, %{written: result.written, zookie: result.zookie})

        {:error, reason} ->
          ZevalWeb.JsonHelpers.bad_request(conn, inspect(reason))
      end
    end
  end

  def write(conn, _) do
    ZevalWeb.JsonHelpers.bad_request(conn, "tuples array is required")
  end

  def delete(conn, %{"tuples" => raw_tuples}) when is_list(raw_tuples) do
    tenant_id = conn.assigns.tenant_id
    parsed = Enum.map(raw_tuples, &parse_tuple_params/1)

    case Tuples.delete(tenant_id, parsed) do
      {:ok, result} ->
        json(conn, %{deleted: result.deleted, zookie: result.zookie})

      {:error, reason} ->
        ZevalWeb.JsonHelpers.bad_request(conn, inspect(reason))
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

  defp parse_tuple_params(%{"namespace" => ns, "object_id" => oid, "relation" => rel, "subject" => subject}) do
    %Tuple{namespace: ns, object_id: oid, relation: rel, subject: parse_subject(subject)}
  end

  defp parse_tuple_params(%{"shorthand" => shorthand}) do
    case Parser.parse(shorthand) do
      {:ok, tuple} -> tuple
      {:error, _reason} -> %Tuple{}
    end
  end

  defp parse_subject(subject) when is_binary(subject) do
    # Try to parse as shorthand first (userset form), fall back to user
    case Parser.parse("x:x#x@#{subject}") do
      {:ok, %Tuple{subject: s}} -> s
      {:error, _} -> {:user, subject}
    end
  end

  defp parse_subject(%{"type" => "user", "id" => uid}), do: {:user, uid}
  defp parse_subject(%{"type" => "userset", "namespace" => ns, "object_id" => oid, "relation" => rel}),
    do: {:userset, ns, oid, rel}

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

  defp format_tuple(%Tuple{namespace: ns, object_id: oid, relation: rel, subject: {:userset, us_ns, us_oid, us_rel}}) do
    %{namespace: ns, object_id: oid, relation: rel, subject: "#{us_ns}:#{us_oid}##{us_rel}"}
  end
end