# WASM Compilation Configuration for Raxol
# This file configures the WebAssembly compilation target for web deployment

import Config

# WASM-specific configuration
config :raxol, :wasm,
  # Output directory for compiled WASM files
  output_dir: "priv/static/wasm",

  # Optimization level (0-3, s, z)
  optimization_level: 2,

  # Enable WASI (WebAssembly System Interface)
  enable_wasi: false,

  # Memory configuration
  initial_memory: 16,  # In MB
  maximum_memory: 256, # In MB

  # Features to include in WASM build
  features: [
    :terminal_emulation,
    :ansi_parsing,
    :themes,
    :basic_plugins
  ],

  # Features to exclude for smaller bundle size
  exclude_features: [
    :docker_integration,
    :native_file_system,
    :process_spawning,
    :network_access
  ],

  # JavaScript interop configuration
  js_interop: %{
    # Exported functions to JavaScript
    exports: [
      :create_terminal,
      :process_input,
      :resize_terminal,
      :get_output,
      :apply_theme,
      :load_plugin
    ],

    # JavaScript functions to import
    imports: [
      :console_log,
      :request_animation_frame,
      :local_storage_get,
      :local_storage_set
    ]
  }

# Disable features not compatible with WASM
config :raxol,
  # Disable GenServer-based features for WASM
  use_genservers: false,

  # Use lightweight alternatives
  enable_history: false,
  alternate_buffer: false,

  # Web-safe defaults
  default_width: 80,
  default_height: 24,

  # Disable native integrations
  enable_nif: false,
  enable_port_driver: false

# Logger configuration for WASM
config :logger,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

# Minimal dependencies for WASM build
config :raxol, :wasm_deps,
  included: [
    # Core terminal functionality
    :terminal_core,
    :ansi_parser,
    :screen_buffer,

    # UI components (lightweight)
    :basic_components,
    :themes,

    # Minimal plugin support
    :plugin_loader
  ],

  excluded: [
    # Heavy dependencies
    :phoenix,
    :ecto,
    :postgrex,

    # Native dependencies
    :termbox2_nif,
    :bcrypt,

    # Development-only
    :ex_doc,
    :credo,
    :dialyxir
  ]

# Performance optimizations for WASM
config :raxol, :wasm_performance,
  # Use pre-compiled ANSI sequences
  cache_ansi_sequences: true,

  # Minimal render pipeline
  use_optimized_renderer: true,

  # Disable unused features
  enable_mouse: false,
  enable_graphics: false,

  # Memory management
  buffer_pool_size: 10,
  max_undo_history: 50