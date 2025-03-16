defmodule Raxol.MixProject do
  use Mix.Project

  @version "0.0.1"
  @source_url "https://github.com/hydepwns/raxol"

  def project do
    [
      app: :raxol,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Raxol",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Raxol.Application, []}
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:ex_termbox, "~> 1.0"}, # Terminal rendering library
      
      # Optional dependencies for specific features
      {:jason, "~> 1.2", optional: true}, # JSON parsing for data visualization
      
      # Development dependencies
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Raxol - A comprehensive terminal UI framework for Elixir.
    """
  end

  defp package do
    [
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
