defmodule Raxol.MixProject do
  use Mix.Project

  @version "1.2.1"
  @source_url "https://github.com/Hydepwns/raxol"

  def project do
    [
      app: :raxol,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: Mix.env() != :dev,
        ignore_module_conflict: true,
        compile_order: [:cell, :operations]
      ],
      compilers: Mix.compilers() ++ [:elixir_make],
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
          :race_conditions,
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

  defp core_deps do
    [
      # Connection pooling library (optional)
      {:poolboy, "~> 1.5", optional: true},
      # Tutorial loading frontmatter parser
      {:yaml_elixir, "~> 2.11"},
      # Syntax highlighting core
      {:makeup, "~> 1.2"},
      # Elixir syntax highlighting
      {:makeup_elixir, "~> 0.16"},
      # System clipboard access
      {:clipboard, "~> 0.2.1"},
      # Efficient circular buffer implementation
      {:circular_buffer, "~> 0.4"}
    ]
  end

  defp phoenix_deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_live_view, "~> 1.0.17"},
      {:phoenix_html, "~> 4.0"},
      {:plug_cowboy, "~> 2.7"},
      {:phoenix_live_dashboard, "~> 0.8.7", only: :dev},
      {:phoenix_live_reload, "~> 1.6", only: :dev}
    ]
  end

  defp database_deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.20.0", runtime: false},
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

      # Testing
      {:mox, "~> 1.2", only: :test},
      {:meck, "~> 0.9", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:stream_data, "~> 1.1", only: [:dev, :test]},

      # Benchmarking suite
      {:benchee, "~> 1.3", only: [:dev, :test]},
      {:benchee_html, "~> 1.0", only: [:dev, :test]},
      {:benchee_json, "~> 1.0", only: [:dev, :test]},

      # Development utilities
      {:file_system, "~> 0.2", only: [:dev, :test]}
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
      {:gettext, "~> 0.26"},
      # DNS clustering (removed - unused)
      # {:dns_cluster, "~> 0.1"},

      # Telemetry & monitoring
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_poller, "~> 1.2"}
      # {:telemetry_metrics_prometheus, "~> 1.1"} # Removed - unused
    ]
  end

  defp i18n_deps do
    [
      {:ex_cldr, "~> 2.15"},
      {:ex_cldr_numbers, "~> 2.12"},
      {:ex_cldr_currencies, "~> 2.5"},
      {:ex_cldr_dates_times, "~> 2.14"}
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
      "release.tag": ["run scripts/release.exs --tag"]
    ]
  end

  defp description do
    """
    The Next.js of Terminal UIs - Build blazing-fast, interactive terminal applications with React-style components, 60fps animations, and seamless web continuity. Enterprise-compliant with 3.3μs parsing performance.
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
      logo: "assets/logo.svg",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md",
        "CONTRIBUTING.md"
      ],
      groups_for_extras: [
        "Getting Started": [
          "README.md"
        ],
        "Project Info": [
          "CHANGELOG.md",
          "LICENSE.md"
        ],
        Contributing: ["CONTRIBUTING.md"]
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
