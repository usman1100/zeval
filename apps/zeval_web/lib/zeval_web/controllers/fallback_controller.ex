defmodule ZevalWeb.FallbackController do
  @moduledoc """
  Catch-all for unmatched `/api/*` routes — returns a consistent JSON 404
  instead of Phoenix's default HTML/error rendering.
  """
  use ZevalWeb, :controller

  def not_found(conn, _params) do
    ZevalWeb.JsonHelpers.not_found(conn, "no such endpoint")
  end
end
