defmodule ZevalWeb.DashboardLive.NamespaceLive do
  use ZevalWeb, :live_view

  alias ZevalCore.{Tenants, Namespace, Memberships}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    {:ok,
     assign(socket,
       active: "namespaces",
       page_title: "Zeval Engine — Namespaces",
       namespaces: Namespace.list_for_user(user_id),
       tenants: Tenants.list_for_user(user_id),
       filter_tenant_id: "",
       selected_namespace: nil
     )}
  end

  def handle_event("filter_tenant", %{"value" => id}, socket) do
    user_id = socket.assigns.current_user.id

    # Only honor the filter if the user is a member of the chosen tenant.
    filter_id = if id != "" and Memberships.member?(user_id, id), do: id, else: ""
    namespaces = Namespace.list_for_user(user_id, if(filter_id == "", do: nil, else: filter_id))

    {:noreply, assign(socket, namespaces: namespaces, filter_tenant_id: filter_id)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Namespace.get_record_for_user(user_id, id) do
      nil ->
        {:noreply, socket}

      ns ->
        Namespace.delete(ns.tenant_id, ns.name)

        {:noreply,
         assign(socket, namespaces: Namespace.list_for_user(user_id), selected_namespace: nil)}
    end
  end

  def handle_event("view_config", %{"id" => id}, socket) do
    case Namespace.get_record_for_user(socket.assigns.current_user.id, id) do
      nil -> {:noreply, socket}
      ns -> {:noreply, assign(socket, selected_namespace: ns)}
    end
  end

  def handle_event("close_viewer", _, socket) do
    {:noreply, assign(socket, selected_namespace: nil)}
  end
end
