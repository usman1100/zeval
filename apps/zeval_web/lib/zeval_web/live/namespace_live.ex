defmodule ZevalWeb.DashboardLive.NamespaceLive do
  use ZevalWeb, :live_view
  import ZevalWeb.DashboardLive.Sidebar, only: [dashboard_layout: 1]
  import Ecto.Query

  alias ZevalCore.{Repo, Tenants, Namespace}
  alias ZevalCore.Namespace.NamespaceConfig

  def mount(_params, session, socket) do
    {:ok, assign(socket,
      current_user: %{email: session["current_user_email"], name: session["current_user_name"]},
      namespaces: all_namespaces_with_tenants(),
      tenants: Tenants.list(),
      filter_tenant_id: "",
      selected_namespace: nil
    )}
  end

  def render(assigns) do
    ~H"""
    <.dashboard_layout page_title="Zeval Engine — Namespaces" current_user={@current_user} active="namespaces">

      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold text-white">Namespaces</h2>
        <a href="/dashboard/namespaces/new"
          class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium">
          + New Namespace
        </a>
      </div>

      <div class="mb-4">
        <select phx-change="filter_tenant"
          class="bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-sm text-white">
          <option value="">All tenants</option>
          <%= for t <- @tenants do %>
            <option value={t.id} selected={@filter_tenant_id == t.id}><%= t.name %></option>
          <% end %>
        </select>
      </div>

      <div class="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-gray-800">
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Name</th>
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Tenant</th>
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Version</th>
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Created</th>
              <th class="text-right px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for ns <- @namespaces do %>
              <tr class="border-b border-gray-800 hover:bg-gray-800/50">
                <td class="px-4 py-3 text-sm text-white font-medium"><%= ns.name %></td>
                <td class="px-4 py-3 text-sm text-gray-400"><%= ns.tenant_name %></td>
                <td class="px-4 py-3 text-sm text-gray-400">v<%= ns.version %></td>
                <td class="px-4 py-3 text-sm text-gray-400">
                  <%= if ns.inserted_at do %>
                    <%= Calendar.strftime(ns.inserted_at, "%Y-%m-%d") %>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-right space-x-3">
                  <button phx-click="view_config" phx-value-id={ns.id}
                    class="text-blue-400 hover:text-blue-300 text-sm">View</button>
                  <a href={"/dashboard/namespaces/#{ns.id}/edit"}
                    class="text-gray-400 hover:text-white text-sm">Edit</a>
                  <button phx-click="delete" phx-value-id={ns.id}
                    phx-confirm="Delete namespace '#{ns.name}' and all its config?"
                    class="text-red-400 hover:text-red-300 text-sm">Delete</button>
                </td>
              </tr>
            <% end %>
            <%= if @namespaces == [] do %>
              <tr><td colspan="5" class="px-4 py-8 text-center text-gray-500">No namespaces yet.</td></tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @selected_namespace do %>
        <div class="fixed inset-0 bg-black/60 flex items-center justify-center z-50" phx-click="close_viewer">
          <div class="bg-gray-900 border border-gray-700 rounded-xl p-6 max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto" phx-click-away="close_viewer">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-white"><%= @selected_namespace.name %></h3>
              <button phx-click="close_viewer" class="text-gray-400 hover:text-white text-xl">&times;</button>
            </div>
            <pre class="bg-gray-950 border border-gray-700 rounded-lg p-4 text-sm font-mono text-green-300 overflow-x-auto"><%= Jason.encode!(@selected_namespace.config, pretty: true) %></pre>
          </div>
        </div>
      <% end %>

    </.dashboard_layout>
    """
  end

  def handle_event("filter_tenant", %{"value" => id}, socket) do
    namespaces = if id == "" do
      all_namespaces_with_tenants()
    else
      namespaces_for_tenant(id)
    end
    {:noreply, assign(socket, namespaces: namespaces, filter_tenant_id: id)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    ns = Repo.get!(NamespaceConfig, id)
    Namespace.delete(ns.tenant_id, ns.name)
    {:noreply, assign(socket, namespaces: all_namespaces_with_tenants(), selected_namespace: nil)}
  end

  def handle_event("view_config", %{"id" => id}, socket) do
    ns = Repo.get!(NamespaceConfig, id)
    {:noreply, assign(socket, selected_namespace: ns)}
  end

  def handle_event("close_viewer", _, socket) do
    {:noreply, assign(socket, selected_namespace: nil)}
  end

  defp all_namespaces_with_tenants do
    Repo.all(
      from n in NamespaceConfig,
        join: t in ZevalCore.Tenant, on: n.tenant_id == t.id,
        order_by: [desc: n.inserted_at],
        select: %{
          id: n.id,
          name: n.name,
          version: n.version,
          inserted_at: n.inserted_at,
          tenant_id: n.tenant_id,
          tenant_name: t.name,
          config: n.config
        }
    )
  end

  defp namespaces_for_tenant(tenant_id) do
    Repo.all(
      from n in NamespaceConfig,
        join: t in ZevalCore.Tenant, on: n.tenant_id == t.id,
        where: n.tenant_id == ^tenant_id,
        order_by: [desc: n.inserted_at],
        select: %{
          id: n.id,
          name: n.name,
          version: n.version,
          inserted_at: n.inserted_at,
          tenant_id: n.tenant_id,
          tenant_name: t.name,
          config: n.config
        }
    )
  end
end
