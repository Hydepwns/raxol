# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

import Config

# General application configuration
# config :raxol,
#   ecto_repos: [Raxol.Repo],
config :raxol,
  generators: [binary_id: true]

# Configures the endpoint
config :raxol, RaxolWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: RaxolWeb.ErrorHTML, json: RaxolWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Raxol.PubSub,
  live_view: [signing_salt: "your-signing-salt"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
import_config "cldr.exs"

# Configure the database
config :raxol, Raxol.Repo,
  database: "raxol_dev",
  hostname: "localhost",
  enabled: true

# Configure the application
config :raxol,
  database_enabled: true

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{config_env()}.exs"

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
  adapter: Bandit.HTTP,
  watchers: [
    # Configure esbuild version
    esbuild: {
      Esbuild,
      :install_and_run,
      [:default, ~w(--sourcemap=inline --watch), version: "0.25.0"]
    },
    # Configure dart_sass version
    sass: {
      DartSass,
      :install_and_run,
      [:default, ~w(--watch), version: "1.61.0"]
    }
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

# Configure terminal settings
config :raxol, :terminal,
  default_width: 80,
  default_height: 24,
  scrollback_lines: 1000,
  enable_ansi: true,
  enable_mouse: true

# Configure buffer system
# Set to :new to use the refactored modular BufferServerRefactored
# Set to :old to use the original monolithic BufferServer
config :raxol, :buffer_system, :new

# Configure web interface settings
config :raxol, :web,
  default_theme: "dark",
  enable_websockets: true,
  session_timeout: 3600
