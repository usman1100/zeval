defmodule ZevalCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :zeval_core,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls, threshold: 0],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ZevalCore.Application, []}
    ]
  end

  defp deps do
    [
      # Database
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.18"},

      # Password hashing for dashboard users
      {:bcrypt_elixir, "~> 3.2"},
      {:jason, "~> 1.4"},

      # Observability
      {:telemetry_metrics, "~> 1.0"},

      # Test-only
      {:stream_data, "~> 1.1", only: :test},
      {:ex_machina, "~> 2.8", only: :test}
    ]
  end
end
