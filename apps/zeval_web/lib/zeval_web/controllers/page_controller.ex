defmodule ZevalWeb.PageController do
  use ZevalWeb, :controller

  def index(conn, _params) do
    if get_session(conn, :current_user_id) do
      redirect(conn, to: "/dashboard")
    else
      conn
      |> put_resp_header("content-type", "text/html; charset=utf-8")
      |> send_resp(200, Phoenix.View.render_to_string(ZevalWeb.PageView, "index.html", %{}))
    end
  end
end
