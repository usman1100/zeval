defmodule ZevalWeb.DashboardLive.TenantLive do
  use ZevalWeb, :live_view

  alias ZevalCore.Tenants
  alias ZevalWeb.ChangesetError

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active: "tenants",
       page_title: "Zeval Engine — Tenants",
       tenants: Tenants.list_for_user(socket.assigns.current_user.id),
       show_create: false,
       new_name: "",
       error: nil
     )}
  end

  def handle_event("update_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, new_name: name)}
  end

  def handle_event("show_create", _, socket) do
    {:noreply, assign(socket, show_create: true, error: nil)}
  end

  def handle_event("hide_create", _, socket) do
    {:noreply, assign(socket, show_create: false, error: nil)}
  end

  def handle_event("create", %{"name" => name}, socket) when byte_size(name) < 2 do
    {:noreply, assign(socket, error: "Name must be at least 2 characters")}
  end

  def handle_event("create", %{"name" => name}, socket) do
    case Tenants.create_for_user(socket.assigns.current_user.id, name) do
      {:ok, _tenant} ->
        {:noreply,
         assign(socket,
           tenants: Tenants.list_for_user(socket.assigns.current_user.id),
           show_create: false,
           new_name: "",
           error: nil
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, error: ChangesetError.first(changeset))}

      {:error, _other} ->
        {:noreply, assign(socket, error: "Could not create tenant")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Tenants.delete_for_user(user_id, id) do
      {:ok, _} ->
        {:noreply, assign(socket, tenants: Tenants.list_for_user(user_id), error: nil)}

      {:error, :not_found} ->
        {:noreply, assign(socket, error: "Tenant not found")}
    end
  end
end
