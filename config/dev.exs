import Config

config :zeval_core, ZevalCore.Repo,
  username: "zeval",
  password: "zeval",
  hostname: "localhost",
  database: "zeval_dev",
  port: 5432,
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

config :zeval_web, ZevalWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  check_origin: false,
  secret_key_base: "dev_secret_key_base_do_not_use_in_production_min_64_bytes_long_xxxxxxxx"

config :logger, :default_handler, level: :debug

# Static token for the tenant-bootstrap endpoint in dev.
config :zeval_web, :admin_bootstrap_token, "dev-bootstrap-token"

# Static token for the /metrics endpoint in dev.
config :zeval_web, :metrics_token, "dev-metrics-token"
