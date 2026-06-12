defmodule ZevalWeb.DashboardLive.ApiKeyLive do
  use ZevalWeb, :live_view

  alias ZevalCore.{ServiceAccounts, Tenants, Memberships}
  alias ZevalWeb.ChangesetError

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    {:ok,
     assign(socket,
       active: "api-keys",
       page_title: "Zeval Engine — API Keys",
       accounts: ServiceAccounts.list_for_user(user_id),
       tenants: Tenants.list_for_user(user_id),
       show_create: false,
       new_name: "",
       new_tenant_id: "",
       created_key: nil,
       error: nil
     )}
  end

  def handle_event("update_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, new_name: name)}
  end

  def handle_event("show_create", _, socket) do
    {:noreply, assign(socket, show_create: true, created_key: nil, error: nil)}
  end

  def handle_event("hide_create", _, socket) do
    {:noreply, assign(socket, show_create: false, created_key: nil, error: nil)}
  end

  def handle_event("dismiss_key", _, socket) do
    {:noreply, assign(socket, created_key: nil)}
  end

  def handle_event("select_tenant", %{"tenant_id" => id}, socket) do
    {:noreply, assign(socket, new_tenant_id: id)}
  end

  def handle_event("create", %{"name" => name, "tenant_id" => tid}, socket)
      when tid != "" and byte_size(name) > 0 do
    user_id = socket.assigns.current_user.id

    if Memberships.member?(user_id, tid) do
      case ServiceAccounts.create(tid, name, created_by: "user:#{user_id}") do
        {:ok, %{raw_key: raw_key}} ->
          {:noreply,
           assign(socket,
             accounts: ServiceAccounts.list_for_user(user_id),
             created_key: raw_key,
             show_create: true,
             error: nil
           )}

        {:error, changeset} ->
          {:noreply, assign(socket, error: ChangesetError.first(changeset))}
      end
    else
      {:noreply, assign(socket, error: "You do not have access to that tenant")}
    end
  end

  def handle_event("create", _, socket) do
    {:noreply, assign(socket, error: "Tenant and name are required")}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    # Only revoke a key that belongs to a tenant the user is a member of.
    with account when not is_nil(account) <- ServiceAccounts.get(id),
         true <- Memberships.member?(user_id, account.tenant_id),
         {:ok, _} <- ServiceAccounts.revoke(id, revoked_by: "user:#{user_id}") do
      {:noreply, assign(socket, accounts: ServiceAccounts.list_for_user(user_id), error: nil)}
    else
      _ -> {:noreply, assign(socket, error: "Could not revoke that key")}
    end
  end
end
