defmodule Raxol.MixProject do
  use Mix.Project

  @version "2.0.1"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol,
      version: @version,
      elixir: "~> 1.17 or ~> 1.18 or ~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: Mix.env() == :prod,
        ignore_module_conflict: true,
        compile_order: [:cell, :operations]
      ],
      compilers: compilers(),
      consolidate_protocols: Mix.env() != :test,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Raxol",
      source_url: @source_url,
      test_coverage: [
        tool: ExCoveralls,
        ignore_modules: [
          :termbox2_nif,
          Termbox2Nif
        ]
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      make_cwd: "lib/termbox2_nif/c_src",
      make_targets: ["all"],
      make_clean: ["clean"],
      make_env: %{
        "MIX_APP_PATH" => "priv"
      },
      dialyzer: [
        # PLT Configuration for caching
        plt_core_path: "priv/plts/core.plt",
        plt_local_path: "priv/plts/local.plt",

        # Add applications to PLT for better analysis
        plt_add_apps: [
          :ex_unit,
          :mix,
          :phoenix,
          :phoenix_live_view,
          :ecto,
          :postgrex,
          :jason,
          :plug
        ],

        # Analysis flags for comprehensive checking
        flags: [
          :error_handling,
          :underspecs,
          :unmatched_returns,
          :unknown
        ],

        # Ignore warnings file
        ignore_warnings: ".dialyzer_ignore.exs",

        # List of paths to include in analysis
        paths: [
          "_build/#{Mix.env()}/lib/raxol/ebin"
        ],

        # Modules to ignore (can be added as needed)
        ignore_modules: [
          # Add modules that consistently produce false positives
        ]
      ]
    ]
  end

  # Platform-specific compilers
  # Only include :elixir_make on Unix (for termbox2 NIF)
  # Windows uses pure Elixir IOTerminal driver
  defp compilers do
    case :os.type() do
      {:unix, _} -> Mix.compilers() ++ [:elixir_make]
      {:win32, _} -> Mix.compilers()
    end
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
          # NIF integration now working with elixir_make
          # :termbox2_nif,
          :toml,
          :jason,
          :telemetry,
          :file_system,
          :mnesia,
          :os_mon
        ] ++ test_applications()
    ]
  end

  defp elixirc_paths(:test),
    do: [
      "lib",
      "test/support",
      "examples/demos",
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
      # Modular Raxol Packages (path deps for development, version deps for publishing)
      modular_packages(),

      # Core Terminal Dependencies
      core_deps(),

      # Phoenix Web Framework
      phoenix_deps(),

      # Database Dependencies
      database_deps(),

      # Visualization & UI
      visualization_deps(),

      # Development & Testing
      development_deps(),

      # Utilities & System
      utility_deps(),

      # Internationalization
      i18n_deps()
    ]
    |> List.flatten()
  end

  defp modular_packages do
    if Mix.env() == :prod or System.get_env("HEX_BUILD") do
      # Use hex versions for publishing
      [
        {:raxol_core, "~> 2.0"},
        {:raxol_plugin, "~> 2.0"},
        {:raxol_liveview, "~> 2.0"}
      ]
    else
      # Use path dependencies for local development
      [
        {:raxol_core, path: "apps/raxol_core", override: true},
        {:raxol_plugin, path: "apps/raxol_plugin", override: true},
        {:raxol_liveview, path: "apps/raxol_liveview", override: true}
      ]
    end
  end

  defp core_deps do
    [
      # Connection pooling library (optional)
      {:poolboy, "~> 1.5", optional: true},
      # Tutorial loading frontmatter parser
      {:yaml_elixir, "~> 2.12"},
      # Syntax highlighting core
      {:makeup, "~> 1.2"},
      # Elixir syntax highlighting
      {:makeup_elixir, "~> 1.0.1"},
      # System clipboard access
      {:clipboard, "~> 0.2.1"},
      # Efficient circular buffer implementation
      {:circular_buffer, "~> 1.0"},
      # Plugin dependencies (optional - only needed for specific plugins)
      {:req, "~> 0.5", optional: true},
      {:oauth2, "~> 2.1", optional: true}
    ]
  end

  defp phoenix_deps do
    [
      {:phoenix, "~> 1.8.1"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_live_view, "~> 1.1.13"},
      {:phoenix_html, "~> 4.3"},
      {:plug_cowboy, "~> 2.7"},
      {:phoenix_live_dashboard, "~> 0.8.7", only: :dev},
      {:phoenix_live_reload, "~> 1.6.1", only: :dev}
    ]
  end

  defp database_deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.21.1", runtime: false},
      # Password hashing
      {:bcrypt_elixir, "~> 3.3"}
    ]
  end

  defp visualization_deps do
    [
      # Image processing
      {:mogrify, "~> 0.9.3"},
      # Charts and plots
      {:contex, "~> 0.5.0"}
    ]
  end

  defp development_deps do
    [
      # Build tools
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:dart_sass, "~> 0.7", runtime: Mix.env() == :dev},
      {:elixir_make, "~> 0.9", runtime: false},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:earmark, "~> 1.4", only: :dev},

      # Security scanning
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},

      # AI development tools
      {:tidewave, "~> 0.5", only: :dev},
      {:usage_rules, "~> 0.1", only: :dev},

      # Testing
      {:mox, "~> 1.2", only: :test},
      {:muzak, "~> 1.1", only: :test, runtime: false},
      {:meck, "~> 1.0", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:stream_data, "~> 1.1", only: [:dev, :test]},

      # Benchmarking suite
      {:benchee, "~> 1.3", only: [:dev, :test]},
      {:benchee_html, "~> 1.0", only: [:dev, :test]},
      {:benchee_json, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp utility_deps do
    [
      # JSON processing
      {:jason, "~> 1.4.4"},
      # UUID generation
      {:uuid, "~> 1.1"},
      # TOML configuration
      {:toml, "~> 0.7"},
      # MIME type detection (removed - unused)
      # {:mimerl, "~> 1.4"},
      # HTTP client
      {:httpoison, "~> 2.2"},
      # Localization
      {:gettext, "~> 1.0"},
      # File system watching
      {:file_system, "~> 1.1"},
      # DNS clustering (removed - unused)
      # {:dns_cluster, "~> 0.1"},

      # Telemetry & monitoring
      {:telemetry, "~> 1.3"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.2"}
      # {:telemetry_metrics_prometheus, "~> 1.1"} # Removed - unused
    ]
  end

  defp i18n_deps do
    [
      {:ex_cldr, "~> 2.44.1"},
      {:ex_cldr_numbers, "~> 2.35.2"},
      {:ex_cldr_currencies, "~> 2.5"},
      {:ex_cldr_dates_times, "~> 2.24.0"}
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
      lint: ["credo"],
      # Dialyzer commands
      "dialyzer.setup": ["dialyzer --plt"],
      "dialyzer.check": ["dialyzer --format dialyxir"],
      "dialyzer.clean": ["cmd rm -rf priv/plts/*.plt"],
      # Unified development commands
      "dev.test": ["cmd scripts/dev.sh test"],
      "dev.test-all": ["cmd scripts/dev.sh test-all"],
      "dev.check": ["cmd scripts/dev.sh check"],
      "dev.setup": ["cmd scripts/dev.sh setup"],
      # Release commands
      "release.dev": ["run scripts/release.exs --env dev"],
      "release.prod": ["run scripts/release.exs --env prod"],
      "release.all": ["run scripts/release.exs --env prod --all"],
      "release.clean": ["run scripts/release.exs --clean"],
      "release.tag": ["run scripts/release.exs --tag"],
      # AI development tools
      "usage_rules.update": [
        "usage_rules.sync CLAUDE.md usage_rules:all phoenix ecto --inline usage_rules:all --link-to-folder deps --remove-missing --yes"
      ]
    ]
  end

  defp description do
    """
    Meta-package for Raxol terminal framework. Includes core buffer primitives, plugin system, and Phoenix LiveView integration. Build fast terminal UIs with React-style components.
    """
  end

  defp package do
    [
      name: "raxol",
      files:
        ~w(lib priv/themes .formatter.exs mix.exs README* LICENSE* CHANGELOG.md docs examples .github/CONTRIBUTING.md),
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
      main: "readme-1",
      logo: "assets/logo.svg",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md",
        ".github/CONTRIBUTING.md",
        "docs/getting-started/PACKAGES.md",
        "docs/getting-started/QUICKSTART.md",
        "docs/getting-started/CORE_CONCEPTS.md",
        "docs/getting-started/MIGRATION_FROM_DIY.md",
        "docs/core/BUFFER_API.md",
        "docs/core/ARCHITECTURE.md",
        "docs/core/GETTING_STARTED.md",
        "docs/cookbook/README.md",
        "docs/cookbook/LIVEVIEW_INTEGRATION.md",
        "docs/cookbook/THEMING.md",
        "docs/cookbook/COMMAND_SYSTEM.md",
        "docs/cookbook/PERFORMANCE_OPTIMIZATION.md",
        "docs/cookbook/VIM_NAVIGATION.md",
        "docs/plugins/PLUGIN_DEVELOPMENT_GUIDE.md",
        "docs/bench/README.md",
        "docs/project/TODO.md",
        "examples/core/README.md",
        "apps/raxol_core/README.md",
        "apps/raxol_liveview/README.md",
        "apps/raxol_plugin/README.md"
      ],
      groups_for_extras: [
        "Getting Started": [
          "README.md",
          "docs/getting-started/PACKAGES.md",
          "docs/getting-started/QUICKSTART.md",
          "docs/getting-started/CORE_CONCEPTS.md",
          "docs/getting-started/MIGRATION_FROM_DIY.md"
        ],
        "Core Concepts": [
          "docs/core/BUFFER_API.md",
          "docs/core/ARCHITECTURE.md",
          "docs/core/GETTING_STARTED.md"
        ],
        Cookbook: [
          "docs/cookbook/README.md",
          "docs/cookbook/LIVEVIEW_INTEGRATION.md",
          "docs/cookbook/THEMING.md",
          "docs/cookbook/COMMAND_SYSTEM.md",
          "docs/cookbook/PERFORMANCE_OPTIMIZATION.md",
          "docs/cookbook/VIM_NAVIGATION.md"
        ],
        Plugins: [
          "docs/plugins/PLUGIN_DEVELOPMENT_GUIDE.md"
        ],
        Packages: [
          "apps/raxol_core/README.md",
          "apps/raxol_liveview/README.md",
          "apps/raxol_plugin/README.md"
        ],
        "Examples & Benchmarks": [
          "examples/core/README.md",
          "docs/bench/README.md"
        ],
        Project: [
          "docs/project/TODO.md"
        ],
        "Project Info": [
          "CHANGELOG.md",
          "LICENSE.md",
          ".github/CONTRIBUTING.md"
        ]
      ],
      groups_for_modules: [
        Core: [
          Raxol,
          Raxol.Application,
          Raxol.Component,
          Raxol.Minimal
        ],
        "Terminal Emulation": [
          ~r/^Raxol\.Terminal\..*/
        ],
        "UI Components": [
          ~r/^Raxol\.UI\..*/
        ],
        "State Management": [
          ~r/^Raxol\.UI\.State\..*/
        ],
        Performance: [
          ~r/^Raxol\.Benchmarks\..*/,
          ~r/^Raxol\.Metrics.*/
        ],
        "Security & Audit": [
          ~r/^Raxol\.Security\..*/,
          ~r/^Raxol\.Audit.*/
        ],
        Plugins: [
          ~r/^Raxol\.Plugin.*/
        ],
        "Events & Architecture": [
          ~r/^Raxol\.Events.*/,
          ~r/^Raxol\.Architecture\..*/
        ],
        "Web & Cloud": [
          ~r/^Raxol\.Web\..*/,
          ~r/^Raxol\.Cloud\..*/,
          ~r/^RaxolWeb\..*/
        ]
      ],
      source_url: "https://github.com/Hydepwns/raxol",
      source_ref: "v#{@version}",
      formatters: ["html"],
      api_reference: true,
      nest_modules_by_prefix: [
        Raxol.Terminal,
        Raxol.UI,
        Raxol.Security,
        Raxol.Audit,
        Raxol.Architecture
      ]
    ]
  end
end
