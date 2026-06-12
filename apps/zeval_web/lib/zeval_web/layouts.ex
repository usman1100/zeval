defmodule ZevalWeb.Layouts do
  @moduledoc """
  Root and app layouts for the dashboard.

  `root/1` is the HTML shell rendered once on the initial HTTP request — it
  carries the CSRF token the LiveView socket needs to connect. `app/1` is the
  dashboard chrome (sidebar + main) wrapped around each LiveView's content.

  Replacing the previous per-LiveView self-contained HTML restores live
  navigation, removes ~600 lines of duplicated markup, and gives the socket a
  CSRF token (required now that `protect_from_forgery` is enabled).
  """
  use Phoenix.Component

  import ZevalWeb.DashboardLive.Sidebar, only: [sidebar: 1]

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="bg-gray-950">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <.live_title>{assigns[:page_title] || "Zeval Engine"}</.live_title>
        <script src="https://cdn.tailwindcss.com">
        </script>
        <script type="text/javascript" src="/assets/phoenix.js">
        </script>
        <script type="text/javascript" src="/assets/phoenix_live_view.js">
        </script>
        <script>
          let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
          let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
            params: {_csrf_token: csrfToken}
          })
          liveSocket.connect()
        </script>
      </head>
      <body class="bg-gray-950 text-gray-100 antialiased">
        {@inner_content}
      </body>
    </html>
    """
  end

  attr(:current_user, :map, default: nil)
  attr(:active, :string, default: "")

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-950">
      <.sidebar current_user={@current_user} active={assigns[:active] || ""} />
      <main class="flex-1 p-8 overflow-y-auto">
        {@inner_content}
      </main>
    </div>
    """
  end
end
