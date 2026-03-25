defmodule Raxol.Config.Schema.Definitions do
  @moduledoc """
  Schema definitions for all Raxol configuration sections.
  """

  def terminal_schema do
    %{
      width: %{
        type: :integer,
        required: false,
        default: 80,
        constraints: [{:min, 10}, {:max, 500}],
        description: "Terminal width in columns"
      },
      height: %{
        type: :integer,
        required: false,
        default: 24,
        constraints: [{:min, 5}, {:max, 200}],
        description: "Terminal height in rows"
      },
      scrollback_size: %{
        type: :integer,
        required: false,
        default: 10_000,
        constraints: [{:min, 0}, {:max, 1_000_000}],
        description: "Number of lines to keep in scrollback buffer"
      },
      encoding: %{
        type: {:enum, ["UTF-8", "ASCII", "ISO-8859-1"]},
        required: false,
        default: "UTF-8",
        description: "Character encoding for terminal"
      },
      cursor: cursor_schema(),
      colors: colors_schema(),
      bell: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable terminal bell"
      },
      font: font_schema()
    }
  end

  def cursor_schema do
    %{
      style: %{
        type: {:enum, [:block, :underline, :bar]},
        required: false,
        default: :block,
        description: "Cursor display style"
      },
      blink: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable cursor blinking"
      },
      blink_rate: %{
        type: :integer,
        required: false,
        default: 500,
        constraints: [{:min, 100}, {:max, 2000}],
        description: "Cursor blink rate in milliseconds"
      }
    }
  end

  def colors_schema do
    %{
      palette: %{
        type: {:enum, [:default, :solarized, :dracula, :nord, :custom]},
        required: false,
        default: :default,
        description: "Color palette to use"
      },
      true_color: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable 24-bit true color support"
      },
      custom_colors: %{
        type: {:map, :string},
        required: false,
        default: %{},
        description: "Custom color definitions"
      }
    }
  end

  def font_schema do
    %{
      family: %{
        type: :string,
        required: false,
        default: "monospace",
        description: "Font family name"
      },
      size: %{
        type: :integer,
        required: false,
        default: 12,
        constraints: [{:min, 6}, {:max, 72}],
        description: "Font size in points"
      },
      bold: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Use bold font weight"
      }
    }
  end

  def buffer_schema do
    %{
      max_size: %{
        type: :integer,
        required: false,
        default: 1_048_576,
        constraints: [{:min, 1024}, {:max, 104_857_600}],
        description: "Maximum buffer size in bytes"
      },
      chunk_size: %{
        type: :integer,
        required: false,
        default: 4096,
        constraints: [{:min, 512}, {:max, 65_536}],
        description: "Buffer chunk size for operations"
      },
      compression: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable buffer compression"
      },
      compression_threshold: %{
        type: :integer,
        required: false,
        default: 10_240,
        constraints: [{:min, 1024}],
        description: "Minimum size before compression is applied"
      }
    }
  end

  def rendering_schema do
    %{
      fps_target: %{
        type: :integer,
        required: false,
        default: 60,
        constraints: [{:min, 1}, {:max, 144}],
        description: "Target frames per second"
      },
      max_frame_skip: %{
        type: :integer,
        required: false,
        default: 3,
        constraints: [{:min, 0}, {:max, 10}],
        description: "Maximum consecutive frames to skip"
      },
      enable_animations: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable UI animations"
      },
      animation_duration: %{
        type: :integer,
        required: false,
        default: 200,
        constraints: [{:min, 0}, {:max, 1000}],
        description: "Default animation duration in milliseconds"
      },
      performance_mode: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable performance mode (reduces quality for speed)"
      },
      gpu_acceleration: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable GPU acceleration when available"
      }
    }
  end

  def plugins_schema do
    %{
      enabled: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable plugin system"
      },
      directory: %{
        type: :string,
        required: false,
        default: "plugins",
        constraints: [{:min_length, 1}],
        description: "Directory containing plugins"
      },
      auto_reload: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Automatically reload plugins on file changes"
      },
      allowed: %{
        type: {:list, :string},
        required: false,
        default: [],
        description: "List of allowed plugin names (empty allows all)"
      },
      disabled: %{
        type: {:list, :string},
        required: false,
        default: [],
        description: "List of disabled plugin names"
      },
      load_timeout: %{
        type: :integer,
        required: false,
        default: 5000,
        constraints: [{:min, 100}, {:max, 30_000}],
        description: "Plugin load timeout in milliseconds"
      }
    }
  end

  def security_schema do
    %{
      session_timeout: %{
        type: :integer,
        required: false,
        default: 1800,
        constraints: [{:min, 60}, {:max, 86_400}],
        description: "Session timeout in seconds"
      },
      max_sessions: %{
        type: :integer,
        required: false,
        default: 5,
        constraints: [{:min, 1}, {:max, 100}],
        description: "Maximum concurrent sessions per user"
      },
      enable_audit: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable security audit logging"
      },
      password_min_length: %{
        type: :integer,
        required: false,
        default: 8,
        constraints: [{:min, 6}, {:max, 128}],
        description: "Minimum password length"
      },
      password_require_special: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Require special characters in passwords"
      },
      password_require_numbers: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Require numbers in passwords"
      },
      enable_2fa: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable two-factor authentication"
      },
      rate_limiting: rate_limiting_schema()
    }
  end

  def rate_limiting_schema do
    %{
      enabled: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable rate limiting"
      },
      window: %{
        type: :integer,
        required: false,
        default: 60_000,
        constraints: [{:min, 1000}],
        description: "Rate limit window in milliseconds"
      },
      max_requests: %{
        type: :integer,
        required: false,
        default: 100,
        constraints: [{:min, 1}],
        description: "Maximum requests per window"
      }
    }
  end

  def performance_schema do
    %{
      profiling_enabled: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable performance profiling"
      },
      benchmark_on_start: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Run benchmarks on application start"
      },
      cache_size: %{
        type: :integer,
        required: false,
        default: 100_000,
        constraints: [{:min, 0}],
        description: "Maximum cache entries"
      },
      cache_ttl: %{
        type: :integer,
        required: false,
        default: 300_000,
        constraints: [{:min, 0}],
        description: "Cache time-to-live in milliseconds"
      },
      worker_pool_size: %{
        type: :integer,
        required: false,
        default: {:erlang, :system_info, [:schedulers_online]},
        constraints: [{:min, 1}, {:max, 128}],
        description: "Size of worker process pool"
      }
    }
  end

  def theme_schema do
    %{
      name: %{
        type: :string,
        required: false,
        default: "default",
        description: "Active theme name"
      },
      auto_switch: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Automatically switch theme based on system"
      },
      custom_themes_dir: %{
        type: :string,
        required: false,
        default: "themes",
        description: "Directory containing custom themes"
      }
    }
  end

  def logging_schema do
    %{
      level: %{
        type: {:enum, [:debug, :info, :warning, :error]},
        required: false,
        default: :info,
        description: "Logging level"
      },
      file: %{
        type: :string,
        required: false,
        default: "logs/raxol.log",
        description: "Log file path"
      },
      max_file_size: %{
        type: :integer,
        required: false,
        default: 10_485_760,
        constraints: [{:min, 1024}],
        description: "Maximum log file size in bytes"
      },
      rotation_count: %{
        type: :integer,
        required: false,
        default: 5,
        constraints: [{:min, 0}, {:max, 100}],
        description: "Number of rotated log files to keep"
      },
      format: %{
        type: {:enum, [:text, :json]},
        required: false,
        default: :text,
        description: "Log output format"
      },
      include_metadata: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Include metadata in log entries"
      }
    }
  end

  def accessibility_schema do
    %{
      screen_reader: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable screen reader support"
      },
      high_contrast: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable high contrast mode"
      },
      focus_indicators: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Show focus indicators"
      },
      reduce_motion: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Reduce UI motion and animations"
      },
      font_scaling: %{
        type: :float,
        required: false,
        default: 1.0,
        constraints: [{:min, 0.5}, {:max, 3.0}],
        description: "Font scaling factor"
      }
    }
  end

  def keybindings_schema do
    %{
      enabled: %{
        type: :boolean,
        required: false,
        default: true,
        description: "Enable custom keybindings"
      },
      config_file: %{
        type: :string,
        required: false,
        default: "keybindings.toml",
        description: "Keybindings configuration file"
      },
      vim_mode: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable Vim keybindings"
      },
      emacs_mode: %{
        type: :boolean,
        required: false,
        default: false,
        description: "Enable Emacs keybindings"
      }
    }
  end
end
