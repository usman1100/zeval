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

  def watch(conn, params) do
    tenant_id = conn.assigns.tenant_id
    namespace_filter = params["namespace"]

    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> send_chunked(:ok)
    |> stream_events(tenant_id, namespace_filter)
  end

  defp stream_events(conn, tenant_id, namespace_filter) do
    topic = "watch:#{tenant_id}:#{namespace_filter || "*"}"

    # Subscribe to the topic and stream events until the client disconnects
    Phoenix.PubSub.subscribe(ZevalWeb.PubSub, topic)

    # Send initial heartbeat
    chunk(conn, "data: {\"event\":\"connected\"}\n\n")

    receive do
      {:phoenix_pubsub, %{event: :tuple_written, payload: payload}} ->
        if matches_filter(payload, namespace_filter) do
          data = Jason.encode!(Map.put(payload, :event, "tuple.written"))
          chunk(conn, "data: #{data}\n\n")
        end
        stream_events(conn, tenant_id, namespace_filter)

      {:phoenix_pubsub, %{event: :tuple_deleted, payload: payload}} ->
        if matches_filter(payload, namespace_filter) do
          data = Jason.encode!(Map.put(payload, :event, "tuple.deleted"))
          chunk(conn, "data: #{data}\n\n")
        end
        stream_events(conn, tenant_id, namespace_filter)

      {:phoenix_pubsub, _other} ->
        stream_events(conn, tenant_id, namespace_filter)

      {:plug_conn, :sent} ->
        :ok
    end
  end

  defp matches_filter(_payload, nil), do: true
  defp matches_filter(%{namespace: ns}, filter), do: ns == filter
  defp matches_filter(_, _), do: true
end