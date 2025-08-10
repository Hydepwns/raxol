import Config

# Raxol Configuration for Test Environment  
# 🤖 Generated from config schema - do not edit directly

config :raxol, :terminal,
  default_width: 40,
  default_height: 12,
  scrollback_lines: 1000,
  enable_ansi: true,
  enable_mouse: true,
  debug_mode: false

config :raxol, :web,
  default_theme: "light",
  enable_websockets: true,
  session_timeout: 3600

config :raxol, :core,
  max_concurrent_sessions: 5,
  buffer_size_limit: 65536

# Phoenix Test Configuration
config :raxol, RaxolWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base",
  server: false

# Database Test Configuration
config :raxol, Raxol.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost", 
  database: "raxol_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Logger Configuration
config :logger, level: :warning
