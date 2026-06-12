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
    <html lang="en" class="dark">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <.live_title>{assigns[:page_title] || "Zeval Engine"}</.live_title>
        <script src="https://cdn.tailwindcss.com?plugins=forms,container-queries">
        </script>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet"/>
        <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap" rel="stylesheet"/>
        <style>
          .material-symbols-outlined {
            font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
            font-size: 18px;
          }
          .custom-scrollbar::-webkit-scrollbar {
            width: 4px;
            height: 4px;
          }
          .custom-scrollbar::-webkit-scrollbar-track {
            background: #0a0a0a;
          }
          .custom-scrollbar::-webkit-scrollbar-thumb {
            background: #262626;
          }
        </style>
        <script>
          tailwind.config = {
            darkMode: "class",
            theme: {
              extend: {
                "colors": {
                  "outline": "#8e9192",
                  "background": "#121314",
                  "on-tertiary-container": "#7a7979",
                  "on-error": "#690005",
                  "on-primary-fixed-variant": "#474646",
                  "on-tertiary-fixed-variant": "#474746",
                  "on-tertiary": "#303030",
                  "inverse-surface": "#e3e2e2",
                  "surface-dim": "#121314",
                  "on-background": "#e3e2e2",
                  "on-surface-variant": "#c4c7c7",
                  "primary": "#c9c6c5",
                  "text-secondary": "#a3a3a3",
                  "secondary-fixed": "#e5e2e1",
                  "on-surface": "#e3e2e2",
                  "tertiary-container": "#0a0a0a",
                  "primary-fixed-dim": "#c9c6c5",
                  "on-secondary-fixed": "#1c1b1b",
                  "surface-bright": "#393939",
                  "surface-container-lowest": "#0d0e0f",
                  "ruby-error": "#e11d48",
                  "surface-container": "#1f2020",
                  "surface-container-low": "#1b1c1c",
                  "secondary-container": "#474746",
                  "on-error-container": "#ffdad6",
                  "on-primary-fixed": "#1c1b1b",
                  "primary-container": "#0a0a0a",
                  "surface-container-highest": "#343535",
                  "primary-fixed": "#e5e2e1",
                  "on-primary-container": "#7b7979",
                  "secondary-fixed-dim": "#c8c6c5",
                  "tertiary": "#c8c6c5",
                  "on-secondary-fixed-variant": "#474746",
                  "error": "#ffb4ab",
                  "border-subtle": "#262626",
                  "surface-variant": "#343535",
                  "outline-variant": "#444748",
                  "inverse-on-surface": "#303031",
                  "inverse-primary": "#5f5e5e",
                  "tertiary-fixed-dim": "#c8c6c5",
                  "surface": "#121314",
                  "tertiary-fixed": "#e4e2e1",
                  "on-tertiary-fixed": "#1b1c1c",
                  "surface-container-high": "#292a2a",
                  "on-secondary": "#313030",
                  "text-muted": "#525252",
                  "error-container": "#93000a",
                  "on-primary": "#313030",
                  "surface-tint": "#c9c6c5",
                  "secondary": "#c8c6c5",
                  "emerald-success": "#10b981",
                  "text-primary": "#ffffff",
                  "on-secondary-container": "#b7b4b4"
                },
                "borderRadius": {
                  "DEFAULT": "0.125rem",
                  "lg": "0.25rem",
                  "xl": "0.5rem",
                  "full": "0.75rem"
                },
                "spacing": {
                  "container-max": "1440px",
                  "stack-lg": "1.5rem",
                  "stack-md": "1rem",
                  "stack-xs": "0.25rem",
                  "gutter": "1rem",
                  "stack-sm": "0.5rem",
                  "margin-page": "2rem"
                },
                "fontFamily": {
                  "label-mono": ["JetBrains Mono"],
                  "headline-lg": ["Inter"],
                  "body-sm": ["Inter"],
                  "code-block": ["JetBrains Mono"],
                  "body-md": ["Inter"],
                  "headline-md": ["Inter"]
                },
                "fontSize": {
                  "label-mono": ["12px", {"lineHeight": "16px", "letterSpacing": "0.02em", "fontWeight": "500"}],
                  "headline-lg": ["24px", {"lineHeight": "32px", "letterSpacing": "-0.02em", "fontWeight": "600"}],
                  "body-sm": ["12px", {"lineHeight": "18px", "fontWeight": "400"}],
                  "code-block": ["13px", {"lineHeight": "20px", "fontWeight": "400"}],
                  "body-md": ["14px", {"lineHeight": "20px", "fontWeight": "400"}],
                  "headline-md": ["20px", {"lineHeight": "28px", "letterSpacing": "-0.01em", "fontWeight": "600"}]
                }
              },
            },
          }
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
      <body class="bg-background text-on-background min-h-screen antialiased selection:bg-emerald-success selection:text-background">
        {@inner_content}
      </body>
    </html>
    """
  end

  attr(:current_user, :map, default: nil)
  attr(:active, :string, default: "")

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-background">
      <.sidebar current_user={@current_user} active={assigns[:active] || ""} />
      <main class="flex-1 flex flex-col min-w-0 bg-background">
        <div class="flex-1 overflow-y-auto custom-scrollbar">
          <div class="p-margin-page max-w-container-max mx-auto w-full">
            {@inner_content}
          </div>
        </div>
      </main>
    </div>
    """
  end
end
