defmodule ZevalWeb.MetricsController do
  use ZevalWeb, :controller

  def index(conn, _params) do
    metrics = TelemetryMetricsPrometheus.Core.scrape(:prometheus_metrics)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
  end
end
