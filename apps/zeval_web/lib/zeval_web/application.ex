defmodule ZevalWeb.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ZevalWeb.Endpoint,
      {Phoenix.PubSub, [name: ZevalWeb.PubSub, adapter: Phoenix.PubSub.PG2]}
    ]

    opts = [strategy: :one_for_one, name: ZevalWeb.Supervisor]

    # Attach telemetry handlers for tuple change events
    :telemetry.attach_many(
      "zeval-web-tuples",
      [[:zeval, :tuples, :written], [:zeval, :tuples, :deleted]],
      &ZevalWeb.TelemetryHandler.handle_event/4,
      :no_config
    )

    Supervisor.start_link(children, opts)
  end
end