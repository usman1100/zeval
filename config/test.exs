import Config

database_url = System.get_env("DATABASE_URL")

repo_config =
  if is_binary(database_url) and database_url != "" do
    url_with_test_db = String.replace(database_url, ~r"/[^/]+$", "/zeval_test")

    [
      url: url_with_test_db,
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
    ]
  else
    [
      username: System.get_env("PGUSER"),
      password: System.get_env("PGPASSWORD"),
      hostname: System.get_env("PGHOST"),
      database: "zeval_test",
      port: String.to_integer(System.get_env("PGPORT", "5432")),
      pool: Ecto.Adapters.SQL.Sandbox,
      pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
    ]
  end

config :zeval_core, ZevalCore.Repo, repo_config

config :zeval_web, ZevalWeb.Endpoint,
  http: [port: 4001],
  secret_key_base: "test_secret_key_base_do_not_use_in_production_min_64_bytes_long_xxxx"

config :logger, :default_handler, level: :warning

# Run owned connections through the SQL sandbox in tests.
config :zeval_web, sql_sandbox: true
