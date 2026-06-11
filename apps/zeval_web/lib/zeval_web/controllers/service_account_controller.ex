defmodule ZevalWeb.ServiceAccountController do
  use ZevalWeb, :controller

  alias ZevalCore.ServiceAccounts

  def create(conn, %{"name" => name}) do
    tenant_id = conn.assigns.tenant_id

    case ServiceAccounts.create(tenant_id, name) do
      {:ok, %{account: account, raw_key: raw_key}} ->
        conn
        |> put_status(201)
        |> json(%{
          service_account: %{
            id: account.id,
            name: account.name,
            key_prefix: account.key_prefix,
            raw_key: raw_key
          }
        })

      {:error, changeset} ->
        ZevalWeb.JsonHelpers.unprocessable(conn, changeset)
    end
  end

  def create(conn, _) do
    ZevalWeb.JsonHelpers.bad_request(conn, "name is required")
  end

  def revoke(conn, %{"id" => id}) do
    case ServiceAccounts.revoke(id) do
      {:ok, _} ->
        json(conn, %{revoked: true})

      {:error, :not_found} ->
        ZevalWeb.JsonHelpers.not_found(conn, "service account not found")
    end
  end
end