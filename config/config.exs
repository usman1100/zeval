import Config

# Shared config for all environments
config :zeval_core, ecto_repos: [ZevalCore.Repo]

config :zeval_core, ZevalCore.Repo, migration_timestamps: [type: :timestamptz]

config :zeval_web, ZevalWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: ZevalWeb.PubSub,
  live_view: [signing_salt: "dev-signing-salt-zeval-dashboard"],
  render_errors: [
    formats: [json: ZevalWeb.ErrorJSON],
    layout: false
  ]

# Dashboard session options. These are DEV defaults; production overrides
# the salts and sets `secure: true` from env vars in runtime.exs.
config :zeval_web, :session_options,
  store: :cookie,
  key: "_zeval_dashboard",
  signing_salt: "dev-signing-salt-change-in-prod",
  encryption_salt: "dev-encryption-salt-change-in-prod",
  http_only: true,
  secure: false,
  same_site: "Lax"

config :logger, :default_handler, level: :info

config :zeval_web, env: "dev"

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :tenant_id]

# Prometheus metrics config — installed via supervision tree child
# Telemetry poller for VM metrics
config :telemetry_poller,
  period: :timer.seconds(10),
  measurements: [
    {:process_info, [:message_queue_len, :memory, :status]},
    {:vm, [:total_run_queue_lengths, :memory, :total]}
  ]

# Rate limiting backend
config :hammer, backend: :ets

import_config "#{config_env()}.exs"
