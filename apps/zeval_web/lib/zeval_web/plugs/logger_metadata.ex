defmodule ZevalWeb.Plugs.LoggerMetadata do
  @moduledoc """
  Injects structured metadata into Logger for API requests.
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    metadata = %{
      request_path: conn.request_path,
      method: conn.method
    }

    metadata =
      if tenant_id = conn.assigns[:tenant_id] do
        Map.put(metadata, :tenant_id, tenant_id)
      else
        metadata
      end

    Logger.metadata(metadata)
    conn
  end
end