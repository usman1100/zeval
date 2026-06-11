defmodule ZevalWeb.TelemetryHandler do
  @moduledoc """
  Bridges tuple change telemetry events to PubSub broadcasts
  for the Watch SSE endpoint.
  """

  require Phoenix.PubSub

  @doc false
  def handle_event([:zeval, :tuples, :written], _measurements, metadata, _config) do
    broadcast_tuple_event(:tuple_written, metadata)
  end

  def handle_event([:zeval, :tuples, :deleted], _measurements, metadata, _config) do
    broadcast_tuple_event(:tuple_deleted, metadata)
  end

  defp broadcast_tuple_event(event, metadata) do
    tenant_id = metadata[:tenant_id]
    topic = "watch:#{tenant_id}:*"
    Phoenix.PubSub.broadcast(ZevalWeb.PubSub, topic, %{event: event, payload: metadata})
  end
end