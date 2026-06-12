defmodule ZevalWeb.Plugs.AdminAuth do
  @moduledoc """
  Guards privileged bootstrap endpoints (e.g. tenant creation) with a
  static admin token.

  The expected token is read from `:zeval_web, :admin_bootstrap_token`
  (set from the `ADMIN_BOOTSTRAP_TOKEN` env var in `runtime.exs`). When no
  token is configured the route is disabled entirely (503) rather than left
  open — fail closed, never open.

  Expects `Authorization: Bearer <token>`. Comparison is constant-time.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case Application.get_env(:zeval_web, :admin_bootstrap_token) do
      token when is_binary(token) and byte_size(token) > 0 ->
        verify(conn, token)

      _ ->
        deny(conn, 503, "admin bootstrap is not configured", "bootstrap_disabled")
    end
  end

  defp verify(conn, expected) do
    with ["Bearer " <> presented] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(presented, expected) do
      conn
    else
      _ -> deny(conn, 401, "unauthorized", "unauthorized")
    end
  end

  defp deny(conn, status, message, code) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: message, code: code}))
    |> halt()
  end
end
