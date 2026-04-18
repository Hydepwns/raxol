defmodule RaxolWatch.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/raxol/raxol"

  def project do
    [
      app: :raxol_watch,
      version: @version,
      elixir: "~> 1.17 or ~> 1.18 or ~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "RaxolWatch",
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
      raxol_dep(:raxol_core, "~> 2.4", "../raxol_core"),

      # Push notifications (optional -- only needed with real APNS/FCM)
      {:pigeon, "~> 2.0", optional: true},

      {:jason, "~> 1.4"},

      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp raxol_dep(name, version, path) do
    if System.get_env("HEX_BUILD") || !File.dir?(path) do
      {name, version}
    else
      {name, version, path: path, override: true}
    end
  end

  defp description do
    """
    Watch notification bridge for Raxol. Pushes glanceable summaries and
    accessibility announcements to Apple Watch (APNS) and Wear OS (FCM).
    Tap actions route back as events to the TEA app.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md"]
    ]
  end
end
