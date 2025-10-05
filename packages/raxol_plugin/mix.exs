defmodule RaxolPlugin.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol_plugin,
      version: @version,
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
      # Core dependency - terminal buffer primitives
      {:raxol_core, "~> 2.0", path: "../raxol_core"},

      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Plugin system for Raxol terminal applications. Build extensible terminal
    UIs with a simple plugin behavior defining init, handle_input, render, and
    cleanup callbacks. Includes testing utilities and documentation generators.
    """
  end

  defp package do
    [
      name: "raxol_plugin",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/raxol_plugin",
        "Changelog" => "#{@source_url}/blob/main/packages/raxol_plugin/CHANGELOG.md"
      },
      maintainers: ["Raxol Team"]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "../../docs/plugins/BUILDING_PLUGINS.md",
        "../../docs/plugins/SPOTIFY.md"
      ],
      groups_for_extras: [
        "Plugin Development": Path.wildcard("../../docs/plugins/*.md")
      ]
    ]
  end
end
