defmodule ZevalWeb.DashboardLive.HomeLive do
  use ZevalWeb, :live_view
  import ZevalWeb.DashboardLive.Sidebar, only: [dashboard_layout: 1]

  def mount(_params, session, socket) do
    {:ok, assign(socket, current_user: %{email: session["current_user_email"], name: session["current_user_name"]})}
  end

  def render(assigns) do
    ~H"""
    <.dashboard_layout page_title="Zeval Engine — Dashboard" current_user={@current_user}>
      <h2 class="text-2xl font-bold text-white mb-6">Dashboard</h2>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="bg-gray-900 border border-gray-800 rounded-xl p-6">
          <div class="text-sm text-gray-400 mb-1">Tenants</div>
          <div class="text-3xl font-bold text-white">-</div>
        </div>
        <div class="bg-gray-900 border border-gray-800 rounded-xl p-6">
          <div class="text-sm text-gray-400 mb-1">Namespaces</div>
          <div class="text-3xl font-bold text-white">-</div>
        </div>
        <div class="bg-gray-900 border border-gray-800 rounded-xl p-6">
          <div class="text-sm text-gray-400 mb-1">Tuples</div>
          <div class="text-3xl font-bold text-white">-</div>
        </div>
      </div>

      <div class="bg-gray-900 border border-gray-800 rounded-xl p-6">
        <h3 class="text-lg font-semibold text-white mb-4">Quick Actions</h3>
        <div class="flex flex-wrap gap-3">
          <a href="/dashboard/namespaces" class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm">New Namespace</a>
          <a href="/dashboard/check" class="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg text-sm">Check Access</a>
          <a href="/dashboard/api-keys" class="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg text-sm">Create API Key</a>
        </div>
      </div>
    </.dashboard_layout>
    """
  end
end