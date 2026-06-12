defmodule ZevalWeb.Plugs.MetricsAuth do
  @moduledoc """
  Guards the Prometheus `/metrics` endpoint with a static bearer token read
  from `:zeval_web, :metrics_token` (METRICS_TOKEN env). When unset the
  endpoint is disabled (404) — operational metrics are never exposed
  unauthenticated. Comparison is constant-time.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case Application.get_env(:zeval_web, :metrics_token) do
      token when is_binary(token) and byte_size(token) > 0 ->
        verify(conn, token)

      _ ->
        # Disabled: respond as if the route doesn't exist.
        conn |> send_resp(404, "not found") |> halt()
    end
  end

  defp verify(conn, expected) do
    with ["Bearer " <> presented] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(presented, expected) do
      conn
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "unauthorized", code: "unauthorized"}))
        |> halt()
    end
  end
end
