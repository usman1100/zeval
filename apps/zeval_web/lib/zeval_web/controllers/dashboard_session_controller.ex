defmodule ZevalWeb.DashboardSessionController do
  use ZevalWeb, :controller

  alias ZevalCore.DashboardUsers

  plug :redirect_if_logged_in when action in [:new, :create]

  def new(conn, _params) do
    html = login_page_html(nil)
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html)
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case DashboardUsers.authenticate(email, password) do
      {:ok, user} ->
        return_to = get_session(conn, :return_to) || "/dashboard"

        conn
        |> put_session(:current_user_id, user.id)
        |> put_session(:current_user_email, user.email)
        |> put_session(:current_user_name, user.name)
        |> configure_session(renew: true)
        |> redirect(external: return_to)

      {:error, _reason} ->
        html = login_page_html("Invalid email or password")
        conn
        |> put_resp_header("content-type", "text/html; charset=utf-8")
        |> send_resp(200, html)
    end
  end

  def create(conn, _) do
    html = login_page_html("Email and password are required")
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html)
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: "/dashboard/login")
  end

  defp login_page_html(error) do
    error_html = if error do
      ~s(<div class="bg-red-900/50 border border-red-700 text-red-300 px-4 py-3 rounded-lg mb-4 text-sm">#{error}</div>)
    else
      ""
    end

    csrf = Plug.CSRFProtection.get_csrf_token()

    """
    <!DOCTYPE html>
    <html lang="en" class="bg-gray-950">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Zeval Engine — Login</title>
      <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-gray-950 text-gray-100 antialiased">
      <div class="min-h-screen flex items-center justify-center">
        <div class="w-full max-w-sm">
          <div class="text-center mb-8">
            <h1 class="text-2xl font-bold text-white">Zeval Engine</h1>
            <p class="text-gray-400 mt-1">Authorization Dashboard</p>
          </div>
          <div class="bg-gray-900 border border-gray-700 rounded-xl p-8">
            #{error_html}
            <form method="POST" action="/dashboard/login">
              <input name="_csrf_token" type="hidden" value="#{csrf}" />
              <div class="mb-4">
                <label for="email" class="block text-sm font-medium text-gray-300 mb-1">Email</label>
                <input type="email" name="email" id="email" required
                  class="w-full bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-sm text-white placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
                  placeholder="admin@example.com" />
              </div>
              <div class="mb-6">
                <label for="password" class="block text-sm font-medium text-gray-300 mb-1">Password</label>
                <input type="password" name="password" id="password" required
                  class="w-full bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-sm text-white placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none"
                  placeholder="••••••••" />
              </div>
              <button type="submit"
                class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2.5 rounded-lg text-sm transition-colors">
                Sign in
              </button>
            </form>
          </div>
        </div>
      </div>
    </body>
    </html>
    """
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