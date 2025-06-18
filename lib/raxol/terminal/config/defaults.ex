defmodule Raxol.Terminal.Config.Defaults do
  @moduledoc '''
  Default terminal configuration values.

  Provides functions for generating default terminal configurations.
  '''

  @doc '''
  Generates a default configuration map merging all specific defaults.

  This map represents the base configuration before any detection or user overrides.

  ## Returns

  A map containing default configuration values for all settings.
  '''
  def generate_default_config do
    %{
      # Base settings often detected or overridden
      terminal_type: :unknown,
      # Safer default, detected later
      color_mode: :basic,
      # Safer default, detected later
      unicode_support: false,
      # Safer default, detected later
      mouse_support: false,
      # Safer default, detected later
      clipboard_support: false,
      # Safer default, detected later
      bracketed_paste: false,
      # Safer default, detected later
      focus_support: false,
      # Safer default, detected later
      title_support: false,
      # Safer default, detected later
      hyperlinks: false,
      # Safer default, detected later
      sixel_support: false,
      # Safer default, detected later
      image_support: false,
      # Safer default, detected later
      sound_support: false,
      # Added: ANSI config for compatibility with code/tests expecting :ansi key
      ansi: %{
        enabled: true,
        color_mode: :basic,
        colors: %{}
      }
    }
    |> Map.merge(default_display_config())
    |> Map.merge(default_rendering_config())
    |> Map.merge(default_behavior_config())
    |> Map.merge(default_system_config())
    |> Map.merge(default_background_config())
    |> Map.merge(default_animation_config())

    # Note: Input defaults like escape_timeout are less common in the main config struct
    # Note: ANSI color map is usually part of theme/profile, not base defaults here
  end

  @doc '''
  Generates a default display configuration.

  ## Returns

  A map containing default display configuration values.
  '''
  def default_display_config do
    %{
      width: 80,
      height: 24,
      # Aligned from configuration.ex
      font_family: "Monospace",
      # Aligned from configuration.ex
      font_size: 12,
      cursor_style: :block,
      cursor_blink: true,
      # Added from configuration.ex
      cursor_color: "#ffffff",
      # Added from configuration.ex
      selection_color: "rgba(255, 255, 255, 0.3)"
      # Removed: colors, truecolor, unicode, title (handled in main map or detection)
    }
  end

  @doc '''
  Generates a default rendering configuration.

  ## Returns

  A map containing default rendering configuration values.
  '''
  def default_rendering_config do
    %{
      # Aligned from configuration.ex
      line_height: 1.0,
      # Added from configuration.ex
      ligatures: false,
      # Added from configuration.ex
      font_rendering: :normal,
      # Added from configuration.ex
      batch_size: 100
      # Removed: fps, double_buffer, redraw_mode, optimize_empty_cells, smooth_resize, cell_width, cell_height (less common top-level defaults)
    }
  end

  @doc '''
  Generates a default behavior configuration.

  ## Returns

  A map containing default behavior configuration values.
  '''
  def default_behavior_config do
    %{
      # Aligned from configuration.ex (@default_scrollback_height)
      scrollback_limit: 1000,
      # Added from configuration.ex
      prompt: "> ",
      # Added from configuration.ex
      welcome_message: "Welcome to Raxol Terminal",
      # Added from configuration.ex
      command_history_size: 1000,
      # Added from configuration.ex (renamed from save_history)
      enable_command_history: true,
      # Added from configuration.ex
      enable_syntax_highlighting: true,
      # Added from configuration.ex
      enable_fullscreen: false,
      # Added from configuration.ex
      accessibility_mode: false,
      # Added from configuration.ex
      virtual_scroll: false
      # Removed: history_file, exit_on_close, confirm_exit, bell_style, silence_bell, word_separators, auto_wrap, scroll_on_output, scroll_on_keystroke (less common or potentially profile-specific)
    }
  end

  @doc '''
  Generates a default system/performance configuration.

  ## Returns

  A map containing default system/performance configuration values.
  '''
  def default_system_config do
    %{
      # Added from configuration.ex
      memory_limit: 50 * 1024 * 1024,
      # Added from configuration.ex
      cleanup_interval: 60 * 1000
    }
  end

  @doc '''
  Generates a default background configuration.

  ## Returns

  A map containing default background configuration values.
  '''
  def default_background_config do
    %{
      # Added from configuration.ex
      background_type: :solid,
      # Added from configuration.ex
      background_opacity: 1.0,
      # Added from configuration.ex
      background_image: "",
      # Added from configuration.ex
      background_blur: 0.0,
      # Added from configuration.ex
      background_scale: :fit
    }
  end

  @doc '''
  Generates a default animation configuration.

  ## Returns

  A map containing default animation configuration values.
  '''
  def default_animation_config do
    %{
      # Added from configuration.ex
      animation_type: :gif,
      # Added from configuration.ex
      animation_path: "",
      # Added from configuration.ex
      animation_fps: 30,
      # Added from configuration.ex
      animation_loop: true,
      # Added from configuration.ex
      animation_blend: 0.8
    }
  end

  def minimal_config do
    generate_default_config()
  end

  # Removed minimal_config - use generate_default_config and override as needed
end
