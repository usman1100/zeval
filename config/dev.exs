import Config

# Load .env file so mix / iex pick up env vars automatically.
env_path = Path.join([__DIR__, "..", ".env"])

if File.exists?(env_path) do
  env_path
  |> File.read!()
  |> String.split("\n", trim: true)
  |> Enum.each(fn line ->
    line = String.trim(line)

    if line != "" and not String.starts_with?(line, "#") do
      case String.split(line, "=", parts: 2) do
        [key, value] -> System.put_env(key, value)
        _ -> :ok
      end
    end
  end)
end

# All credentials come from environment variables (loaded via .env).
# DATABASE_URL is the primary source; if unset, individual PG* vars are used.
database_url = System.get_env("DATABASE_URL")

repo_config =
  if is_binary(database_url) and database_url != "" do
    [
      url: database_url,
      pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
      show_sensitive_data_on_connection_error: true
    ]
  else
    [
      username: System.get_env("PGUSER"),
      password: System.get_env("PGPASSWORD"),
      hostname: System.get_env("PGHOST"),
      database: System.get_env("PGDATABASE"),
      port: String.to_integer(System.get_env("PGPORT", "5432")),
      pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
      show_sensitive_data_on_connection_error: true
    ]
  end

config :zeval_core, ZevalCore.Repo, repo_config

config :zeval_web, ZevalWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  check_origin: false,
  secret_key_base: "dev_secret_key_base_do_not_use_in_production_min_64_bytes_long_xxxxxxxx"

config :logger, :default_handler, level: :debug

# Static token for the /metrics endpoint in dev.
config :zeval_web, :metrics_token, "dev-metrics-token"
