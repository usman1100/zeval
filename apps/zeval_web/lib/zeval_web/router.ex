defmodule ZevalWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(ZevalWeb.Plugs.LoggerMetadata)
  end

  pipeline :auth do
    plug(:accepts, ["json"])
    plug(ZevalWeb.Plugs.ServiceAuth)
    plug(ZevalWeb.Plugs.LoggerMetadata)
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :dashboard_auth do
    plug(ZevalWeb.Plugs.DashboardAuth)
  end

  pipeline :check_rate do
    plug(ZevalWeb.Plugs.RateLimit, max_requests: 1000, bucket_name: "check")
  end

  pipeline :tuple_write_rate do
    plug(ZevalWeb.Plugs.RateLimit, max_requests: 500, bucket_name: "tuples")
  end

  pipeline :metrics_auth do
    plug(ZevalWeb.Plugs.MetricsAuth)
  end

  # Public liveness/readiness probes.
  scope "/", ZevalWeb do
    get("/health", HealthController, :health)
    get("/ready", HealthController, :ready)
  end

  # Public landing page (needs browser pipeline for CSRF/session).
  scope "/", ZevalWeb do
    pipe_through([:browser])
    get("/", PageController, :index)
  end

  # Prometheus metrics — requires METRICS_TOKEN bearer (disabled if unset).
  scope "/", ZevalWeb do
    pipe_through([:metrics_auth])
    get("/metrics", MetricsController, :index)
  end

  # Per-IP rate limit for credential endpoints (login/signup), to blunt
  # credential stuffing.
  pipeline :login_rate do
    plug(ZevalWeb.Plugs.RateLimit, max_requests: 30, bucket_name: "login", key: :ip)
  end

  # Dashboard — public routes
  scope "/dashboard", ZevalWeb do
    pipe_through([:browser, :login_rate])

    get("/login", DashboardSessionController, :new)
    post("/login", DashboardSessionController, :create)
    get("/logout", DashboardSessionController, :delete)
    get("/signup", DashboardSessionController, :signup_new)
    post("/signup", DashboardSessionController, :signup_create)
  end

  # Dashboard — authenticated routes. DashboardAuth guards the HTTP request;
  # LiveAuth (on_mount) re-verifies the user on every socket mount.
  scope "/dashboard", ZevalWeb do
    pipe_through([:browser, :dashboard_auth])

    live_session :dashboard,
      on_mount: ZevalWeb.LiveAuth,
      root_layout: {ZevalWeb.Layouts, :root},
      layout: {ZevalWeb.Layouts, :app} do
      live("/", DashboardLive.HomeLive, :index)
      live("/tenants", DashboardLive.TenantLive, :index)
      live("/tenants/:id", DashboardLive.TenantDetailLive, :show)
      live("/api-keys", DashboardLive.ApiKeyLive, :index)
      live("/namespaces", DashboardLive.NamespaceLive, :index)
      live("/namespaces/new", DashboardLive.NamespaceEditorLive, :new)
      live("/namespaces/:id/edit", DashboardLive.NamespaceEditorLive, :edit)
      live("/tuples", DashboardLive.TupleLive, :index)
      live("/check", DashboardLive.CheckLive, :index)
      live("/expand", DashboardLive.ExpandLive, :index)
      live("/docs", DashboardLive.DocsLive, :index)
    end
  end

  # Tenants are created only from the dashboard (which assigns the creator as
  # owner via tenant_memberships) — there is no public tenant-creation API, so
  # a tenant can never exist without an owner.

  scope "/api/v1", ZevalWeb do
    pipe_through([:auth])

    # Service account key management — scoped to the authenticated tenant.
    post("/service-accounts", ServiceAccountController, :create)
    delete("/service-accounts/:id", ServiceAccountController, :revoke)

    # Namespace configs (200 req/min — general rate)
    post("/namespaces", NamespaceController, :upsert)
    get("/namespaces", NamespaceController, :index)
    get("/namespaces/:name", NamespaceController, :show)
    delete("/namespaces/:name", NamespaceController, :delete)

    # Tuple read and expand (200 req/min — general rate)
    post("/tuples/read", TupleController, :read)
    post("/tuples/expand", TupleController, :expand)

    # Watch (SSE) (200 req/min — general rate)
    get("/watch", WatchController, :watch)
  end

  # Tuples write/delete — higher limit (500 req/min)
  scope "/api/v1", ZevalWeb do
    pipe_through([:auth, :tuple_write_rate])

    post("/tuples", TupleController, :write)
    delete("/tuples", TupleController, :delete)
  end

  # Check — highest limit (1000 req/min)
  scope "/api/v1", ZevalWeb do
    pipe_through([:auth, :check_rate])

    post("/check", CheckController, :check)
  end

  # JSON 404 for any unmatched API route (consistent error shape).
  scope "/api", ZevalWeb do
    pipe_through([:api])
    match(:*, "/*path", FallbackController, :not_found)
  end
end
