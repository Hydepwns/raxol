defmodule Raxol.Terminal.Config.Schema do
  
  @moduledoc """
  Schema definitions for terminal configuration.

  Defines the structure and types for all terminal configuration options.
  """

  @doc """
  Defines the schema for terminal configuration.

  This includes all possible configuration fields with their types,
  default values, and descriptions.
  """
  def config_schema do
    %{
      # Base settings
      terminal_type:
        {:enum,
         [
           :unknown,
           :xterm,
           :linux,
           :vt100,
           :vt220,
           :vt52,
           :rxvt,
           :screen,
           :konsole,
           :iterm,
           :windows
         ], "Detected terminal type"},
      color_mode:
        {:enum, [:basic, :extended, :truecolor], "Supported color mode"},
      unicode_support:
        {:boolean, "Whether the terminal supports unicode characters"},
      mouse_support: {:boolean, "Whether mouse support is enabled"},
      clipboard_support: {:boolean, "Whether clipboard integration is enabled"},
      bracketed_paste: {:boolean, "Whether bracketed paste mode is supported"},
      focus_support: {:boolean, "Whether focus reporting is supported"},
      title_support:
        {:boolean, "Whether setting the terminal title is supported"},
      hyperlinks:
        {:boolean, "Whether terminal hyperlinks (OSC 8) are supported"},
      sixel_support: {:boolean, "Whether Sixel graphics are supported"},
      image_support:
        {:boolean, "Whether other image protocols (e.g., iTerm) are supported"},
      sound_support: {:boolean, "Whether terminal bell/sound is supported"},

      # Display settings
      width: {:integer, "Terminal width in columns"},
      height: {:integer, "Terminal height in rows"},
      font_family: {:string, "Default font family"},
      font_size: {:integer, "Default font size"},
      cursor_style: {:enum, [:block, :underline, :bar], "Default cursor style"},
      cursor_blink: {:boolean, "Whether the cursor should blink"},
      cursor_color: {:string, "Default cursor color (hex or name)"},
      selection_color:
        {:string,
         "Default selection background color (hex or name, supports RGBA)"},

      # Rendering settings
      line_height: {:float, "Line height multiplier"},
      ligatures: {:boolean, "Whether font ligatures should be enabled"},
      font_rendering:
        {:enum, [:normal, :antialiased, :subpixel], "Font rendering mode"},
      batch_size: {:integer, "Number of operations to batch before rendering"},

      # Behavior settings
      scrollback_limit:
        {:integer, "Maximum number of lines in the scrollback buffer"},
      prompt: {:string, "Default command prompt string"},
      welcome_message: {:string, "Message displayed on terminal start"},
      command_history_size:
        {:integer, "Maximum number of commands to store in history"},
      enable_command_history: {:boolean, "Whether to save command history"},
      enable_syntax_highlighting:
        {:boolean, "Whether to enable syntax highlighting in inputs"},
      enable_fullscreen: {:boolean, "Whether to allow fullscreen mode"},
      accessibility_mode:
        {:boolean, "Whether accessibility features are enabled by default"},
      virtual_scroll:
        {:boolean, "Whether to enable virtual scrolling for large outputs"},

      # System/Performance settings
      memory_limit:
        {:integer, "Memory limit for the terminal process in bytes"},
      cleanup_interval:
        {:integer, "Interval for periodic cleanup tasks in milliseconds"},

      # Background settings
      background_type:
        {:enum, [:solid, :image, :animation], "Type of terminal background"},
      background_opacity: {:float, "Background opacity (0.0 to 1.0)"},
      background_image:
        {:string, "Path to background image file (if type is :image)"},
      background_blur: {:float, "Background blur radius (pixels)"},
      background_scale:
        {:enum, [:fit, :fill, :stretch, :tile],
         "How to scale the background image"},

      # Animation settings
      animation_type:
        {:enum, [:gif, :apng, :video],
         "Type of background animation (if type is :animation)"},
      animation_path: {:string, "Path to background animation file"},
      animation_fps: {:integer, "Target FPS for background animation"},
      animation_loop:
        {:boolean, "Whether the background animation should loop"},
      animation_blend:
        {:float, "Opacity blend factor for background animation (0.0 to 1.0)"}
    }
  end

  @doc """
  Returns the default configuration values.
  This delegates to the Defaults module for actual values.
  """
  def default_config do
    Raxol.Terminal.Config.Defaults.generate_default_config()
  end

  @doc """
  Returns the type information for a specific configuration path.

  ## Parameters

  * `path` - A list of keys representing the path to the configuration value

  ## Returns

  A tuple with type information or nil if the path doesn't exist
  """
  def get_type(path) do
    # Implementation to retrieve type info from the schema
    schema = config_schema()
    get_type_from_path(schema, path)
  end

  # Private function to retrieve type from nested schema
  defp get_type_from_path(_schema, []), do: nil

  defp get_type_from_path(schema, [key | rest]) when is_map(schema) do
    case Map.get(schema, key) do
      nil -> nil
      value when is_map(value) -> get_type_from_path(value, rest)
      value -> if rest == [], do: value, else: nil
    end
  end

  defp get_type_from_path(_schema, _path), do: nil

  def schema(), do: config_schema()

  @doc """
  Returns the schema in a format compatible with validation tests.
  Each field is a map with a :type key.
  """
  def test_schema do
    %{
      terminal_type: %{type: :atom},
      color_mode: %{type: :atom},
      unicode_support: %{type: :boolean},
      width: %{type: :integer},
      height: %{type: :integer}
    }
  end
end
