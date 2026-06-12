defmodule ZevalWeb.Plugs.LoggerMetadata do
  @moduledoc """
  Injects structured metadata into Logger for API requests.
  """

  import Plug.Conn, only: [get_resp_header: 2]
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    metadata = [
      request_path: conn.request_path,
      method: conn.method
    ]

    # Correlate with Plug.RequestId's x-request-id so a single request can be
    # traced across log lines.
    metadata =
      case get_resp_header(conn, "x-request-id") do
        [request_id | _] -> Keyword.put(metadata, :request_id, request_id)
        _ -> metadata
      end

    metadata =
      if tenant_id = conn.assigns[:tenant_id] do
        Keyword.put(metadata, :tenant_id, tenant_id)
      else
        metadata
      end

    Logger.metadata(metadata)
    conn
  end
end
