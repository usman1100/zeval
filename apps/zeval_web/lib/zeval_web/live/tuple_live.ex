defmodule ZevalWeb.DashboardLive.TupleLive do
  use ZevalWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active: "tuples", page_title: "Zeval Engine — Tuples")}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-stack-lg">
      <div>
        <nav class="flex items-center gap-2 font-label-mono text-label-mono mb-stack-xs">
          <span class="text-text-muted">Zeval Engine</span>
          <span class="text-text-muted">/</span>
          <span class="text-text-primary">Tuples</span>
        </nav>
        <h2 class="font-headline-lg text-headline-lg text-text-primary">Tuples</h2>
        <p class="text-text-secondary font-body-md text-body-md mt-1">Read, write, and delete relationship tuples.</p>
      </div>

      <div class="bg-surface border border-border-subtle p-stack-md flex flex-col items-center justify-center py-stack-lg gap-stack-md">
        <span class="material-symbols-outlined text-text-muted text-4xl">database</span>
        <p class="font-body-md text-body-md text-text-muted">Tuples management is coming soon.</p>
      </div>
    </div>
    """
  end
end
