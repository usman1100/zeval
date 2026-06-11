defmodule ZevalWeb.TenantController do
  use ZevalWeb, :controller

  alias ZevalCore.Tenants

  def create(conn, %{"name" => name}) do
    case Tenants.create(name) do
      {:ok, tenant} ->
        conn
        |> put_status(201)
        |> json(%{tenant: %{id: tenant.id, name: tenant.name}})

      {:error, changeset} ->
        ZevalWeb.JsonHelpers.unprocessable(conn, changeset)
    end
  end

  def create(conn, _) do
    ZevalWeb.JsonHelpers.bad_request(conn, "name is required")
  end
end