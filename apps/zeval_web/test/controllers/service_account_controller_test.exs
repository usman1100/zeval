defmodule ZevalWeb.ServiceAccountControllerTest do
  use ZevalWeb.ConnCase

  alias ZevalCore.{Tenants, ServiceAccounts}

  defp tenant(name),
    do:
      (fn ->
         {:ok, t} = Tenants.create(name)
         t
       end).()

  defp key_for(tenant) do
    {:ok, %{account: account, raw_key: raw}} =
      ServiceAccounts.create(tenant.id, "k-#{System.unique_integer([:positive])}")

    {account, raw}
  end

  describe "POST /api/v1/service-accounts" do
    test "is rejected without authentication", %{conn: conn} do
      conn = post(conn, "/api/v1/service-accounts", %{"name" => "evil"})
      assert json_response(conn, 401)["code"] == "unauthorized"
    end

    test "creates a key for the authenticated tenant only (ignores body tenant_id)", %{conn: conn} do
      tenant_a = tenant("a-#{System.unique_integer([:positive])}")
      tenant_b = tenant("b-#{System.unique_integer([:positive])}")
      {_account, raw} = key_for(tenant_a)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw}")
        |> post("/api/v1/service-accounts", %{"name" => "new", "tenant_id" => tenant_b.id})

      body = json_response(conn, 201)
      created_id = body["service_account"]["id"]

      # The new key must belong to tenant_a (the caller), NOT the body's tenant_b.
      assert ServiceAccounts.get(created_id).tenant_id == tenant_a.id
    end
  end

  describe "DELETE /api/v1/service-accounts/:id" do
    test "is rejected without authentication", %{conn: conn} do
      tenant_a = tenant("a-#{System.unique_integer([:positive])}")
      {account, _raw} = key_for(tenant_a)

      conn = delete(conn, "/api/v1/service-accounts/#{account.id}")
      assert json_response(conn, 401)["code"] == "unauthorized"
      assert is_nil(ServiceAccounts.get(account.id).revoked_at)
    end

    test "cannot revoke another tenant's key", %{conn: conn} do
      tenant_a = tenant("a-#{System.unique_integer([:positive])}")
      tenant_b = tenant("b-#{System.unique_integer([:positive])}")
      {_a_account, a_raw} = key_for(tenant_a)
      {b_account, _b_raw} = key_for(tenant_b)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{a_raw}")
        |> delete("/api/v1/service-accounts/#{b_account.id}")

      assert json_response(conn, 404)
      # tenant_b's key is untouched.
      assert is_nil(ServiceAccounts.get(b_account.id).revoked_at)
    end

    test "revokes own tenant's key", %{conn: conn} do
      tenant_a = tenant("a-#{System.unique_integer([:positive])}")
      {_account, raw} = key_for(tenant_a)
      {victim, _} = key_for(tenant_a)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{raw}")
        |> delete("/api/v1/service-accounts/#{victim.id}")

      assert json_response(conn, 200)["revoked"] == true
      refute is_nil(ServiceAccounts.get(victim.id).revoked_at)
    end
  end

  describe "tenant creation is not exposed over the API" do
    test "POST /api/v1/tenants has no route (dashboard-only creation)", %{conn: conn} do
      # The public tenant-bootstrap endpoint was removed; tenants are created
      # only from the dashboard so they always have an owner.
      conn = post(conn, "/api/v1/tenants", %{"name" => "nope"})
      assert json_response(conn, 404)["code"] == "not_found"
    end
  end
end
