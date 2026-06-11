import Config

config :zeval_core, ZevalCore.Repo,
  username: "zeval",
  password: "zeval",
  hostname: "localhost",
  database: "zeval_test",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :zeval_web, ZevalWeb.Endpoint,
  http: [port: 4001],
  secret_key_base: "test_secret_key_base_do_not_use_in_production_min_64_bytes_long_xxxx"

config :logger, :default_handler, level: :warning
