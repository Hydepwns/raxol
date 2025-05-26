# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# Configure Ecto repositories
config :raxol, ecto_repos: [Raxol.Repo]

# You can configure your application as:
#
#     config :ratatouille, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:ratatouille, :key)

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

# Configure the database
config :raxol, Raxol.Repo,
  database: "raxol_dev",
  hostname: "localhost",
  enabled: true

# Configure the application
config :raxol,
  database_enabled: true

# Import environment specific config
import_config "#{config_env()}.exs"

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
      [:default, ~w(--sourcemap=inline --watch), version: "0.8"]
    },
    # Configure dart_sass version
    sass: {
      DartSass,
      :install_and_run,
      [:default, ~w(--watch), version: "0.7"]
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

# Configure web interface settings
config :raxol, :web,
  default_theme: "dark",
  enable_websockets: true,
  session_timeout: 3600
