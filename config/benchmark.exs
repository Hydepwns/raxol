import Config

# Benchmark Configuration for Raxol
# This file contains all configuration for the world-class benchmarking system

config :raxol, :benchmark,
  # General benchmark settings
  defaults: %{
    # seconds to run each benchmark
    time: 10,
    # seconds of warmup
    warmup: 2,
    # seconds to measure memory
    memory_time: 2,
    # number of parallel processes
    parallel: 1,
    # auto-determine iterations
    iterations: nil,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.HTML, file: "bench/output/results.html"},
      {Benchee.Formatters.JSON, file: "bench/output/results.json"},
      {Raxol.Benchmark.EnhancedFormatter, file: "bench/output/enhanced.html"}
    ]
  },

  # Performance targets (microseconds)
  targets: %{
    parser: %{
      plain_text: 1.0,
      ansi_basic: 3.0,
      ansi_complex: 5.0,
      cursor_movement: 2.0,
      color_256: 4.0,
      color_rgb: 5.0,
      large_text: 10.0
    },
    terminal: %{
      emulator_creation: 100.0,
      buffer_write_char: 0.5,
      buffer_write_string: 2.0,
      cursor_move: 0.3,
      scroll_operation: 5.0,
      screen_clear: 10.0
    },
    rendering: %{
      small_buffer: 100.0,
      medium_buffer: 500.0,
      large_buffer: 1000.0,
      damage_tracking: 50.0
    },
    memory: %{
      # 2.8MB in KB
      session_kb: 2800,
      buffer_growth_rate: 1.5,
      max_sessions: 1000
    }
  },

  # Regression detection settings
  regression: %{
    # 5% regression threshold
    threshold: 0.05,
    # 95% confidence
    confidence_level: 0.95,
    baseline_dir: "bench/baselines",
    history_limit: 100,
    methods: [:statistical, :threshold],
    # Automatically save baselines
    auto_baseline: true
  },

  # Statistical analysis settings
  statistics: %{
    percentiles: [50, 75, 90, 95, 99, 99.9],
    outlier_methods: [:iqr, :mad],
    outlier_threshold: 3,
    confidence_intervals: true,
    bootstrap_iterations: 1000,
    distribution_analysis: true,
    histogram_bins: 20
  },

  # Competitor comparison settings
  competitors: %{
    enabled: true,
    terminals: [:alacritty, :kitty, :wezterm, :iterm2, :tmux],
    # Simulate competitor performance
    simulation_mode: true,
    comparison_metrics: [:parser, :memory, :startup, :scrolling],
    feature_matrix: true
  },

  # Continuous monitoring settings
  monitoring: %{
    enabled: false,
    # 1 minute
    interval: 60_000,
    # 10% degradation
    alert_threshold: 0.10,
    notifications: %{
      email: false,
      slack: false,
      webhook: nil
    },
    dashboard_port: 4001,
    metrics_retention_days: 30
  },

  # Profiling settings
  profiling: %{
    enabled: false,
    tools: [:fprof, :eprof, :observer],
    flame_graphs: true,
    sampling_rate: 1000,
    output_dir: "bench/profiles"
  },

  # Output and reporting
  output: %{
    dir: "bench/output",
    formats: [:text, :json, :html, :markdown],
    enhanced_reports: true,
    charts: true,
    comparison_tables: true,
    timestamp_format: :iso8601,
    verbose: false
  },

  # Test data generation
  scenarios: %{
    use_property_based: true,
    # Random seed for reproducibility
    seed: nil,
    sizes: %{
      small: 100,
      medium: 1_000,
      large: 10_000,
      stress: 100_000
    },
    real_world_scenarios: [
      :vim_session,
      :git_diff,
      :htop_output,
      :npm_install,
      :docker_build,
      :log_viewer,
      :repl_session
    ]
  },

  # Suite registry settings
  registry: %{
    auto_discover: true,
    scan_paths: ["lib/**/*.ex", "test/**/*_bench.exs"],
    cache_discovery: true,
    parallel_execution: false
  },

  # Storage settings
  storage: %{
    results_dir: "bench/results",
    baselines_dir: "bench/baselines",
    snapshots_dir: "bench/snapshots",
    archive_old_results: true,
    compression: :gzip,
    retention_days: 90
  },

  # CI/CD integration
  ci: %{
    enabled: System.get_env("CI") == "true",
    fail_on_regression: true,
    # Stricter in CI
    regression_threshold: 0.03,
    comment_on_pr: true,
    artifacts_path: "_build/bench",
    baseline_branch: "main"
  },

  # Environment-specific overrides
  env_overrides: %{
    dev: %{
      time: 2,
      warmup: 0.5,
      memory_time: 0.5
    },
    test: %{
      time: 1,
      warmup: 0.1,
      memory_time: 0.1
    },
    prod: %{
      time: 20,
      warmup: 5,
      memory_time: 5
    }
  }

# Load environment-specific config
env = Mix.env()

if env_config = get_in(config, [:raxol, :benchmark, :env_overrides, env]) do
  config :raxol, :benchmark,
    defaults:
      Map.merge(
        get_in(config, [:raxol, :benchmark, :defaults]),
        env_config
      )
end

# CI-specific configuration
if System.get_env("CI") do
  config :raxol, :benchmark,
    output:
      Map.put(
        get_in(config, [:raxol, :benchmark, :output]),
        :dir,
        System.get_env("CI_ARTIFACTS_PATH", "_build/bench")
      )
end
