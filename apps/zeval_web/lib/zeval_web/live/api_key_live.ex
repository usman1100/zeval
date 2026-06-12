defmodule ZevalWeb.DashboardLive.ApiKeyLive do
  use ZevalWeb, :live_view
  import ZevalWeb.DashboardLive.Sidebar, only: [sidebar: 1]
  import Ecto.Query

  alias ZevalCore.{ServiceAccounts, Tenants, Repo}

  def mount(_params, session, socket) do
    {:ok, assign(socket,
      current_user: session["current_user"],
      accounts: all_accounts(),
      tenants: Tenants.list(),
      show_create: false,
      new_name: "",
      new_tenant_id: "",
      created_key: nil,
      error: nil
    )}
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="bg-gray-950">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Zeval Engine — API Keys</title>
      <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-950 text-gray-100 antialiased">
      <div class="flex min-h-screen bg-gray-950">
        <.sidebar current_user={@current_user} active="api-keys" />
        <main class="flex-1 p-8 overflow-y-auto">

          <div class="flex items-center justify-between mb-6">
            <h2 class="text-2xl font-bold text-white">API Keys</h2>
            <button phx-click="show_create"
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium">
              + New Key
            </button>
          </div>

          <%= if @show_create do %>
            <div class="bg-gray-900 border border-gray-700 rounded-xl p-6 mb-6">
              <h3 class="text-lg font-semibold text-white mb-4">Create API Key</h3>
              <%= if @error do %>
                <div class="bg-red-900/50 border border-red-700 text-red-300 px-4 py-3 rounded-lg mb-4 text-sm"><%= @error %></div>
              <% end %>
              <form phx-submit="create">
                <div class="mb-4">
                  <label class="block text-sm font-medium text-gray-300 mb-1">Tenant</label>
                  <select name="tenant_id" phx-change="select_tenant"
                    class="w-full bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-sm text-white">
                    <option value="">Select a tenant</option>
                    <%= for t <- @tenants do %>
                      <option value={t.id}><%= t.name %></option>
                    <% end %>
                  </select>
                </div>
                <div class="mb-4">
                  <label class="block text-sm font-medium text-gray-300 mb-1">Key Name</label>
                  <input type="text" name="name" phx-keyup="update_name" phx-debounce="200"
                    class="w-full bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-sm text-white"
                    placeholder="production-key" />
                </div>
                <div class="flex gap-3">
                  <button type="submit"
                    class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium">Generate Key</button>
                  <button type="button" phx-click="hide_create"
                    class="bg-gray-700 hover:bg-gray-600 text-gray-300 px-4 py-2 rounded-lg text-sm">Cancel</button>
                </div>
              </form>

              <%= if @created_key do %>
                <div class="mt-6 border-t border-gray-700 pt-4">
                  <div class="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4">
                    <p class="text-yellow-300 text-sm font-medium mb-2">⚠️ Save this key — it will not be shown again</p>
                    <div class="flex items-center gap-2">
                      <code class="flex-1 bg-gray-950 border border-gray-600 rounded-lg px-3 py-2 text-sm font-mono text-green-300 break-all"><%= @created_key %></code>
                      <button phx-click="copy_key" class="bg-gray-700 hover:bg-gray-600 text-white px-3 py-2 rounded-lg text-sm whitespace-nowrap">Copy</button>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <div class="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
            <table class="w-full">
              <thead>
                <tr class="border-b border-gray-800">
                  <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Name</th>
                  <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Prefix</th>
                  <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Status</th>
                  <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Last Used</th>
                  <th class="text-left px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Created</th>
                  <th class="text-right px-4 py-3 text-xs font-medium text-gray-400 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for acct <- @accounts do %>
                  <tr class="border-b border-gray-800 hover:bg-gray-800/50">
                    <td class="px-4 py-3 text-sm text-white font-medium"><%= acct.name %></td>
                    <td class="px-4 py-3 text-sm text-gray-400 font-mono"><%= acct.key_prefix %></td>
                    <td class="px-4 py-3">
                      <%= if acct.revoked_at do %>
                        <span class="bg-red-900 text-red-300 px-2 py-0.5 rounded-full text-xs">Revoked</span>
                      <% else %>
                        <span class="bg-green-900 text-green-300 px-2 py-0.5 rounded-full text-xs">Active</span>
                      <% end %>
                    </td>
                    <td class="px-4 py-3 text-sm text-gray-400">
                      <%= if acct.last_used_at do %>
                        <%= Calendar.strftime(acct.last_used_at, "%Y-%m-%d") %>
                      <% else %>
                        Never
                      <% end %>
                    </td>
                    <td class="px-4 py-3 text-sm text-gray-400">
                      <%= if acct.inserted_at do %>
                        <%= Calendar.strftime(acct.inserted_at, "%Y-%m-%d") %>
                      <% end %>
                    </td>
                    <td class="px-4 py-3 text-right">
                      <%= unless acct.revoked_at do %>
                        <button phx-click="revoke" phx-value-id={acct.id}
                          phx-confirm="Revoke this key? Existing integrations using it will stop working."
                          class="text-red-400 hover:text-red-300 text-sm">Revoke</button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
                <%= if @accounts == [] do %>
                  <tr><td colspan="6" class="px-4 py-8 text-center text-gray-500">No API keys yet.</td></tr>
                <% end %>
              </tbody>
            </table>
          </div>

        </main>
      </div>
    </body>
    </html>
    """
  end

  def handle_event("show_create", _, socket) do
    {:noreply, assign(socket, show_create: true, created_key: nil, error: nil)}
  end

  def handle_event("hide_create", _, socket) do
    {:noreply, assign(socket, show_create: false, created_key: nil, error: nil)}
  end

  def handle_event("select_tenant", %{"tenant_id" => id}, socket) do
    {:noreply, assign(socket, new_tenant_id: id)}
  end

  def handle_event("create", %{"name" => name, "tenant_id" => tid}, socket)
      when tid != "" and byte_size(name) > 0 do
    case ServiceAccounts.create(tid, name) do
      {:ok, %{raw_key: raw_key}} ->
        {:noreply, assign(socket,
          accounts: all_accounts(),
          created_key: raw_key,
          show_create: true,
          error: nil
        )}
      {:error, changeset} ->
        msg = hd(hd(Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end) |> Map.values()))
        {:noreply, assign(socket, error: msg)}
    end
  end

  def handle_event("create", _, socket) do
    {:noreply, assign(socket, error: "Tenant and name are required")}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    ServiceAccounts.revoke(id)
    {:noreply, assign(socket, accounts: all_accounts())}
  end

  def handle_event("copy_key", _, socket) do
    {:noreply, socket}
  end

  defp all_accounts do
    Repo.all(from a in ZevalCore.ServiceAccount, order_by: [desc: a.inserted_at])
  end
end