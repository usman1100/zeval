defmodule ZevalWeb.Plugs.ServiceAuth do
  @moduledoc """
  Validates the incoming API key from the `Authorization` header.

  Expects `Authorization: Bearer perm_live_abc123...`. Hashes the key
  with SHA-256, looks it up in the service_accounts table, and assigns
  `conn.assigns.tenant_id` and `conn.assigns.service_account` on success.

  Returns 401 `{"error": "unauthorized"}` on failure.
  """

  import Plug.Conn
  alias ZevalCore.ServiceAccounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> raw_key] <- get_req_header(conn, "authorization"),
         hash = ServiceAccounts.hash_key(raw_key),
         {:ok, account} <- ServiceAccounts.get_by_hash(hash) do
      ServiceAccounts.touch_last_used(account.id)

      conn
      |> assign(:tenant_id, account.tenant_id)
      |> assign(:service_account, account)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "unauthorized", code: "unauthorized"}))
        |> halt()
    end
  end
end
