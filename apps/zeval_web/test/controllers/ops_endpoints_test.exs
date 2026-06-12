defmodule ZevalWeb.OpsEndpointsTest do
  use ZevalWeb.ConnCase

  describe "health/readiness" do
    test "GET /health is 200", %{conn: conn} do
      assert json_response(get(conn, "/health"), 200)["status"] == "ok"
    end

    test "GET /ready checks the DB", %{conn: conn} do
      assert json_response(get(conn, "/ready"), 200)["status"] == "ready"
    end
  end

  describe "/metrics" do
    test "rejects without the metrics token", %{conn: conn} do
      conn = get(conn, "/metrics")
      assert conn.status in [401, 404]
    end

    test "allows with the configured token", %{conn: conn} do
      Application.put_env(:zeval_web, :metrics_token, "test-metrics")
      on_exit(fn -> Application.delete_env(:zeval_web, :metrics_token) end)

      conn =
        conn
        |> put_req_header("authorization", "Bearer test-metrics")
        |> get("/metrics")

      assert conn.status == 200
    end
  end

  describe "unmatched api routes" do
    test "return a JSON 404", %{conn: conn} do
      conn = get(conn, "/api/v1/does-not-exist")
      assert json_response(conn, 404)["code"] == "not_found"
    end
  end
end
