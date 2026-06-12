defmodule ZevalWeb.DashboardLive.TupleLive do
  use ZevalWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active: "tuples", page_title: "Zeval Engine — Tuples")}
  end

  def render(assigns) do
    ~H"""
    <h2 class="text-2xl font-bold text-white mb-4">Tuples</h2>
    <p class="text-gray-400">Coming soon.</p>
    """
  end
end
