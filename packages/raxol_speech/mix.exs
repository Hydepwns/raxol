defmodule RaxolSpeech.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/raxol/raxol"

  def project do
    [
      app: :raxol_speech,
      version: @version,
      elixir: "~> 1.17 or ~> 1.18 or ~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "RaxolSpeech",
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
      # Core dependency (Events, Accessibility, Behaviours)
      raxol_dep(:raxol_core, "~> 2.4", "../raxol_core"),

      # Speech recognition (optional -- STT works without these)
      {:bumblebee, "~> 0.6", optional: true},
      {:nx, "~> 0.9", optional: true},
      {:exla, "~> 0.9", optional: true},

      # JSON processing
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
    Speech surface for Raxol. TTS reads accessibility announcements aloud,
    STT captures voice input via Bumblebee/Whisper and injects as events.
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
