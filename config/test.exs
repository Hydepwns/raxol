import Config

# Configure your database
# config :raxol, Raxol.Repo,
#   database: "raxol_test\#{System.get_env(\"MIX_TEST_PARTITION\")}\",
#   pool_size: 5,
#   pool: Ecto.Adapters.SQL.Sandbox

# Override Repo adapter and pool for tests
config :raxol, Raxol.Repo,
  adapter: Raxol.Test.MockDB,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Ensure it\'s disabled unless explicitly used in specific tests
  enabled: false

# Configure database settings
# Global flag to disable database
config :raxol, database_enabled: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :raxol, RaxolWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false

# In test we don't send emails.
config :raxol, Raxol.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure terminal settings for testing
config :raxol, :terminal,
  default_width: 80,
  default_height: 24,
  scrollback_lines: 100,
  enable_ansi: true,
  enable_mouse: false,
  debug_mode: false,
  log_level: :warn

# Flag to control compilation of AI-related tests
config :raxol, :compile_ai_tests, false

# Configure web interface settings for testing
config :raxol, :web,
  default_theme: "light",
  enable_websockets: false,
  session_timeout: 60,
  debug_mode: false,
  enable_hot_reload: false

# Configure test helpers
config :raxol, :test_helpers,
  enable_mock_web: true,
  mock_timeout: 1000

# Disable unnecessary services for ANSI processor tests
config :raxol, :ansi_processor_test,
  disable_services: [
    :database,
    :web,
    :mailer,
    :hot_reload,
    :color_system
  ]
