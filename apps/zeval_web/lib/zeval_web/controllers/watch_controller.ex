defmodule ZevalWeb.WatchController do
  @moduledoc """
  SSE (Server-Sent Events) endpoint for watching tuple changes.

  GET /api/v1/watch?namespace=doc

  Streams newline-delimited JSON events:

      data: {"event":"tuple.written","namespace":"doc","object_id":"readme","relation":"viewer","subject":"alice"}

      data: {"event":"tuple.deleted",...}
  """

  use ZevalWeb, :controller
  require Phoenix.PubSub

  # Send a comment heartbeat if idle this long, so dead connections are
  # detected (a failed chunk halts the stream) rather than pinning a process
  # forever.
  @heartbeat_ms 30_000

  @namespace_regex ~r/^[a-z][a-z0-9_]{0,63}$/

  def watch(conn, params) do
    tenant_id = conn.assigns.tenant_id

    case validate_namespace(params["namespace"]) do
      {:ok, namespace_filter} ->
        conn
        |> put_resp_header("content-type", "text/event-stream")
        |> put_resp_header("cache-control", "no-cache")
        |> put_resp_header("connection", "keep-alive")
        |> send_chunked(:ok)
        |> stream_events(tenant_id, namespace_filter)

      :error ->
        ZevalWeb.JsonHelpers.bad_request(conn, "invalid namespace filter")
    end
  end

  defp validate_namespace(nil), do: {:ok, nil}

  defp validate_namespace(ns) when is_binary(ns) do
    if Regex.match?(@namespace_regex, ns), do: {:ok, ns}, else: :error
  end

  defp validate_namespace(_), do: :error

  defp stream_events(conn, tenant_id, namespace_filter) do
    topic = "watch:#{tenant_id}:#{namespace_filter || "*"}"

    # Subscribe to the topic and stream events until the client disconnects
    Phoenix.PubSub.subscribe(ZevalWeb.PubSub, topic)

    # Send initial heartbeat
    case chunk(conn, "data: {\"event\":\"connected\"}\n\n") do
      {:ok, conn} -> loop(conn, tenant_id, namespace_filter)
      {:error, _} -> conn
    end
  end

  defp loop(conn, tenant_id, namespace_filter) do
    receive do
      {:phoenix_pubsub, %{event: :tuple_written, payload: payload}} ->
        send_or_continue(conn, tenant_id, namespace_filter, payload, "tuple.written")

      {:phoenix_pubsub, %{event: :tuple_deleted, payload: payload}} ->
        send_or_continue(conn, tenant_id, namespace_filter, payload, "tuple.deleted")

      {:phoenix_pubsub, _other} ->
        loop(conn, tenant_id, namespace_filter)

      {:plug_conn, :sent} ->
        conn
    after
      @heartbeat_ms ->
        # Heartbeat comment; if the write fails the client is gone — stop.
        case chunk(conn, ": ping\n\n") do
          {:ok, conn} -> loop(conn, tenant_id, namespace_filter)
          {:error, _} -> conn
        end
    end
  end

  defp send_or_continue(conn, tenant_id, namespace_filter, payload, event) do
    if matches_filter(payload, namespace_filter) do
      data = Jason.encode!(Map.put(payload, :event, event))

      case chunk(conn, "data: #{data}\n\n") do
        {:ok, conn} -> loop(conn, tenant_id, namespace_filter)
        {:error, _} -> conn
      end
    else
      loop(conn, tenant_id, namespace_filter)
    end
  end

  defp matches_filter(_payload, nil), do: true
  defp matches_filter(%{namespace: ns}, filter), do: ns == filter
  defp matches_filter(_, _), do: true
end
