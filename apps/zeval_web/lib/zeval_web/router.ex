defmodule ZevalWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug :accepts, ["json"]
    plug ZevalWeb.Plugs.ServiceAuth
    plug ZevalWeb.Plugs.LoggerMetadata
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
  end

  scope "/api/v1", ZevalWeb do
    pipe_through :api

    # Tenant bootstrap (no auth — creates the first tenant)
    post "/tenants", TenantController, :create

    # Service account key management (no auth — or we can use bootstrap token)
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