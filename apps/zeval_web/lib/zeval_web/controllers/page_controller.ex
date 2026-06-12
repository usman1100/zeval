defmodule ZevalWeb.PageController do
  use ZevalWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/dashboard/login")
  end
end