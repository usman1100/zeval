defmodule ZevalWeb.HealthController do
  @moduledoc """
  Liveness and readiness probes.

    * `GET /health` — always 200 if the process is up (liveness).
    * `GET /ready`  — 200 only if the database is reachable (readiness).
  """
  use ZevalWeb, :controller

  def health(conn, _params), do: json(conn, %{status: "ok"})

  def ready(conn, _params) do
    case db_ok?() do
      true -> json(conn, %{status: "ready"})
      false -> conn |> put_status(503) |> json(%{status: "not_ready"})
    end
  end

  defp db_ok? do
    case Ecto.Adapters.SQL.query(ZevalCore.Repo, "SELECT 1", []) do
      {:ok, _} -> true
      _ -> false
    end
  rescue
    _ -> false
  end
end
