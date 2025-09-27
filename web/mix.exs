defmodule RaxolPlayground.MixProject do
  use Mix.Project

  def project do
    [
      app: :raxol_playground,
      version: "0.1.0",
      elixir: "~> 1.16 or ~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {RaxolPlayground.Application, []}
    ]
  end

  defp deps do
    [
      {:raxol, path: ".."},
      {:phoenix, "~> 1.8.1"},
      {:phoenix_live_view, "~> 1.1.12"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.6.1", only: :dev},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4.4"},
      {:plug_cowboy, "~> 2.7"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:heroicons, "~> 0.5"},
      {:gettext, "~> 1.0"}
    ]
  end
end