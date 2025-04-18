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
      ],
      dialyzer: [
        # Add core Elixir apps needed for tests
        plt_add_apps: [:ex_unit],
        # Optional: Path to ignore file
        ignore_warnings: "dialyzer.ignore-warnings",
        # Common flags
        flags: [
          :unmatched_returns,
          :error_handling,
          :underspecs
          # Add other flags as needed, e.g., :missing_return for stricter checks
        ],
        # You can skip checks for modules by adding them to the `ignore_modules` list below.
        plt_core_path: "priv/plts",
        # plt_add_apps: [:mix], # Specify apps to add to PLT list
        # plt_file: {:no_warn, "priv/plts/core"},
        ignore_modules: [
          # Example:
          # Raxol.ExampleModule,
          # Phoenix.HTML.Form, # Ignore specific modules if needed
          # Ignore NIF module wrappers
          Raxol.Runtime.Termbox,
          # Suppress persistent spurious warnings
          Raxol.Terminal.Configuration
        ]
      ]
    ]
  end

  def application do
    [
      mod: {Raxol.Application, []},
      extra_applications: [:logger, :runtime_tools, :ex_termbox]
    ]
  end

  defp elixirc_paths(:test),
    do: ["lib", "test/support", "test/raxol", "test/raxol_web"]

  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependencies
      # Terminal rendering library
      {:ex_termbox, "~> 1.0"},
      {:ratatouille, "~> 0.3"},
      {:phoenix, "~> 1.7.20"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:surface, "~> 0.12"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:jason, "~> 1.4"},

      # Database and persistence
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      # For password hashing
      {:bcrypt_elixir, "~> 3.0"},

      # Visualization
      # For charts and plots
      {:contex, "~> 0.5.0"},

      # Web interface
      {:plug_cowboy, "~> 2.7"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Components & Layout (Using local path for now)
      # {:raxol_view_components, path: "../raxol_view_components"}, # Example if extracted

      # Development tools
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:dart_sass, "~> 0.7", runtime: Mix.env() == :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: [:dev, :test], runtime: false},

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
      test: ["test"],
      "assets.setup": [
        "esbuild.install --if-missing",
        "sass.install --if-missing"
      ],
      "assets.build": ["esbuild raxol", "sass default"],
      "assets.deploy": [
        "esbuild raxol --minify",
        "sass default --no-source-map --style=compressed",
        "phx.digest"
      ],
      "explain.credo": ["run scripts/explain_credo_warning.exs"]
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
        "GitHub" => "https://github.com/Hydepwns/raxol"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md", "docs/development.md"],
      source_url: "https://github.com/Hydepwns/raxol",
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
