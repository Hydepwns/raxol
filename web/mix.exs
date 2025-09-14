defmodule RaxolPlayground.MixProject do
  use Mix.Project

  def project do
    [
      app: :raxol_playground,
      version: "0.1.0",
      elixir: "~> 1.17",
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
      {:raxol, path: "."},
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.5"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev}
    ]
  end
end