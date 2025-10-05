defmodule RaxolCore.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol_core,
      version: @version,
      elixir: "~> 1.16 or ~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Raxol Core",
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
      # ZERO runtime dependencies - pure functional buffer operations

      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Lightweight terminal buffer primitives for Elixir. Pure functional operations
    for creating, manipulating, and rendering terminal buffers. Zero dependencies,
    < 100KB compiled. Perfect for CLI tools, terminal UIs, and LiveView integration.
    """
  end

  defp package do
    [
      name: "raxol_core",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/raxol_core",
        "Changelog" => "#{@source_url}/blob/main/packages/raxol_core/CHANGELOG.md"
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
        "../../docs/core/GETTING_STARTED.md",
        "../../docs/core/BUFFER_API.md",
        "../../docs/core/ARCHITECTURE.md"
      ],
      groups_for_extras: [
        "Getting Started": Path.wildcard("../../docs/getting-started/*.md"),
        "Core Documentation": Path.wildcard("../../docs/core/*.md")
      ]
    ]
  end
end
