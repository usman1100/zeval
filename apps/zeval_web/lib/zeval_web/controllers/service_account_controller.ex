defmodule ZevalWeb.ServiceAccountController do
  use ZevalWeb, :controller

  alias ZevalCore.ServiceAccounts

  # The tenant is always taken from the authenticated service account
  # (conn.assigns.tenant_id, set by ServiceAuth). It is never read from the
  # request body — doing so previously let any caller mint keys for any tenant.

  def create(conn, %{"name" => name}) when is_binary(name) do
    tenant_id = conn.assigns.tenant_id
    actor = "account:#{conn.assigns.service_account.id}"

    case ServiceAccounts.create(tenant_id, name, created_by: actor) do
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
    tenant_id = conn.assigns.tenant_id

    # Verify the target account belongs to the caller's tenant before
    # revoking, so a key from tenant A cannot revoke tenant B's accounts.
    case ServiceAccounts.get(id) do
      %{tenant_id: ^tenant_id} ->
        case ServiceAccounts.revoke(id, revoked_by: "account:#{conn.assigns.service_account.id}") do
          {:ok, _} ->
            json(conn, %{revoked: true})

          {:error, :not_found} ->
            ZevalWeb.JsonHelpers.not_found(conn, "service account not found")
        end

      _ ->
        # Either missing or owned by a different tenant — same response to
        # avoid leaking which account IDs exist across tenants.
        ZevalWeb.JsonHelpers.not_found(conn, "service account not found")
    end
  end
end
