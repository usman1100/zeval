defmodule ZevalWeb.DashboardLive.CheckLive do
  use ZevalWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active: "check", page_title: "Zeval Engine — Check Tool")}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-stack-lg">
      <div>
        <nav class="flex items-center gap-2 font-label-mono text-label-mono mb-stack-xs">
          <span class="text-text-muted">Zeval Engine</span>
          <span class="text-text-muted">/</span>
          <span class="text-text-primary">Check Tool</span>
        </nav>
        <h2 class="font-headline-lg text-headline-lg text-text-primary">Permission Checker</h2>
        <p class="text-text-secondary font-body-md text-body-md mt-1">Interactive permission testing with resolution tree.</p>
      </div>

      <div class="bg-surface border border-border-subtle p-stack-md flex flex-col items-center justify-center py-stack-lg gap-stack-md">
        <span class="material-symbols-outlined text-text-muted text-4xl">fact_check</span>
        <p class="font-body-md text-body-md text-text-muted">Check tool is coming soon.</p>
      </div>
    </div>
    """
  end
end
