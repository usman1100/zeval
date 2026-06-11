defmodule ZevalWeb.Plugs.RateLimit do
  @moduledoc """
  Rate limiting plug using Hammer with ETS backend.

  Limits are per service account (keyed by account ID). Different
  endpoints have different limits:

    - `/check` — 1000 requests per minute
    - `/tuples` write/delete — 500 requests per minute
    - Everything else — 200 requests per minute
  """

  import Plug.Conn
  require Logger

  def init(opts) do
    %{
      max_requests: Keyword.get(opts, :max_requests, 200),
      window_ms: Keyword.get(opts, :window_ms, 60_000),
      bucket_name: Keyword.get(opts, :bucket_name, "general")
    }
  end

  def call(conn, %{max_requests: max, window_ms: window, bucket_name: bucket} = _opts) do
    account_id =
      case conn.assigns[:service_account] do
        %{id: id} -> id
        _ -> "anonymous"
      end

    case ZevalWeb.RateLimiter.hit("#{bucket}:#{account_id}", window, max) do
      {:allow, _count} ->
        conn

      {:deny, _count} ->
        retry_after = div(window, 1000)

        conn
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> put_resp_content_type("application/json")
        |> send_resp(
          429,
          Jason.encode!(%{
            error: "rate limit exceeded",
            code: "rate_limited",
            retry_after_seconds: retry_after,
            max_requests_per_window: max,
            window_seconds: div(window, 1000)
          })
        )
        |> halt()
    end
  end
end