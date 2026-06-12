defmodule ZevalWeb.DashboardLive.Sidebar do
  @moduledoc """
  Sidebar navigation for the dashboard, rendered by `ZevalWeb.Layouts.app/1`.
  """
  use Phoenix.Component

  attr(:current_user, :any, default: nil)
  attr(:active, :string, default: "")

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
        <div class="text-sm text-gray-400">{user_email(@current_user)}</div>
        <a href="/dashboard/logout" class="text-xs text-gray-500 hover:text-gray-300">Sign out</a>
      </div>
    </aside>
    """
  end

  attr(:href, :string, required: true)
  attr(:active, :boolean, default: false)
  slot(:inner_block, required: false)

  def nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={
        "flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-colors " <>
          if @active, do: "bg-gray-800 text-white", else: "text-gray-400 hover:text-white hover:bg-gray-800"
      }
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  defp user_email(%{email: email}) when is_binary(email), do: email
  defp user_email(_), do: "User"
end
