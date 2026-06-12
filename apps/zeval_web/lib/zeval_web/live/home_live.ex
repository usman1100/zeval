defmodule ZevalWeb.DashboardLive.HomeLive do
  use ZevalWeb, :live_view

  alias ZevalCore.{Tenants, Namespace, Tuples}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    stats = compute_stats(user_id)

    {:ok,
     assign(socket,
       active: "home",
       page_title: "Zeval Engine — Dashboard",
       stats: stats
     )}
  end

  defp compute_stats(user_id) do
    tenants = Tenants.list_for_user(user_id)

    namespace_count =
      tenants
      |> Enum.map(fn t -> Namespace.list(t.id) |> length() end)
      |> Enum.sum()

    tuple_count =
      tenants
      |> Enum.map(fn t -> Tuples.read(t.id) |> length() end)
      |> Enum.sum()

    %{tenants: length(tenants), namespaces: namespace_count, tuples: tuple_count}
  end
end
