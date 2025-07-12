defmodule Raxol.MixProject do
  use Mix.Project

  @version "0.6.0"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol,
      version: @version,
      elixir: "~> 1.17.1",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: false,
        ignore_module_conflict: true,
        compile_order: [:cell, :operations]
      ],
      compilers: Mix.compilers(),
      consolidate_protocols: Mix.env() != :test,
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
          # Suppress persistent spurious warnings
        ]
      ]
    ]
  end

  # Raxol is primarily a library/toolkit; applications using it define their own OTP app.
  def application do
    [
      mod: {Raxol.Application, []},
      extra_applications:
        [
          :kernel,
          :stdlib,
          :phoenix,
          :phoenix_html,
          :phoenix_live_view,
          :phoenix_pubsub,
          # :ecto_sql,  # Removed to prevent auto-starting Repo
          # :postgrex,  # Removed to prevent auto-starting Repo
          :runtime_tools,
          :swoosh,
          # :termbox2_nif,  # Temporarily disabled for testing
          :toml
        ] ++ test_applications()
    ]
  end

  defp elixirc_paths(:test),
    do: [
      "lib",
      "test/support",
      "examples/demos",
      "lib/raxol/test",
      "lib/raxol/terminal/buffer/cell.ex"
    ]

  defp elixirc_paths(_), do: ["lib", "lib/raxol/terminal/buffer/cell.ex"]

  defp test_applications do
    if Mix.env() == :test do
      # Removed :ecto_sql to prevent auto-starting Repo
      [:mox]
    else
      []
    end
  end

  defp deps do
    [
      # Core dependencies
      # Terminal rendering library (we maintain this fork of termbox2_nif at https://github.com/hydepwns/termbox2-nif)
      # {:termbox2_nif, "~> 2.0"},  # Temporarily disabled for testing

      # --- Added for Tutorial Loading ---
      # Markdown parser
      {:cmark, "~> 0.10"},
      # YAML parser for frontmatter
      {:yaml_elixir, "~> 2.11"},
      # ---------------------------------

      # --- Added for Syntax Highlighting ---
      {:makeup, "~> 1.2"},
      {:makeup_elixir, "~> 0.16"},
      # -----------------------------------

      # Image processing
      {:mogrify, "~> 0.9.3"},
      {:phoenix, "~> 1.7.21"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_live_view, "~> 1.0.17"},
      # {:surface, "~> 0.12.1"},
      # {:sourceror, "~> 1.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      {:jason, "~> 1.4.4"},

      # Database and persistence
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.20.0", runtime: false},
      # For password hashing
      {:bcrypt_elixir, "~> 3.3"},

      # Visualization
      # For charts and plots
      {:contex, "~> 0.5.0"},

      # Email
      {:swoosh, "~> 1.19"},

      # Web interface
      {:plug_cowboy, "~> 2.7"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_html_helpers, "~> 1.0"},

      # Core Plugins Dependencies
      # System clipboard access
      {:clipboard, "~> 0.2.1"},
      {:circular_buffer, "~> 0.4"},

      # Optional Plugin Reloading
      {:file_system, "~> 0.2", only: [:dev, :test]},

      # Development tools
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:dart_sass, "~> 0.7", runtime: Mix.env() == :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Testing
      {:mox, "~> 1.2", only: :test},
      {:meck, "~> 0.9", only: :test},
      {:elixir_make, "~> 0.9", runtime: false},
      {:floki, "~> 0.37", only: :test},
      {:briefly, "~> 0.5", only: :test},

      # Utilities
      {:uuid, "~> 1.1"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.2"},
      {:telemetry_metrics_prometheus, "~> 1.1"},
      {:gettext, "~> 0.26"},
      {:dns_cluster, "~> 0.1"},
      {:bandit, "~> 1.7"},
      {:excoveralls, "~> 0.18", only: :test},
      {:hackney, "~> 1.24"},
      {:httpoison, "~> 2.2"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:toml, "~> 0.7"},
      {:mimerl, "~> 1.4"},
      # Use our local version of json parser
      # {:json, path: "lib/json"},

      # CLDR for internationalization
      {:ex_cldr, "~> 2.15"},
      {:ex_cldr_numbers, "~> 2.12"},
      {:ex_cldr_currencies, "~> 2.5"},
      {:ex_cldr_dates_times, "~> 2.14"},
      {:earmark, "~> 1.4", only: :dev}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: [
        # "ecto.create -r Raxol.Repo --quiet",  # Removed to prevent Ecto.Repo requirement
        # "ecto.migrate -r Raxol.Repo",  # Removed to prevent Ecto.Repo requirement
        "test"
      ],
      "assets.setup": [
        "esbuild.install --if-missing",
        "sass.install --if-missing"
      ],
      "assets.deploy": ["sass.deploy", "tailwind.deploy"],
      "assets.build": [
        "sass default",
        "tailwind default"
      ],
      "explain.credo": ["run scripts/explain_credo_warning.exs"],
      lint: ["credo"]
    ]
  end

  defp description do
    """
    Modern Elixir toolkit for building advanced terminal user interfaces (TUIs) with components, theming, event handling, accessibility, and high performance."
    """
  end

  defp package do
    [
      name: "raxol",
      files:
        ~w(lib priv/themes .formatter.exs mix.exs README* LICENSE* CHANGELOG.md docs examples),
      maintainers: ["DROO AMOR"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Hydepwns/raxol",
        "Documentation" => "https://hexdocs.pm/raxol",
        "Changelog" =>
          "https://github.com/Hydepwns/raxol/blob/master/CHANGELOG.md"
      },
      description: description(),
      source_url: @source_url,
      homepage_url: "https://github.com/Hydepwns/raxol"
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/CONFIGURATION.md",
        "examples/guides/01_getting_started/quick_start.md",
        "examples/guides/02_core_concepts/terminal_emulator.md",
        "examples/snippets/README.md",
        "extensions/vscode/README.md",
        "examples/guides/03_components_and_layout/components/README.md"
      ],
      source_url: "https://github.com/Hydepwns/raxol",
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
