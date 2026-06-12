defmodule ZevalWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :zeval_web

  socket("/live", Phoenix.LiveView.Socket)

  # Serve static assets (phoenix_live_view.js, etc.)
  plug(Plug.Static,
    at: "/",
    from: :zeval_web,
    only: ~w(assets fonts images favicon.ico robots.txt)
  )

  # Session for dashboard authentication. Options (salts, secure flag) are
  # resolved at runtime from :zeval_web, :session_options — see config.exs
  # (dev defaults) and runtime.exs (production, env-sourced).
  plug(ZevalWeb.Plugs.Session)

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(ZevalWeb.Router)
end
