defmodule ZevalWeb.DashboardLive.Sidebar do
  @moduledoc """
  Sidebar navigation for the dashboard, rendered by `ZevalWeb.Layouts.app/1`.
  """
  use Phoenix.Component

  attr(:current_user, :any, default: nil)
  attr(:active, :string, default: "")

  def sidebar(assigns) do
    ~H"""
    <aside class="w-[260px] h-screen sticky top-0 left-0 border-r border-border-subtle bg-surface flex flex-col p-stack-md shrink-0">
      <div class="mb-stack-lg">
        <h1 class="font-headline-md text-headline-md font-bold text-primary">Zeval Engine</h1>
        <p class="font-label-mono text-label-mono text-text-muted">v1.2.4-stable</p>
      </div>
      <nav class="flex-1 space-y-stack-xs overflow-y-auto custom-scrollbar">
        <.nav_link href="/dashboard" icon="home" active={@active == "home"}>Home</.nav_link>
        <.nav_link href="/dashboard/tenants" icon="corporate_fare" active={@active == "tenants"}>Tenants</.nav_link>
        <.nav_link href="/dashboard/api-keys" icon="vpn_key" active={@active == "api-keys"}>API Keys</.nav_link>
        <.nav_link href="/dashboard/namespaces" icon="dns" active={@active == "namespaces"}>Namespaces</.nav_link>
        <.nav_link href="/dashboard/tuples" icon="database" active={@active == "tuples"}>Tuples</.nav_link>
        <.nav_link href="/dashboard/check" icon="fact_check" active={@active == "check"}>Check Tool</.nav_link>
        <.nav_link href="/dashboard/expand" icon="unfold_more" active={@active == "expand"}>Expand Tool</.nav_link>
        <.nav_link href="/dashboard/docs" icon="menu_book" active={@active == "docs"}>API Reference</.nav_link>
      </nav>
      <div class="mt-auto pt-stack-md border-t border-border-subtle space-y-stack-xs">
        <.nav_link href="/dashboard/logout" icon="logout" active={false}>Sign Out</.nav_link>
      </div>
    </aside>
    """
  end

  attr(:href, :string, required: true)
  attr(:icon, :string, default: "circle")
  attr(:active, :boolean, default: false)
  slot(:inner_block, required: false)

  def nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={
        "flex items-center gap-stack-sm px-stack-sm py-2 rounded duration-200 ease-in-out " <>
          if @active,
            do: "bg-secondary-container text-on-secondary-container",
            else: "text-text-secondary hover:text-text-primary hover:bg-surface-container-highest"
      }
    >
      <span class="material-symbols-outlined">{@icon}</span>
      <span class="font-body-md text-body-md">{render_slot(@inner_block)}</span>
    </a>
    """
  end
end
