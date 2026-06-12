defmodule ZevalWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :zeval_web

  # No sockets — this is a JSON-only API

  # Session for dashboard authentication
  plug Plug.Session,
    store: :cookie,
    key: "_zeval_dashboard",
    signing_salt: "signing-salt-change-in-prod",
    encryption_salt: "encryption-salt-change-in-prod",
    http_only: true,
    secure: false,
    same_site: "Lax"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug ZevalWeb.Router
end