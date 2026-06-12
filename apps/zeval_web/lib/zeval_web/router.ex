defmodule ZevalWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug :accepts, ["json"]
    plug ZevalWeb.Plugs.ServiceAuth
    plug ZevalWeb.Plugs.LoggerMetadata
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
  end

  pipeline :dashboard_auth do
    plug ZevalWeb.Plugs.DashboardAuth
  end

  pipeline :check_rate do
    plug ZevalWeb.Plugs.RateLimit, max_requests: 1000, bucket_name: "check"
  end

  pipeline :tuple_write_rate do
    plug ZevalWeb.Plugs.RateLimit, max_requests: 500, bucket_name: "tuples"
  end

  # Prometheus metrics — no auth
  scope "/", ZevalWeb do
    get "/metrics", MetricsController, :index
    get "/", PageController, :index
  end

  # Dashboard — public routes
  scope "/dashboard", ZevalWeb do
    pipe_through [:browser]

    get "/login", DashboardSessionController, :new
    post "/login", DashboardSessionController, :create
    get "/logout", DashboardSessionController, :delete
    get "/signup", DashboardSessionController, :signup_new
    post "/signup", DashboardSessionController, :signup_create
  end

  # Dashboard — authenticated routes
  scope "/dashboard", ZevalWeb do
    pipe_through [:browser, :dashboard_auth]

    live "/", DashboardLive.HomeLive, :index
    live "/tenants", DashboardLive.TenantLive, :index
    live "/tenants/:id", DashboardLive.TenantDetailLive, :show
    live "/api-keys", DashboardLive.ApiKeyLive, :index
    live "/namespaces", DashboardLive.NamespaceLive, :index
    live "/namespaces/:id/edit", DashboardLive.NamespaceEditorLive, :edit
    live "/tuples", DashboardLive.TupleLive, :index
    live "/check", DashboardLive.CheckLive, :index
    live "/expand", DashboardLive.ExpandLive, :index
  end

  scope "/api/v1", ZevalWeb do
    pipe_through :api

    # Tenant bootstrap (no auth — creates the first tenant)
    post "/tenants", TenantController, :create

    # Service account key management (no auth — needs tenant_id)
    post "/service-accounts", ServiceAccountController, :create
    delete "/service-accounts/:id", ServiceAccountController, :revoke
  end

  scope "/api/v1", ZevalWeb do
    pipe_through [:auth]

    # Namespace configs (200 req/min — general rate)
    post "/namespaces", NamespaceController, :upsert
    get "/namespaces", NamespaceController, :index
    get "/namespaces/:name", NamespaceController, :show
    delete "/namespaces/:name", NamespaceController, :delete

    # Tuple read and expand (200 req/min — general rate)
    post "/tuples/read", TupleController, :read
    post "/tuples/expand", TupleController, :expand

    # Watch (SSE) (200 req/min — general rate)
    get "/watch", WatchController, :watch
  end

  # Tuples write/delete — higher limit (500 req/min)
  scope "/api/v1", ZevalWeb do
    pipe_through [:auth, :tuple_write_rate]

    post "/tuples", TupleController, :write
    delete "/tuples", TupleController, :delete
  end

  # Check — highest limit (1000 req/min)
  scope "/api/v1", ZevalWeb do
    pipe_through [:auth, :check_rate]

    post "/check", CheckController, :check
  end
end