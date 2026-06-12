defmodule ZevalWeb.DashboardLive.NamespaceLive do
  use ZevalWeb, :live_view
  import ZevalWeb.DashboardLive.Sidebar, only: [sidebar: 1]

  def mount(_params, session, socket) do
    {:ok, assign(socket, current_user: %{email: session["current_user_email"], name: session["current_user_name"]}, active: "namespaces")}
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="bg-gray-950">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Zeval Engine &mdash; Namespaces</title>
      <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-950 text-gray-100 antialiased">
      <div class="flex min-h-screen bg-gray-950">
        <.sidebar current_user={@current_user} active={@active} />
        <main class="flex-1 p-8 overflow-y-auto">
          <h2 class="text-2xl font-bold text-white mb-4">Namespaces</h2>
          <p class="text-gray-400">Coming soon.</p>
        </main>
      </div>
    </body>
    </html>
    """
  end
end
