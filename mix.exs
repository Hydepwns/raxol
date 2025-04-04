defmodule Raxol.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/hydepwns/raxol"

  def project do
    [
      app: :raxol,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Raxol",
      source_url: @source_url,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      mod: {Raxol.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependencies
      {:ex_termbox, "~> 1.0"}, # Terminal rendering library
      {:phoenix, "~> 1.7.20"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:jason, "~> 1.4"},
      
      # Database and persistence
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      
      # Web interface
      {:phoenix_html, "~> 4.1"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      
      # Development tools
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:dart_sass, "~> 0.7", runtime: Mix.env() == :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      
      # Testing
      {:mox, "~> 1.0", only: :test},
      {:meck, "~> 0.9.2", only: :test},
      {:wallaby, "~> 0.30.0", only: :test, runtime: false},
      {:floki, ">= 0.30.0", only: :test},
      
      # Utilities
      {:uuid, "~> 1.1"},
      {:inflex, "~> 2.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["esbuild.install --if-missing", "sass.install --if-missing"],
      "assets.build": ["esbuild raxol", "sass default"],
      "assets.deploy": [
        "esbuild raxol --minify",
        "sass default --no-source-map --style=compressed",
        "phx.digest"
      ]
    ]
  end

  defp description do
    """
    Raxol - A comprehensive terminal UI framework for Elixir with web interface capabilities.
    """
  end

  defp package do
    [
      maintainers: ["Your Name"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/yourusername/raxol"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "docs/development.md"],
      source_url: "https://github.com/yourusername/raxol",
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
