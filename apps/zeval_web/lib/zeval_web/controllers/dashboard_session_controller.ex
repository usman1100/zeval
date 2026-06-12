defmodule ZevalWeb.DashboardSessionController do
  use ZevalWeb, :controller

  alias ZevalCore.DashboardUsers

  plug(:redirect_if_logged_in when action in [:new, :create, :signup_new, :signup_create])

  # -- Login --

  # Static markup; the only dynamic value (error message) is HTML-escaped in
  # error_html/1 and the CSRF token is generated server-side.
  # sobelow_skip ["XSS.SendResp"]
  def new(conn, _params) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, login_page_html(nil))
  end

  # sobelow_skip ["XSS.SendResp"]
  def create(conn, %{"email" => email, "password" => password}) do
    case DashboardUsers.authenticate(email, password) do
      {:ok, user} ->
        set_session_and_redirect(conn, user)

      {:error, _reason} ->
        conn
        |> put_resp_header("content-type", "text/html; charset=utf-8")
        |> send_resp(200, login_page_html("Invalid email or password"))
    end
  end

  # sobelow_skip ["XSS.SendResp"]
  def create(conn, _) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, login_page_html("Email and password are required"))
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: "/dashboard/login")
  end

  # -- Signup --

  # sobelow_skip ["XSS.SendResp"]
  def signup_new(conn, _params) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, signup_page_html(nil))
  end

  # sobelow_skip ["XSS.SendResp"]
  def signup_create(conn, %{"name" => name, "email" => email, "password" => password}) do
    case DashboardUsers.create(%{name: name, email: email, password: password}) do
      {:ok, user} ->
        set_session_and_redirect(conn, user)

      {:error, changeset} ->
        msg = format_errors(changeset)

        conn
        |> put_resp_header("content-type", "text/html; charset=utf-8")
        |> send_resp(200, signup_page_html(msg))
    end
  end

  # sobelow_skip ["XSS.SendResp"]
  def signup_create(conn, _) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, signup_page_html("Name, email, and password are required"))
  end

  # -- Shared --

  defp set_session_and_redirect(conn, user) do
    return_to = get_session(conn, :return_to) || "/dashboard"

    conn
    |> put_session(:current_user_id, user.id)
    |> put_session(:current_user_email, user.email)
    |> put_session(:current_user_name, user.name)
    |> configure_session(renew: true)
    |> redirect(external: return_to)
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(List.wrap(errors), ", ")}"
    end)
    |> Enum.join("; ")
  end

  # -- Login HTML --

  defp login_page_html(error) do
    error_html = error_html(error)
    csrf = Plug.CSRFProtection.get_csrf_token()

    ~s"""
    <!DOCTYPE html>
    <html lang="en" class="dark">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Zeval Engine — Login</title>
      <script src="https://cdn.tailwindcss.com?plugins=forms"></script>
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet"/>
      <script>
        tailwind.config = {
          darkMode: "class",
          theme: {
            extend: {
              colors: {
                "background": "#121314",
                "surface": "#121314",
                "surface-container-lowest": "#0d0e0f",
                "surface-container-low": "#1b1c1c",
                "surface-container": "#1f2020",
                "surface-container-high": "#292a2a",
                "surface-container-highest": "#343535",
                "border-subtle": "#262626",
                "emerald-success": "#10b981",
                "ruby-error": "#e11d48",
                "text-primary": "#ffffff",
                "text-secondary": "#a3a3a3",
                "text-muted": "#525252",
                "primary": "#c9c6c5",
                "secondary-container": "#474746",
                "on-secondary-container": "#b7b4b4"
              },
              fontFamily: {
                "label-mono": ["JetBrains Mono"],
                "body-md": ["Inter"]
              },
              fontSize: {
                "label-mono": ["12px", {"lineHeight": "16px", "letterSpacing": "0.02em", "fontWeight": "500"}],
                "body-md": ["14px", {"lineHeight": "20px", "fontWeight": "400"}]
              }
            }
          }
        }
      </script>
    </head>
    <body class="bg-background text-text-secondary antialiased min-h-screen flex items-center justify-center">
      <div class="w-full max-w-sm px-4">
        <div class="text-center mb-8">
          <div class="w-12 h-12 mx-auto mb-4 bg-surface-container-highest border border-border-subtle flex items-center justify-center">
            <span class="text-primary font-label-mono text-xl">Z</span>
          </div>
          <h1 class="font-body-md text-body-md text-text-primary font-semibold">Zeval Engine</h1>
          <p class="font-label-mono text-label-mono text-text-muted mt-1">Authorization Dashboard</p>
        </div>
        <div class="bg-surface border border-border-subtle p-8">
          #{error_html}
          <form method="POST" action="/dashboard/login">
            <input name="_csrf_token" type="hidden" value="#{csrf}" />
            <div class="mb-4">
              <label for="email" class="block font-label-mono text-label-mono text-text-muted mb-1">Email</label>
              <input type="email" name="email" id="email" required
                class="w-full bg-surface-container-lowest border border-border-subtle font-label-mono text-label-mono text-text-primary px-3 py-2 focus:border-white focus:ring-0 transition-colors"
                placeholder="admin@example.com" />
            </div>
            <div class="mb-6">
              <label for="password" class="block font-label-mono text-label-mono text-text-muted mb-1">Password</label>
              <input type="password" name="password" id="password" required
                class="w-full bg-surface-container-lowest border border-border-subtle font-label-mono text-label-mono text-text-primary px-3 py-2 focus:border-white focus:ring-0 transition-colors"
                placeholder="••••••••" />
            </div>
            <button type="submit"
              class="w-full bg-emerald-success text-background font-label-mono text-label-mono font-bold py-2.5 hover:opacity-90 transition-opacity">
              Sign in
            </button>
          </form>
          <p class="text-center text-text-muted font-body-md text-body-md mt-6">
            No account?
            <a href="/dashboard/signup" class="text-text-primary hover:text-text-secondary font-label-mono">Create one</a>
          </p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  # -- Signup HTML --

  defp signup_page_html(error) do
    error_html = error_html(error)
    csrf = Plug.CSRFProtection.get_csrf_token()

    ~s"""
    <!DOCTYPE html>
    <html lang="en" class="dark">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Zeval Engine — Sign Up</title>
      <script src="https://cdn.tailwindcss.com?plugins=forms"></script>
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet"/>
      <script>
        tailwind.config = {
          darkMode: "class",
          theme: {
            extend: {
              colors: {
                "background": "#121314",
                "surface": "#121314",
                "surface-container-lowest": "#0d0e0f",
                "surface-container-low": "#1b1c1c",
                "surface-container": "#1f2020",
                "surface-container-high": "#292a2a",
                "surface-container-highest": "#343535",
                "border-subtle": "#262626",
                "emerald-success": "#10b981",
                "ruby-error": "#e11d48",
                "text-primary": "#ffffff",
                "text-secondary": "#a3a3a3",
                "text-muted": "#525252",
                "primary": "#c9c6c5",
                "secondary-container": "#474746",
                "on-secondary-container": "#b7b4b4"
              },
              fontFamily: {
                "label-mono": ["JetBrains Mono"],
                "body-md": ["Inter"]
              },
              fontSize: {
                "label-mono": ["12px", {"lineHeight": "16px", "letterSpacing": "0.02em", "fontWeight": "500"}],
                "body-md": ["14px", {"lineHeight": "20px", "fontWeight": "400"}]
              }
            }
          }
        }
      </script>
    </head>
    <body class="bg-background text-text-secondary antialiased min-h-screen flex items-center justify-center">
      <div class="w-full max-w-sm px-4">
        <div class="text-center mb-8">
          <div class="w-12 h-12 mx-auto mb-4 bg-surface-container-highest border border-border-subtle flex items-center justify-center">
            <span class="text-primary font-label-mono text-xl">Z</span>
          </div>
          <h1 class="font-body-md text-body-md text-text-primary font-semibold">Zeval Engine</h1>
          <p class="font-label-mono text-label-mono text-text-muted mt-1">Create your account</p>
        </div>
        <div class="bg-surface border border-border-subtle p-8">
          #{error_html}
          <form method="POST" action="/dashboard/signup">
            <input name="_csrf_token" type="hidden" value="#{csrf}" />
            <div class="mb-4">
              <label for="name" class="block font-label-mono text-label-mono text-text-muted mb-1">Name</label>
              <input type="text" name="name" id="name" required
                class="w-full bg-surface-container-lowest border border-border-subtle font-label-mono text-label-mono text-text-primary px-3 py-2 focus:border-white focus:ring-0 transition-colors"
                placeholder="Jane Smith" />
            </div>
            <div class="mb-4">
              <label for="email" class="block font-label-mono text-label-mono text-text-muted mb-1">Email</label>
              <input type="email" name="email" id="email" required
                class="w-full bg-surface-container-lowest border border-border-subtle font-label-mono text-label-mono text-text-primary px-3 py-2 focus:border-white focus:ring-0 transition-colors"
                placeholder="jane@example.com" />
            </div>
            <div class="mb-6">
              <label for="password" class="block font-label-mono text-label-mono text-text-muted mb-1">Password</label>
              <input type="password" name="password" id="password" required minlength="12"
                class="w-full bg-surface-container-lowest border border-border-subtle font-label-mono text-label-mono text-text-primary px-3 py-2 focus:border-white focus:ring-0 transition-colors"
                placeholder="At least 12 characters" />
            </div>
            <button type="submit"
              class="w-full bg-emerald-success text-background font-label-mono text-label-mono font-bold py-2.5 hover:opacity-90 transition-opacity">
              Create account
            </button>
          </form>
          <p class="text-center text-text-muted font-body-md text-body-md mt-6">
            Already have one?
            <a href="/dashboard/login" class="text-text-primary hover:text-text-secondary font-label-mono">Sign in</a>
          </p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  # -- Shared helpers --

  defp error_html(nil), do: ""
  defp error_html(""), do: ""

  defp error_html(msg) do
    # Escape the message — it can include changeset field names/values. The
    # surrounding markup is static.
    safe = msg |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

    ~s(<div class="bg-ruby-error/10 border border-ruby-error/30 text-ruby-error px-4 py-3 mb-4 font-label-mono text-label-mono">#{safe}</div>)
  end

  defp redirect_if_logged_in(conn, _opts) do
    if get_session(conn, :current_user_id) do
      conn
      |> redirect(to: "/dashboard")
      |> halt()
    else
      conn
    end
  end
end
