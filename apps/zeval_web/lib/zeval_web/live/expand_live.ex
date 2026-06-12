defmodule ZevalWeb.DashboardLive.ExpandLive do
  use ZevalWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active: "expand", page_title: "Zeval Engine — Expand")}
  end

  def render(assigns) do
    ~H"""
    <h2 class="text-2xl font-bold text-white mb-4">Expand</h2>
    <p class="text-gray-400">Coming soon.</p>
    """
  end
end
