import Config

# Configure your database
config :raxol, Raxol.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "raxol_dev",
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
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "your-secret-key-base",
  watchers: [
    esbuild:
      {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    sass: {DartSass, :install_and_run, [:default, ~w(--watch)]}
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

# Do not include metadata nor timestamps in development logs
# Add metadata_filter to silence the specific NIF warning
config :logger, :console,
  format: "[$level] $message\n",
  level: :debug,
  metadata_filter: [
    # Keys are metadata keys, values are functions that return true to KEEP the message
    message: fn
      # Keep messages that DO NOT match the specific warning string
      {:safe, message_chars} ->
        message_string = IO.chardata_to_string(message_chars)

        not String.starts_with?(
          message_string,
          "Unexpected return format from :termbox2.tb_peek_event: {-6, 0, 0, 0}"
        )

      # Keep other message formats (e.g., non-safe charlists, binaries)
      _ ->
        true
    end
  ]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

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
