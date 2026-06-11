import Config

# Shared config for all environments
config :zeval_core, ecto_repos: [ZevalCore.Repo]

config :zeval_core, ZevalCore.Repo,
  migration_timestamps: [type: :timestamptz]

config :zeval_web, ZevalWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: ZevalWeb.PubSub,
  render_errors: [
    formats: [json: ZevalWeb.ErrorJSON],
    layout: false
  ]

config :logger, :default_handler,
  level: :info

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :tenant_id]

import_config "#{config_env()}.exs"
