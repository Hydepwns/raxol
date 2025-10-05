defmodule Raxol.Plugin.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol_plugin,
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
      name: "Raxol Plugin",
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
      {:raxol_core, "~> 2.0", path: "../raxol_core"},

      # Dev dependencies
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Plugin framework for Raxol terminal applications.

    Build and distribute Raxol plugins with a consistent behavior interface.
    """
  end

  defp package do
    [
      name: "raxol_plugin",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/raxol_plugin"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
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
