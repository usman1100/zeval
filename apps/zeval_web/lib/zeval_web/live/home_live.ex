defmodule ZevalWeb.DashboardLive.HomeLive do
  use ZevalWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, active: "home", page_title: "Zeval Engine — Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-stack-lg">
      <div class="flex items-end justify-between">
        <div>
          <nav class="flex items-center gap-stack-xs font-label-mono text-label-mono mb-stack-xs">
            <span class="text-text-muted">Engine</span>
            <span class="text-text-muted">/</span>
            <span class="text-text-primary">Dashboard</span>
          </nav>
          <h2 class="font-headline-lg text-headline-lg text-text-primary">System Overview</h2>
        </div>
        <div class="flex gap-stack-sm">
          <a href="/dashboard/namespaces/new"
            class="bg-emerald-success text-background px-stack-md py-2 font-label-mono text-label-mono font-bold flex items-center gap-2 hover:opacity-90 transition-opacity">
            <span class="material-symbols-outlined">add</span>
            New Namespace
          </a>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-stack-md">
        <div class="bg-surface border border-border-subtle p-stack-md flex flex-col gap-stack-sm">
          <div class="flex justify-between items-start">
            <span class="text-text-secondary font-label-mono text-label-mono uppercase">Total Tenants</span>
            <span class="material-symbols-outlined text-text-muted">corporate_fare</span>
          </div>
          <div class="flex items-baseline gap-2">
            <span class="text-[32px] font-bold text-text-primary leading-none">-</span>
          </div>
        </div>
        <div class="bg-surface border border-border-subtle p-stack-md flex flex-col gap-stack-sm">
          <div class="flex justify-between items-start">
            <span class="text-text-secondary font-label-mono text-label-mono uppercase">Namespaces</span>
            <span class="material-symbols-outlined text-text-muted">dns</span>
          </div>
          <div class="flex items-baseline gap-2">
            <span class="text-[32px] font-bold text-text-primary leading-none">-</span>
          </div>
        </div>
        <div class="bg-surface border border-border-subtle p-stack-md flex flex-col gap-stack-sm">
          <div class="flex justify-between items-start">
            <span class="text-text-secondary font-label-mono text-label-mono uppercase">Total Tuples</span>
            <span class="material-symbols-outlined text-text-muted">database</span>
          </div>
          <div class="flex items-baseline gap-2">
            <span class="text-[32px] font-bold text-text-primary leading-none">-</span>
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-stack-md bg-surface border border-border-subtle overflow-hidden">
        <div class="px-stack-md py-stack-sm border-b border-border-subtle flex items-center justify-between bg-surface-container-low">
          <h3 class="font-headline-md text-headline-md text-text-primary flex items-center gap-2">
            <span class="material-symbols-outlined">history</span>
            Recent Activity
          </h3>
          <div class="flex items-center gap-stack-sm">
            <span class="w-2 h-2 rounded-full bg-emerald-success"></span>
            <span class="font-label-mono text-label-mono text-emerald-success">Live Engine Feed</span>
          </div>
        </div>
        <div class="p-stack-md">
          <p class="text-text-secondary font-body-md text-body-md">Activity feed will appear here once the engine processes authorization checks.</p>
        </div>
        <div class="px-stack-md py-stack-sm border-t border-border-subtle flex justify-center bg-surface-container-lowest">
          <a href="/dashboard/check" class="font-label-mono text-label-mono text-text-muted hover:text-text-primary transition-colors flex items-center gap-1">
            Run a Check
            <span class="material-symbols-outlined">arrow_forward</span>
          </a>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-stack-lg">
        <div class="bg-surface border border-border-subtle p-stack-md flex flex-col gap-stack-md">
          <h4 class="font-label-mono text-label-mono uppercase text-text-secondary">Quick Actions</h4>
          <div class="flex flex-wrap gap-stack-sm">
            <a href="/dashboard/namespaces" class="bg-surface-container-high border border-border-subtle text-text-primary px-stack-md py-2 font-label-mono text-label-mono flex items-center gap-2 hover:bg-surface-container-highest transition-colors">
              <span class="material-symbols-outlined">dns</span>
              Namespaces
            </a>
            <a href="/dashboard/check" class="bg-surface-container-high border border-border-subtle text-text-primary px-stack-md py-2 font-label-mono text-label-mono flex items-center gap-2 hover:bg-surface-container-highest transition-colors">
              <span class="material-symbols-outlined">fact_check</span>
              Check Access
            </a>
            <a href="/dashboard/api-keys" class="bg-surface-container-high border border-border-subtle text-text-primary px-stack-md py-2 font-label-mono text-label-mono flex items-center gap-2 hover:bg-surface-container-highest transition-colors">
              <span class="material-symbols-outlined">vpn_key</span>
              Create API Key
            </a>
          </div>
        </div>
        <div class="bg-surface border border-border-subtle overflow-hidden relative">
          <div class="absolute inset-0 bg-gradient-to-t from-background via-transparent to-transparent pointer-events-none"></div>
          <div class="p-stack-md relative">
            <h4 class="font-headline-md text-headline-md text-text-primary mb-1">High-Performance Engine</h4>
            <p class="font-body-sm text-body-sm text-text-secondary max-w-xs">Zeval Engine provides ultra-low-latency authorization checks powered by a Zanzibar-inspired architecture.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
