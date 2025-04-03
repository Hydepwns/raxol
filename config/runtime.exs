import Config

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :raxol, RaxolWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Configure your database
  config :raxol, Raxol.Repo,
    username: System.get_env("DATABASE_USERNAME", "postgres"),
    password: System.get_env("DATABASE_PASSWORD", "postgres"),
    hostname: System.get_env("DATABASE_HOSTNAME", "localhost"),
    database: System.get_env("DATABASE_NAME", "raxol_prod"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: true

  # Configure your mailer
  config :raxol, Raxol.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("SMTP_RELAY"),
    username: System.get_env("SMTP_USERNAME"),
    password: System.get_env("SMTP_PASSWORD"),
    tls: :always,
    auth: :always,
    port: 587

  # Configure terminal settings from environment
  config :raxol, :terminal,
    default_width: String.to_integer(System.get_env("TERMINAL_WIDTH") || "80"),
    default_height: String.to_integer(System.get_env("TERMINAL_HEIGHT") || "24"),
    scrollback_lines: String.to_integer(System.get_env("TERMINAL_SCROLLBACK") || "1000"),
    enable_ansi: System.get_env("TERMINAL_ANSI", "true") == "true",
    enable_mouse: System.get_env("TERMINAL_MOUSE", "true") == "true",
    debug_mode: System.get_env("TERMINAL_DEBUG", "false") == "true",
    log_level: String.to_atom(System.get_env("TERMINAL_LOG_LEVEL") || "info")

  # Configure web interface settings from environment
  config :raxol, :web,
    default_theme: System.get_env("WEB_THEME", "light"),
    enable_websockets: System.get_env("WEB_WEBSOCKETS", "true") == "true",
    session_timeout: String.to_integer(System.get_env("WEB_SESSION_TIMEOUT") || "3600"),
    debug_mode: System.get_env("WEB_DEBUG", "false") == "true",
    enable_hot_reload: System.get_env("WEB_HOT_RELOAD", "false") == "true"

  # Configure production-specific settings from environment
  config :raxol, :production,
    enable_metrics: System.get_env("ENABLE_METRICS", "true") == "true",
    enable_logging: System.get_env("ENABLE_LOGGING", "true") == "true",
    enable_error_reporting: System.get_env("ENABLE_ERROR_REPORTING", "true") == "true",
    enable_performance_monitoring: System.get_env("ENABLE_PERFORMANCE_MONITORING", "true") == "true"
end 