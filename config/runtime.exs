import Config

if config_env() == :prod do
  # -- Required secrets --------------------------------------------------------

  fetch_secret = fn name ->
    case System.get_env(name) do
      v when is_binary(v) and byte_size(v) > 0 -> v
      _ -> raise "Environment variable #{name} is missing"
    end
  end

  secret_key_base = fetch_secret.("SECRET_KEY_BASE")
  database_url = fetch_secret.("DATABASE_URL")

  unless String.starts_with?(database_url, ["postgres://", "ecto://", "postgresql://"]) do
    raise "DATABASE_URL must be a postgres:// (or ecto://) URL"
  end

  engine_port = System.get_env("ENGINE_PORT", "4000") |> String.to_integer()

  host = System.get_env("PHX_HOST") || "localhost"

  pool_size =
    case Integer.parse(System.get_env("POOL_SIZE", "10")) do
      {n, ""} when n >= 1 and n <= 100 -> n
      _ -> raise "POOL_SIZE must be an integer between 1 and 100"
    end

  database_ssl =
    case System.get_env("DATABASE_SSL", "false") do
      "true" -> true
      "false" -> false
      other -> raise ~s(DATABASE_SSL must be "true" or "false", got: #{inspect(other)})
    end

  socket_options =
    if database_ssl do
      [ssl: [verify: :verify_peer, cacerts: :public_key.cacerts_get()]]
    else
      []
    end

  # -- Endpoint ----------------------------------------------------------------

  config :zeval_web, ZevalWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: engine_port],
    secret_key_base: secret_key_base,
    server: true,
    # Redirect HTTP→HTTPS and emit HSTS. Terminate TLS at the load balancer;
    # this assumes x-forwarded-proto is set by the proxy.
    force_ssl: [rewrite_on: [:x_forwarded_proto], hsts: true],
    check_origin: [
      "https://#{host}"
      | String.split(System.get_env("EXTRA_ALLOWED_ORIGINS", ""), ",", trim: true)
    ],
    live_view: [signing_salt: fetch_secret.("LIVE_VIEW_SIGNING_SALT")]

  # Dashboard session: env-sourced salts, secure cookies.
  config :zeval_web, :session_options,
    store: :cookie,
    key: "_zeval_dashboard",
    signing_salt: fetch_secret.("SESSION_SIGNING_SALT"),
    encryption_salt: fetch_secret.("SESSION_ENCRYPTION_SALT"),
    http_only: true,
    secure: true,
    same_site: "Lax"

  # Optional: protects the /metrics endpoint. If unset, /metrics is disabled.
  config :zeval_web, :metrics_token, System.get_env("METRICS_TOKEN")

  # -- Database ----------------------------------------------------------------

  config :zeval_core, ZevalCore.Repo,
    url: database_url,
    pool_size: pool_size,
    queue_target: 5_000,
    queue_interval: 10_000,
    socket_options: socket_options

  config :logger, :default_handler,
    level: String.to_existing_atom(System.get_env("LOG_LEVEL", "info"))
end
