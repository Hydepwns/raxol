import Config

# Raxol Configuration for Development Environment
# 🤖 Generated from config schema - do not edit directly

config :raxol, :terminal,
  default_width: 80,
  default_height: 24,
  scrollback_lines: 1000,
  enable_ansi: true,
  enable_mouse: true,
  debug_mode: true

config :raxol, :web,
  default_theme: "light",
  enable_websockets: true,
  session_timeout: 3600,
  enable_hot_reload: true,
  debug_mode: true

config :raxol, :core,
  max_concurrent_sessions: 10,
  buffer_size_limit: 1_048_576

# Phoenix Configuration  
config :raxol, RaxolWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    view: RaxolWeb.ErrorView,
    accepts: ~w(html json),
    layout: false
  ],
  pubsub_server: Raxol.PubSub,
  live_view: [signing_salt: "development_salt"],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild:
      {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]

# Database Configuration
config :raxol, Raxol.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "raxol_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Logger Configuration
config :logger, :console, format: "[$level] $message\n"
