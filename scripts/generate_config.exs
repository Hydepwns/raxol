#!/usr/bin/env elixir

defmodule ConfigGenerator do
  @moduledoc """
  Generates environment-specific configuration files from a unified schema.
  
  This ensures DRY configuration management by maintaining a single source
  of truth for all configuration values across environments.
  """
  
  def generate_all do
    IO.puts("🔧 Generating configuration files from schema...")
    
    # In a full implementation, this would load from YAML
    config_data = get_demo_config_data()
    
    # Generate environment-specific configs
    generate_dev_config(config_data)
    generate_test_config(config_data) 
    generate_prod_config(config_data)
    
    IO.puts("✅ Configuration generation complete!")
  end
  
  defp get_demo_config_data do
    # Simplified config data (would come from YAML schema)
    %{
      base: %{
        terminal: %{
          default_width: 80,
          default_height: 24,
          scrollback_lines: 1000,
          enable_ansi: true,
          enable_mouse: true
        },
        web: %{
          default_theme: "light",
          enable_websockets: true,
          session_timeout: 3600
        },
        core: %{
          max_concurrent_sessions: 100,
          buffer_size_limit: 1048576
        }
      },
      environments: %{
        dev: %{
          web: %{enable_hot_reload: true, debug_mode: true},
          terminal: %{debug_mode: true},
          core: %{max_concurrent_sessions: 10}
        },
        test: %{
          core: %{max_concurrent_sessions: 5, buffer_size_limit: 65536},
          terminal: %{default_width: 40, default_height: 12}
        },
        prod: %{
          web: %{enable_hot_reload: false, debug_mode: false},
          terminal: %{debug_mode: false},
          core: %{max_concurrent_sessions: 1000, buffer_size_limit: 10485760}
        }
      }
    }
  end
  
  defp generate_dev_config(config_data) do
    merged_config = merge_config(config_data.base, config_data.environments.dev)
    
    content = """
import Config

# Raxol Configuration for Development Environment
# 🤖 Generated from config schema - do not edit directly

config :raxol, :terminal,
  default_width: #{merged_config.terminal.default_width},
  default_height: #{merged_config.terminal.default_height},
  scrollback_lines: #{merged_config.terminal.scrollback_lines},
  enable_ansi: #{merged_config.terminal.enable_ansi},
  enable_mouse: #{merged_config.terminal.enable_mouse},
  debug_mode: #{Map.get(merged_config.terminal, :debug_mode, false)}

config :raxol, :web,
  default_theme: "#{merged_config.web.default_theme}",
  enable_websockets: #{merged_config.web.enable_websockets},
  session_timeout: #{merged_config.web.session_timeout},
  enable_hot_reload: #{Map.get(merged_config.web, :enable_hot_reload, false)},
  debug_mode: #{Map.get(merged_config.web, :debug_mode, false)}

config :raxol, :core,
  max_concurrent_sessions: #{merged_config.core.max_concurrent_sessions},
  buffer_size_limit: #{merged_config.core.buffer_size_limit}

# Phoenix Configuration  
config :raxol, RaxolWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: RaxolWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Raxol.PubSub,
  live_view: [signing_salt: "development_salt"],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
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
config :logger, :console, format: "[$level] $message\\n"
"""

    File.write!("config/dev_generated.exs", content)
    IO.puts("✅ Generated config/dev_generated.exs")
  end
  
  defp generate_test_config(config_data) do
    merged_config = merge_config(config_data.base, config_data.environments.test)
    
    content = """
import Config

# Raxol Configuration for Test Environment  
# 🤖 Generated from config schema - do not edit directly

config :raxol, :terminal,
  default_width: #{Map.get(merged_config.terminal, :default_width, config_data.base.terminal.default_width)},
  default_height: #{Map.get(merged_config.terminal, :default_height, config_data.base.terminal.default_height)},
  scrollback_lines: #{merged_config.terminal.scrollback_lines},
  enable_ansi: #{merged_config.terminal.enable_ansi},
  enable_mouse: #{merged_config.terminal.enable_mouse},
  debug_mode: false

config :raxol, :web,
  default_theme: "#{merged_config.web.default_theme}",
  enable_websockets: #{merged_config.web.enable_websockets},
  session_timeout: #{merged_config.web.session_timeout}

config :raxol, :core,
  max_concurrent_sessions: #{merged_config.core.max_concurrent_sessions},
  buffer_size_limit: #{merged_config.core.buffer_size_limit}

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
"""

    File.write!("config/test_generated.exs", content)
    IO.puts("✅ Generated config/test_generated.exs")
  end
  
  defp generate_prod_config(config_data) do
    merged_config = merge_config(config_data.base, config_data.environments.prod)
    
    content = """
import Config

# Raxol Configuration for Production Environment
# 🤖 Generated from config schema - do not edit directly  

config :raxol, :terminal,
  default_width: #{merged_config.terminal.default_width},
  default_height: #{merged_config.terminal.default_height},
  scrollback_lines: #{merged_config.terminal.scrollback_lines},
  enable_ansi: #{merged_config.terminal.enable_ansi},
  enable_mouse: #{merged_config.terminal.enable_mouse},
  debug_mode: #{Map.get(merged_config.terminal, :debug_mode, false)}

config :raxol, :web,
  default_theme: "#{merged_config.web.default_theme}",
  enable_websockets: #{merged_config.web.enable_websockets},
  session_timeout: #{merged_config.web.session_timeout},
  enable_hot_reload: #{Map.get(merged_config.web, :enable_hot_reload, false)},
  debug_mode: #{Map.get(merged_config.web, :debug_mode, false)}

config :raxol, :core,
  max_concurrent_sessions: #{merged_config.core.max_concurrent_sessions},
  buffer_size_limit: #{merged_config.core.buffer_size_limit}

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
"""

    File.write!("config/prod_generated.exs", content)
    IO.puts("✅ Generated config/prod_generated.exs")
  end
  
  defp merge_config(base, env_specific) do
    # Deep merge base config with environment-specific overrides
    Map.merge(base, env_specific, fn _key, base_val, env_val ->
      if is_map(base_val) and is_map(env_val) do
        Map.merge(base_val, env_val)
      else
        env_val
      end
    end)
  end
end

ConfigGenerator.generate_all()