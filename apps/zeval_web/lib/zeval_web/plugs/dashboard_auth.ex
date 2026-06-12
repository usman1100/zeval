defmodule ZevalWeb.Plugs.DashboardAuth do
  @moduledoc """
  Session-based auth for `/dashboard/*` routes.

  Checks for a valid `current_user_id` in the session. Redirects to
  `/dashboard/login` if not authenticated, preserving the intended path
  in `:return_to` for post-login redirect.
  """

  import Plug.Conn
  alias ZevalCore.DashboardUsers

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :current_user_id) do
      nil ->
        conn
        |> put_session(:return_to, conn.request_path)
        |> Phoenix.Controller.redirect(to: "/dashboard/login")
        |> halt()

      user_id ->
        case DashboardUsers.get(user_id) do
          nil ->
            conn
            |> delete_session(:current_user_id)
            |> Phoenix.Controller.redirect(to: "/dashboard/login")
            |> halt()

          user ->
            assign(conn, :current_user, user)
        end
    end
  end
end
