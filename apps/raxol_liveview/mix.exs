defmodule Raxol.LiveView.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol_liveview,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.16 or ~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Raxol LiveView",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Core dependency
      {:raxol_core, "~> 2.0"},

      # Phoenix LiveView
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.0"},

      # Dev dependencies
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Phoenix LiveView integration for Raxol terminal buffers.

    Real-time terminal UIs in the browser with WebSocket updates.
    """
  end

  defp package do
    [
      name: "raxol_liveview",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/raxol_liveview"
      },
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end
end
