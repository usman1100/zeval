defmodule ZevalWeb.DashboardLive.ExpandLive do
  use ZevalWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active: "expand", page_title: "Zeval Engine — Expand")}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-stack-lg">
      <div>
        <nav class="flex items-center gap-2 font-label-mono text-label-mono mb-stack-xs">
          <span class="text-text-muted">Zeval Engine</span>
          <span class="text-text-muted">/</span>
          <span class="text-text-primary">Expand Tool</span>
        </nav>
        <h2 class="font-headline-lg text-headline-lg text-text-primary">Expand Tool</h2>
        <p class="text-text-secondary font-body-md text-body-md mt-1">View all users with access to a resource.</p>
      </div>

      <div class="bg-surface border border-border-subtle p-stack-md flex flex-col items-center justify-center py-stack-lg gap-stack-md">
        <span class="material-symbols-outlined text-text-muted text-4xl">unfold_more</span>
        <p class="font-body-md text-body-md text-text-muted">Expand tool is coming soon.</p>
      </div>
    </div>
    """
  end
end
