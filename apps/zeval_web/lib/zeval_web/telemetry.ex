defmodule ZevalWeb.Telemetry do
  @moduledoc """
  Configures Prometheus metrics exporters and telemetry handlers.

  Supported metric types: counter, distribution, last_value, sum.
  Summary is not supported by telemetry_metrics_prometheus_core.
  """

  import Telemetry.Metrics

  def metrics do
    [
      # VM metrics (last_value = gauge)
      last_value("vm.memory.total", unit: {:byte, :kilobyte}),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),

      # Ecto query timing (distribution = histogram)
      distribution("zeval.repo.query.total_time",
        unit: {:native, :microsecond},
        tags: [:source],
        tag_values: &metric_source/1,
        reporter_options: [
          buckets: [100, 500, 1000, 5000, 10_000, 50_000, 100_000]
        ]
      ),

      # Check engine metrics
      counter("zeval.check.count", tags: [:allowed],
        description: "Total authorization checks"
      ),
      distribution("zeval.check.duration",
        unit: {:native, :microsecond},
        tags: [],
        reporter_options: [
          buckets: [100, 500, 1000, 5000, 10_000, 50_000]
        ]
      ),
      last_value("zeval.check.depth", tags: []),

      # Tuple store metrics
      counter("zeval.tuples.written.count", tags: [],
        description: "Total tuples written"
      ),
      counter("zeval.tuples.deleted.count", tags: [],
        description: "Total tuples soft-deleted"
      ),

      # Endpoint request count
      counter("phoenix.endpoint.request_count", tags: [:request_path],
        description: "Total HTTP requests by path"
      )
    ]
  end

  defp metric_source(%{source: source}), do: source
  defp metric_source(_), do: :unknown
end