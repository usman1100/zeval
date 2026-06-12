defmodule ZevalWeb.DashboardLive.CheckLive do
  use ZevalWeb, :live_view
  import ZevalWeb.DashboardLive.Sidebar, only: [dashboard_layout: 1]

  def mount(_params, session, socket) do
    {:ok, assign(socket, current_user: %{email: session["current_user_email"], name: session["current_user_name"]}, active: "check")}
  end

  def render(assigns) do
    ~H"""
    <.dashboard_layout page_title="Zeval Engine — Check Tool" current_user={@current_user} active="check">
      <h2 class="text-2xl font-bold text-white mb-4">Check Tool</h2>
          <p class="text-gray-400">Coming soon.</p>
    </.dashboard_layout>
    """
  end
end
