defmodule ZevalWeb.DashboardLive.Sidebar do
  @moduledoc """
  Shared sidebar component for dashboard pages.
  """
  use Phoenix.Component

  attr :current_user, :map, default: nil
  attr :active, :string, default: ""
  attr :page_title, :string, default: "Zeval Engine"
  slot :inner_block, required: true

  def dashboard_layout(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="bg-gray-950">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title><%= @page_title %></title>
      <script src="https://cdn.tailwindcss.com"></script>
      <script type="text/javascript" src="/assets/phoenix.js"></script>
    <script type="text/javascript" src="/assets/phoenix_live_view.js"></script>
    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {})
      liveSocket.connect()
    </script>
    </head>
    <body class="bg-gray-950 text-gray-100 antialiased">
      <div class="flex min-h-screen bg-gray-950">
        <.sidebar current_user={@current_user} active={@active} />
        <main class="flex-1 p-8 overflow-y-auto">
          <%= render_slot(@inner_block) %>
        </main>
      </div>
    </body>
    </html>
    """
  end

  attr :current_user, :map, default: nil
  attr :active, :string, default: ""

  def sidebar(assigns) do
    ~H"""
    <aside class="w-64 bg-gray-900 border-r border-gray-800 p-4 flex flex-col min-h-screen">
      <div class="mb-8">
        <h1 class="text-lg font-bold text-white">Zeval Engine</h1>
        <p class="text-xs text-gray-500">Dashboard</p>
      </div>

      <nav class="flex-1 space-y-1">
        <.nav_link href="/dashboard" active={@active == "home"}>Home</.nav_link>
        <.nav_link href="/dashboard/tenants" active={@active == "tenants"}>Tenants</.nav_link>
        <.nav_link href="/dashboard/api-keys" active={@active == "api-keys"}>API Keys</.nav_link>
        <.nav_link href="/dashboard/namespaces" active={@active == "namespaces"}>Namespaces</.nav_link>
        <.nav_link href="/dashboard/tuples" active={@active == "tuples"}>Tuples</.nav_link>
        <.nav_link href="/dashboard/check" active={@active == "check"}>Check</.nav_link>
        <.nav_link href="/dashboard/expand" active={@active == "expand"}>Expand</.nav_link>
      </nav>

      <div class="border-t border-gray-800 pt-4 mt-4">
        <div class="text-sm text-gray-400">
          <%= if @current_user, do: @current_user[:email] || "User" %>
        </div>
        <a href="/dashboard/logout" class="text-xs text-gray-500 hover:text-gray-300">Sign out</a>
      </div>
    </aside>
    """
  end

  attr :href, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: false

  def nav_link(assigns) do
    ~H"""
    <a href={@href}
      class={"flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-colors " <>
        (if @active, do: "bg-gray-800 text-white", else: "text-gray-400 hover:text-white hover:bg-gray-800")}>
      <%= render_slot(@inner_block) %>
    </a>
    """
  end
end