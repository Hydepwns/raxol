import Config

# Enable web interface in dev
config :raxol, :features, %{
  web_interface: true,
  pubsub: true,
  database: false,
  terminal_driver: true,
  performance_monitoring: true,
  terminal_sync: true,
  rate_limiting: false,
  telemetry: true,
  plugins: false,
  audit: false,
  dev_performance_hints: true
}

# Disable Ecto repos for dev (Raxol uses Phoenix as library, no active Repo)
# This prevents Tidewave from trying to use Ecto tools
config :raxol, ecto_repos: []

# Configure your database (not started in dev)
config :raxol, Raxol.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "raxol_dev",
  template: "template0",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :raxol, RaxolWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [
    ip: {127, 0, 0, 1},
    port: String.to_integer(System.get_env("PORT") || "4000")
  ],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    "DauGZaFAyuvhf8qoZqqMUbcmikP0Mb0KHDpEY2Dbv35J54NA9L/0R9JYG8G+tmRu",
  watchers: [
    esbuild:
      {Esbuild, :install_and_run, [:raxol, ~w(--sourcemap=inline --watch)]}
  ]

# Watch static and templates for browser reloading.
config :raxol, RaxolWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/raxol_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :raxol, dev_routes: true

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Enable LiveView debug features for Tidewave
config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true

# Configure terminal settings for development
config :raxol, :terminal,
  default_width: 80,
  default_height: 24,
  scrollback_lines: 1000,
  enable_ansi: true,
  enable_mouse: true,
  debug_mode: false,
  log_level: :info

# Configure web interface settings for development
config :raxol, :web,
  default_theme: "light",
  enable_websockets: true,
  session_timeout: 3600,
  debug_mode: false,
  enable_hot_reload: true

# AI Service Configuration
config :raxol, :ai_service,
  local_endpoint:
    System.get_env("AI_LOCAL_ENDPOINT", "http://localhost:8080/v1/completions"),
  timeout: String.to_integer(System.get_env("AI_TIMEOUT", "30000"))

# Streaming Data Configuration  
config :raxol, :streaming,
  default_websocket_endpoint:
    System.get_env("WS_ENDPOINT", "ws://localhost:8080"),
  metrics_path: "/metrics",
  data_path: "/data"

# Task timeouts
config :raxol, :timeouts,
  task_yield: String.to_integer(System.get_env("TASK_YIELD_TIMEOUT", "3000")),
  task_yield_long:
    String.to_integer(System.get_env("TASK_YIELD_LONG_TIMEOUT", "30000")),
  circuit_breaker_reset:
    String.to_integer(System.get_env("CIRCUIT_BREAKER_RESET", "30000"))
