defmodule RaxolLiveView.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol_liveview,
      version: @version,
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
      # Core dependency - terminal buffer primitives
      {:raxol_core, "~> 2.0", path: "../raxol_core"},

      # Phoenix LiveView integration
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},

      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:phoenix, "~> 1.7", only: [:dev, :test]},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp description do
    """
    Phoenix LiveView integration for Raxol terminal buffers. Render terminal
    UIs in web browsers with real-time updates, keyboard/mouse events, and
    themeable CSS. Built on top of raxol_core for lightweight, performant
    terminal rendering.
    """
  end

  defp package do
    [
      name: "raxol_liveview",
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/raxol_liveview",
        "Changelog" => "#{@source_url}/blob/main/packages/raxol_liveview/CHANGELOG.md"
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
        "../../docs/cookbook/LIVEVIEW_INTEGRATION.md",
        "../../docs/cookbook/THEMING.md"
      ],
      groups_for_extras: [
        Cookbooks: Path.wildcard("../../docs/cookbook/*.md")
      ]
    ]
  end
end
