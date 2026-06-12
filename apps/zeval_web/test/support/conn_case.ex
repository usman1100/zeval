defmodule ZevalWeb.ConnCase do
  @moduledoc """
  Test case for tests that need a connection and/or the endpoint.

  Sets up the Ecto SQL sandbox (against ZevalCore.Repo), a base `conn`, and
  helpers for logging a dashboard user into the session.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint ZevalWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import ZevalWeb.ConnCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(ZevalCore.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Builds a conn with the given dashboard user logged into the session."
  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
    |> Plug.Conn.put_session(:current_user_email, user.email)
    |> Plug.Conn.put_session(:current_user_name, user.name)
  end
end
