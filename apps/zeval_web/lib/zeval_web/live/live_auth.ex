defmodule ZevalWeb.LiveAuth do
  @moduledoc """
  `on_mount` hook for dashboard LiveViews.

  The `DashboardAuth` plug only guards the initial HTTP request. Without this
  hook the WebSocket mount (and any live navigation) would trust the session
  blindly. This re-loads the user from the DB on every mount — connected and
  disconnected — and halts to the login page if the session is missing or the
  user no longer exists.

  On success it assigns `:current_user`, so LiveViews never trust unverified
  ids copied out of the session.
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  alias ZevalCore.DashboardUsers

  def on_mount(:default, _params, session, socket) do
    case session["current_user_id"] && DashboardUsers.get(session["current_user_id"]) do
      %_{} = user ->
        {:cont, assign(socket, :current_user, user)}

      _ ->
        {:halt, redirect(socket, to: "/dashboard/login")}
    end
  end
end
