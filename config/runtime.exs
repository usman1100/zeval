import Config

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "Environment variable SECRET_KEY_BASE is missing"

  database_url =
    System.get_env("DATABASE_URL") ||
      raise "Environment variable DATABASE_URL is missing"

  engine_port =
    System.get_env("ENGINE_PORT", "4000") |> String.to_integer()

  config :zeval_web, ZevalWeb.Endpoint,
    http: [port: engine_port],
    secret_key_base: secret_key_base,
    server: true

  config :zeval_core, ZevalCore.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    socket_options: System.get_env("DATABASE_SSL", "false") == "true" && [verify: :verify_peer] || []

  config :logger, :default_handler,
    level: String.to_atom(System.get_env("LOG_LEVEL", "info"))
end
