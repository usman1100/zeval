defmodule ZevalWeb.TupleLiveTest do
  use ZevalWeb.ConnCase

  import Phoenix.LiveViewTest

  alias ZevalCore.{DashboardUsers, Tenants}

  defp user(suffix) do
    {:ok, u} =
      DashboardUsers.create(%{
        name: "U#{suffix}",
        email: "u#{suffix}-#{System.unique_integer([:positive])}@example.com",
        password: "correct horse battery"
      })

    u
  end

  test "selected tenant survives typing in a row", %{conn: conn} do
    owner = user("owner")
    {:ok, tenant} = Tenants.create_for_user(owner.id, "t-#{System.unique_integer([:positive])}")

    {:ok, view, _html} = conn |> log_in_user(owner) |> live("/dashboard/tuples")

    # Select the tenant (phx-change lives on the wrapping form)
    html = view |> element("#tenant-form") |> render_change(%{"tenant_id" => tenant.id})
    assert html =~ ~s(value="#{tenant.id}" selected)

    # Type into a row's namespace field
    html =
      view
      |> element("input[name=namespace]")
      |> render_keyup(%{"idx" => "0", "field" => "namespace", "value" => "doc"})

    # The tenant should still be selected after typing
    assert html =~ ~s(value="#{tenant.id}" selected),
           "tenant selection was lost after typing"
  end
end
