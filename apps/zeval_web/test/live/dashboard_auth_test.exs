defmodule ZevalWeb.DashboardAuthTest do
  use ZevalWeb.ConnCase

  alias ZevalCore.{DashboardUsers, Tenants, Memberships}

  defp user(suffix) do
    {:ok, u} =
      DashboardUsers.create(%{
        name: "U#{suffix}",
        email: "u#{suffix}-#{System.unique_integer([:positive])}@example.com",
        password: "correct horse battery"
      })

    u
  end

  describe "unauthenticated access" do
    test "GET /dashboard redirects to login", %{conn: conn} do
      conn = get(conn, "/dashboard")
      assert redirected_to(conn) == "/dashboard/login"
    end

    test "GET / redirects to dashboard", %{conn: conn} do
      conn = get(conn, "/")
      assert redirected_to(conn) =~ "/dashboard"
    end
  end

  describe "tenant isolation" do
    test "a user only sees their own tenants", %{conn: conn} do
      owner = user("owner")
      other = user("other")

      {:ok, mine} =
        Tenants.create_for_user(owner.id, "mine-#{System.unique_integer([:positive])}")

      {:ok, theirs} =
        Tenants.create_for_user(other.id, "theirs-#{System.unique_integer([:positive])}")

      {:ok, _view, html} = conn |> log_in_user(owner) |> live("/dashboard/tenants")

      assert html =~ mine.name
      refute html =~ theirs.name
    end

    test "cannot open another tenant's detail page by URL", %{conn: conn} do
      owner = user("owner")
      other = user("other")

      {:ok, theirs} =
        Tenants.create_for_user(other.id, "theirs-#{System.unique_integer([:positive])}")

      assert {:error, {:redirect, %{to: "/dashboard/tenants"}}} =
               conn |> log_in_user(owner) |> live("/dashboard/tenants/#{theirs.id}")
    end

    test "a member can open the tenant detail page", %{conn: conn} do
      owner = user("owner")

      {:ok, mine} =
        Tenants.create_for_user(owner.id, "mine-#{System.unique_integer([:positive])}")

      assert Memberships.member?(owner.id, mine.id)
      {:ok, _view, html} = conn |> log_in_user(owner) |> live("/dashboard/tenants/#{mine.id}")
      assert html =~ mine.name
    end
  end
end
