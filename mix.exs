defmodule Raxol.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
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
          # Suppress persistent spurious warnings
        ]
      ]
    ]
  end

  # Raxol is primarily a library/toolkit; applications using it define their own OTP app.
  def application do
    [
      mod: {Raxol.Application, []},
      extra_applications: [:logger, :runtime_tools, :swoosh]
    ]
  end

  defp elixirc_paths(:test),
    do: ["lib", "test/support", "test/raxol", "test/raxol_web"]

  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependencies
      # Terminal rendering library
      {:rrex_termbox, "~> 2.0.1"},

      # TODO: Review if Phoenix/web dependencies are needed for core library
      # They might be remnants of web UI / VSCode Stdio features.
      {:phoenix, "~> 1.7.20"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:surface, "~> 0.12"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:jason, "~> 1.4"},

      # Database and persistence
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.19.0", runtime: false},
      # For password hashing
      {:bcrypt_elixir, "~> 3.0"},

      # Visualization
      # For charts and plots
      {:contex, "~> 0.5.0"},

      # Email
      {:swoosh, "~> 1.17"},

      # Web interface
      {:plug_cowboy, "~> 2.7"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_html_helpers, "~> 1.0"},

      # Components & Layout (Using local path for now)
      # {:raxol_view_components, path: "../raxol_view_components"}, # Example if extracted

      # Core Plugins Dependencies
      # System clipboard access
      {:clipboard, "~> 0.2.1"},
      {:circular_buffer, "~> 0.2"},
      # {:ex_notify, "~> 0.2"}, # REMOVED - Package does not exist / wrong one chosen

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
      {:elixir_make, "~> 0.6", runtime: false},
      {:floki, ">= 0.30.0", only: :test},

      # Utilities
      {:uuid, "~> 1.1"},
      {:inflex, "~> 2.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:excoveralls, "~> 0.18", only: :test},
      {:hackney, "~> 1.9"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["test"],
      "assets.setup": [
        "esbuild.install --if-missing",
        "sass.install --if-missing"
      ],
      "assets.deploy": ["sass.deploy", "tailwind.deploy"],
      "assets.build": [
        "sass default",
        "tailwind default"
      ],
      "explain.credo": ["run scripts/explain_credo_warning.exs"]
    ]
  end

  defp description do
    """
    Raxol - A toolkit for building interactive terminal UI applications in Elixir.
    """
  end

  defp package do
    [
      files:
        ~w(lib priv/themes .formatter.exs mix.exs README* LICENSE* docs/development/changes/CHANGELOG.md),
      maintainers: ["DROO AMOR"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Hydepwns/raxol"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/guides/quick_start.md",
        "docs/guides/vscode_extension.md"
      ],
      source_url: "https://github.com/Hydepwns/raxol",
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
