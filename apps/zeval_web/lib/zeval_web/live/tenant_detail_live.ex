defmodule ZevalWeb.DashboardLive.TenantDetailLive do
  use ZevalWeb, :live_view
import ZevalWeb.DashboardLive.Sidebar, only: [sidebar: 1]

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active: "tenants")}
  end

  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-950">
      <.sidebar current_user={@current_user} active={@active} />
      <main class="flex-1 p-8 overflow-y-auto">
        <h2 class="text-2xl font-bold text-white mb-4">Tenant</h2>
        <p class="text-gray-400">Coming soon.</p>
      </main>
    </div>
    """
  end
end
