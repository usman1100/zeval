defmodule ZevalWeb.DashboardLive.TenantDetailLive do
  use ZevalWeb, :live_view
  import ZevalWeb.DashboardLive.Sidebar, only: [sidebar: 1]
  import Ecto.Query

  alias ZevalCore.{Tenants, Repo, ServiceAccounts}

  def mount(%{"id" => id}, session, socket) do
    tenant = Tenants.get(id)
    accounts = ServiceAccounts.list(id)
    namespaces = Repo.all(
      from n in ZevalCore.Namespace.NamespaceConfig, where: n.tenant_id == ^id, order_by: n.name
    )

    {:ok, assign(socket,
      current_user: session["current_user"],
      tenant: tenant,
      accounts: accounts,
      namespaces: namespaces
    )}
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="bg-gray-950">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Zeval Engine — Tenant</title>
      <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-950 text-gray-100 antialiased">
      <div class="flex min-h-screen bg-gray-950">
        <.sidebar current_user={@current_user} active="tenants" />
        <main class="flex-1 p-8 overflow-y-auto">

          <a href="/dashboard/tenants" class="text-blue-400 hover:text-blue-300 text-sm mb-4 inline-block">&larr; Back to Tenants</a>

          <div class="bg-gray-900 border border-gray-800 rounded-xl p-6 mb-6">
            <h2 class="text-2xl font-bold text-white mb-2"><%= @tenant.name %></h2>
            <p class="text-sm text-gray-400 font-mono mb-4">ID: <%= @tenant.id %></p>
            <div class="flex gap-3">
              <a href={"/dashboard/api-keys"} class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm">Create API Key</a>
              <a href={"/dashboard/namespaces"} class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg text-sm">New Namespace</a>
            </div>
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="bg-gray-900 border border-gray-800 rounded-xl p-6">
              <h3 class="text-lg font-semibold text-white mb-4">Service Accounts</h3>
              <%= if @accounts == [] do %>
                <p class="text-gray-500 text-sm">No service accounts.</p>
              <% else %>
                <div class="space-y-2">
                  <%= for acct <- @accounts do %>
                    <div class="flex items-center justify-between py-2 border-b border-gray-800 last:border-0">
                      <div>
                        <div class="text-sm text-white"><%= acct.name %></div>
                        <div class="text-xs text-gray-500 font-mono"><%= acct.key_prefix %>..</div>
                      </div>
                      <span class="bg-green-900 text-green-300 px-2 py-0.5 rounded-full text-xs">Active</span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <div class="bg-gray-900 border border-gray-800 rounded-xl p-6">
              <h3 class="text-lg font-semibold text-white mb-4">Namespaces</h3>
              <%= if @namespaces == [] do %>
                <p class="text-gray-500 text-sm">No namespaces defined.</p>
              <% else %>
                <div class="space-y-2">
                  <%= for ns <- @namespaces do %>
                    <div class="flex items-center justify-between py-2 border-b border-gray-800 last:border-0">
                      <div>
                        <div class="text-sm text-white"><%= ns.name %></div>
                        <div class="text-xs text-gray-500">v<%= ns.version %></div>
                      </div>
                      <a href={"/dashboard/namespaces"} class="text-blue-400 hover:text-blue-300 text-xs">View</a>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>

        </main>
      </div>
    </body>
    </html>
    """
  end
end