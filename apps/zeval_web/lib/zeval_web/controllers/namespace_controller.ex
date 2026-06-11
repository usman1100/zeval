defmodule ZevalWeb.NamespaceController do
  use ZevalWeb, :controller

  alias ZevalCore.Namespace

  def upsert(conn, params) do
    tenant_id = conn.assigns.tenant_id

    case Namespace.write(tenant_id, params) do
      {:ok, config} ->
        conn
        |> put_status(200)
        |> json(%{namespace: %{name: config.name, version: config.version}})

      {:error, reason} when is_binary(reason) ->
        ZevalWeb.JsonHelpers.bad_request(conn, reason)

      {:error, changeset} ->
        ZevalWeb.JsonHelpers.unprocessable(conn, changeset)
    end
  end

  def index(conn, _params) do
    tenant_id = conn.assigns.tenant_id
    configs = Namespace.list(tenant_id)

    json(conn, %{
      namespaces: Enum.map(configs, fn c ->
        %{name: c.name, version: c.version}
      end)
    })
  end

  def show(conn, %{"name" => name}) do
    tenant_id = conn.assigns.tenant_id

    case Namespace.get(tenant_id, name) do
      {:ok, config} ->
        json(conn, %{namespace: config.config})

      {:error, :not_found} ->
        ZevalWeb.JsonHelpers.not_found(conn, "namespace not found")
    end
  end

  def delete(conn, %{"name" => name}) do
    tenant_id = conn.assigns.tenant_id

    case Namespace.delete(tenant_id, name) do
      :ok -> json(conn, %{deleted: true})
      {:error, :not_found} -> ZevalWeb.JsonHelpers.not_found(conn, "namespace not found")
    end
  end
end