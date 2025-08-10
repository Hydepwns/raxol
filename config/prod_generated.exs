import Config

# Raxol Configuration for Production Environment
# 🤖 Generated from config schema - do not edit directly  

config :raxol, :terminal,
  default_width: 80,
  default_height: 24,
  scrollback_lines: 1000,
  enable_ansi: true,
  enable_mouse: true,
  debug_mode: false

config :raxol, :web,
  default_theme: "light",
  enable_websockets: true,
  session_timeout: 3600,
  enable_hot_reload: false,
  debug_mode: false

config :raxol, :core,
  max_concurrent_sessions: 1000,
  buffer_size_limit: 10485760

# Phoenix Production Configuration
config :raxol, RaxolWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# Database Production Configuration  
config :raxol, Raxol.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: [:inet6]

# Logger Configuration
config :logger, level: :info
