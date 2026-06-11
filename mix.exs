defmodule ZevalEngine.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      elixir: "~> 1.19",
      deps: deps(),
      releases: [
        zeval_engine: [
          include_executables_for: [:unix],
          applications: [
            zeval_core: :permanent,
            zeval_web: :permanent
          ]
        ]
      ]
    ]
  end

  # Dependencies shared across all child apps in the umbrella.
  defp deps do
    [
      # Phoenix and web layer
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.5"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},

      # Database
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.18"},

      # Observability
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_metrics_prometheus, "~> 1.1"},
      {:telemetry_poller, "~> 1.0"},

      # Rate limiting
      {:hammer, "~> 7.0"},

      # Test-only
      {:stream_data, "~> 1.1", only: :test},
      {:ex_machina, "~> 2.8", only: :test}
    ]
  end
end
