defmodule ZevalWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :zeval_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger],
      mod: {ZevalWeb.Application, []}
    ]
  end

  defp deps do
    [
      # Sibling apps
      {:zeval_core, in_umbrella: true},

      # Phoenix and web layer
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},

      # Observability
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_metrics_prometheus, "~> 1.1"},
      {:telemetry_poller, "~> 1.0"},

      # Rate limiting
      {:hammer, "~> 7.0"},

      # Test-only
      {:stream_data, "~> 1.1", only: :test},
      {:ex_machina, "~> 2.8", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end
end
