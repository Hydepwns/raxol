defmodule RaxolLiveView.MixProject do
  use Mix.Project

  @version "2.4.0"
  @source_url "https://github.com/DROOdotFOO/raxol"

  def project do
    [
      app: :raxol_liveview,
      version: @version,
      elixir: "~> 1.16 or ~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependency (Buffer, Events, etc.)
      {:raxol_core, path: "../raxol_core", override: true},

      # PubSub for LiveView <-> Lifecycle communication
      {:phoenix_pubsub, "~> 2.1"},

      # JSON processing
      {:jason, "~> 1.4"},

      # Phoenix LiveView integration (optional -- module guards with Code.ensure_loaded?)
      {:phoenix_live_view, "~> 0.20 or ~> 1.0", optional: true},
      {:phoenix_html, "~> 4.0 or ~> 3.3", optional: true},

      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Phoenix LiveView integration for Raxol terminal buffers. Render terminal
    UIs in web browsers with real-time updates, keyboard/mouse events, and
    themeable CSS.
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
        "README.md"
      ]
    ]
  end
end
