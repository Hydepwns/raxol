# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

import Config

# General application configuration
config :raxol,
  ecto_repos: [Raxol.Repo],
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
  metadata: [
    :request_id,
    :category,
    :performance_impact,
    :suggestions_count,
    :phase3_context
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Suppress Tesla deprecated builder warning (oauth2 uses it)
config :tesla, :disable_deprecated_builder_warning, true

# Configure esbuild version and profiles
config :esbuild,
  version: "0.25.0",
  raxol: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure dart_sass version
config :dart_sass, :version, "1.61.0"

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
# database_enabled is set per environment in dev.exs, test.exs, prod.exs

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
  secret_key_base:
    "DauGZaFAyuvhf8qoZqqMUbcmikP0Mb0KHDpEY2Dbv35J54NA9L/0R9JYG8G+tmRu",
  adapter: Phoenix.Endpoint.Cowboy2Adapter

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
# Set to :new to use the refactored modular BufferServer
# Set to :old to use the original monolithic BufferServer
config :raxol, :buffer_system, :new

# Configure web interface settings
config :raxol, :web,
  default_theme: "dark",
  enable_websockets: true,
  session_timeout: 3600

# Configure demo terminal
config :raxol, :demo,
  max_sessions: 1000,
  session_timeout_ms: 1_800_000,
  max_sessions_per_ip: 10
