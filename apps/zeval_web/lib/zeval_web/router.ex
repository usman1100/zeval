defmodule ZevalWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug :accepts, ["json"]
    plug ZevalWeb.Plugs.ServiceAuth
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
    pipe_through :auth

    # Namespace configs
    post "/namespaces", NamespaceController, :upsert
    get "/namespaces", NamespaceController, :index
    get "/namespaces/:name", NamespaceController, :show
    delete "/namespaces/:name", NamespaceController, :delete

    # Tuples
    post "/tuples", TupleController, :write
    delete "/tuples", TupleController, :delete
    post "/tuples/read", TupleController, :read
    post "/tuples/expand", TupleController, :expand

    # Check
    post "/check", CheckController, :check

    # Watch (SSE)
    get "/watch", WatchController, :watch
  end
end