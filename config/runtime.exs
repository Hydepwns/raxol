import Config

if config_env() == :prod do
  # Configure your database
  config :raxol, Raxol.Repo,
    username: System.get_env("DATABASE_USERNAME", "postgres"),
    password: System.get_env("DATABASE_PASSWORD", "postgres"),
    hostname: System.get_env("DATABASE_HOSTNAME", "localhost"),
    database: System.get_env("DATABASE_NAME", "raxol_prod"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: true

  # Configure terminal settings from environment
  config :raxol, :terminal,
    default_width: String.to_integer(System.get_env("TERMINAL_WIDTH") || "80"),
    default_height:
      String.to_integer(System.get_env("TERMINAL_HEIGHT") || "24"),
    scrollback_lines:
      String.to_integer(System.get_env("TERMINAL_SCROLLBACK") || "1000"),
    enable_ansi: System.get_env("TERMINAL_ANSI", "true") == "true",
    enable_mouse: System.get_env("TERMINAL_MOUSE", "true") == "true",
    debug_mode: System.get_env("TERMINAL_DEBUG", "false") == "true",
    log_level: String.to_atom(System.get_env("TERMINAL_LOG_LEVEL") || "info"),
    virtual_scroll_size:
      String.to_integer(
        System.get_env("TERMINAL_VIRTUAL_SCROLL_SIZE") || "1000"
      ),
    memory_limit:
      String.to_integer(System.get_env("TERMINAL_MEMORY_LIMIT") || "52428800"),
    cleanup_interval:
      String.to_integer(System.get_env("TERMINAL_CLEANUP_INTERVAL") || "60000")

  # Configure web interface settings from environment
  config :raxol, :web,
    default_theme: System.get_env("WEB_THEME", "light"),
    enable_websockets: System.get_env("WEB_WEBSOCKETS", "true") == "true",
    session_timeout:
      String.to_integer(System.get_env("WEB_SESSION_TIMEOUT") || "3600"),
    debug_mode: System.get_env("WEB_DEBUG", "false") == "true",
    enable_hot_reload: System.get_env("WEB_HOT_RELOAD", "false") == "true",
    reduced_motion: System.get_env("REDUCED_MOTION", "false") == "true",
    high_contrast: System.get_env("HIGH_CONTRAST", "false") == "true",
    font_family:
      System.get_env("WEB_FONT_FAMILY", "JetBrains Mono, SF Mono, monospace"),
    font_size: String.to_integer(System.get_env("WEB_FONT_SIZE") || "14"),
    line_height: String.to_float(System.get_env("WEB_LINE_HEIGHT") || "1.2")

  # Configure production-specific settings from environment
  config :raxol, :production,
    enable_metrics: System.get_env("ENABLE_METRICS", "true") == "true",
    enable_logging: System.get_env("ENABLE_LOGGING", "true") == "true",
    enable_error_reporting:
      System.get_env("ENABLE_ERROR_REPORTING", "true") == "true",
    enable_performance_monitoring:
      System.get_env("ENABLE_PERFORMANCE_MONITORING", "true") == "true",
    memory_warning_threshold:
      String.to_integer(
        System.get_env("MEMORY_WARNING_THRESHOLD") || "41943040"
      ),
    performance_sampling_rate:
      String.to_integer(System.get_env("PERFORMANCE_SAMPLING_RATE") || "1000")
end
