defmodule ZevalWeb.DashboardLive.TenantDetailLive do
  use ZevalWeb, :live_view

  alias ZevalCore.{Tenants, ServiceAccounts, Namespace}

  def mount(%{"id" => id}, _session, socket) do
    user_id = socket.assigns.current_user.id

    # Only load the tenant if the current user is a member — prevents viewing
    # another tenant's data by guessing the URL id.
    case Tenants.get_for_user(user_id, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Tenant not found")
         |> redirect(to: "/dashboard/tenants")}

      tenant ->
        {:ok,
         assign(socket,
           active: "tenants",
           page_title: "Zeval Engine — #{tenant.name}",
           tenant: tenant,
           accounts: ServiceAccounts.list(id),
           namespaces: Namespace.list(id)
         )}
    end
  end

end
