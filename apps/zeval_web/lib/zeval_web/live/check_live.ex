defmodule ZevalWeb.DashboardLive.CheckLive do
  use ZevalWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active: "check", page_title: "Zeval Engine — Check Tool")}
  end

  def render(assigns) do
    ~H"""
    <h2 class="text-2xl font-bold text-white mb-4">Check Tool</h2>
    <p class="text-gray-400">Coming soon.</p>
    """
  end
end
