defmodule ZevalWeb.DashboardLive.TenantLive do
  use ZevalWeb, :live_view
  import ZevalWeb.DashboardLive.Sidebar, only: [dashboard_layout: 1]

  alias ZevalCore.Tenants

  def mount(_params, session, socket) do
    {:ok, assign(socket,
      current_user: %{email: session["current_user_email"], name: session["current_user_name"]},
      tenants: Tenants.list(),
      show_create: false,
      new_name: "",
      error: nil
    )}
  end

  def render(assigns) do
    ~H"""
    <.dashboard_layout page_title="Zeval Engine — Tenants" current_user={@current_user} active="tenants">

      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold text-white">Tenants</h2>
        <button phx-click="show_create"
          class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium">
          + New Tenant
        </button>
      </div>

      <%= if @show_create do %>
        <div class="bg-gray-900 border border-gray-700 rounded-xl p-6 mb-6">
          <h3 class="text-lg font-semibold text-white mb-4">Create Tenant</h3>
          <%= if @error do %>
            <div class="bg-red-900/50 border border-red-700 text-red-300 px-4 py-3 rounded-lg mb-4 text-sm"><%= @error %></div>
          <% end %>
          <form phx-submit="create">
            <div class="flex gap-3 items-end">
              <div class="flex-1">
                <label class="block text-sm font-medium text-gray-300 mb-1">Name</label>
                <input type="text" name="name" phx-keyup="update_name" phx-debounce="200"
                  class="w-full bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-sm text-white"
                  placeholder="my-org" />
              </div>
              <button type="submit"
                class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium">Create</button>
              <button type="button" phx-click="hide_create"
                class="bg-gray-700 hover:bg-gray-600 text-gray-300 px-4 py-2 rounded-lg text-sm">Cancel</button>
            </div>
          </form>
        </div>
      <% end %>

      <div class="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-gray-800">
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Name</th>
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">ID</th>
              <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Created</th>
              <th class="text-right px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for tenant <- @tenants do %>
              <tr class="border-b border-gray-800 hover:bg-gray-800/50">
                <td class="px-4 py-3">
                  <a href={"/dashboard/tenants/#{tenant.id}"} class="text-blue-400 hover:text-blue-300 font-medium"><%= tenant.name %></a>
                </td>
                <td class="px-4 py-3 text-sm text-gray-400 font-mono"><%= String.slice(tenant.id, 0, 8) %>..</td>
                <td class="px-4 py-3 text-sm text-gray-400">
                  <%= if tenant.inserted_at do %>
                    <%= Calendar.strftime(tenant.inserted_at, "%Y-%m-%d") %>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-right">
                  <button phx-click="delete" phx-value-id={tenant.id}
                    phx-confirm="Delete this tenant and all its data?"
                    class="text-red-400 hover:text-red-300 text-sm">Delete</button>
                </td>
              </tr>
            <% end %>
            <%= if @tenants == [] do %>
              <tr><td colspan="4" class="px-4 py-8 text-center text-gray-500">No tenants yet. Create one to get started.</td></tr>
            <% end %>
          </tbody>
        </table>
      </div>

    </.dashboard_layout>
    """
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
    case Tenants.create(name) do
      {:ok, _tenant} ->
        {:noreply, assign(socket, tenants: Tenants.list(), show_create: false, new_name: "", error: nil)}
      {:error, changeset} ->
        msg = hd(hd(Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end) |> Map.values()))
        {:noreply, assign(socket, error: msg)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    Tenants.delete(id)
    {:noreply, assign(socket, tenants: Tenants.list())}
  end
end