defmodule ZevalWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :zeval_web

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason

  plug ZevalWeb.Router
end
