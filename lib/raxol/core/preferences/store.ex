defmodule Raxol.Core.Preferences.Store do
  @moduledoc """
  Handles storage and retrieval of user preferences.
  """

  # TODO: Implement preference storage logic (move from Configuration)

  # --- Function Moved from Raxol.Terminal.Configuration ---

  # Assuming 't' is the old Configuration struct or a map
  # Needs alias Raxol.Core.UserPreferences or similar
  # Adjust if name changed
  alias Raxol.Core.UserPreferences

  @spec save_to_preferences(map() | struct()) :: :ok
  # Make public
  def save_to_preferences(config) do
    # Convert struct to map if necessary
    config_map = if is_struct(config), do: Map.from_struct(config), else: config

    pref_data =
      Map.take(config_map, [
        # List relevant keys based on actual config structure
        :font_family,
        :font_size,
        :line_height,
        :cursor_style,
        :cursor_blink,
        :theme,
        :ligatures,
        :font_rendering,
        :cursor_color,
        :selection_color,
        :background_type,
        :background_opacity,
        :background_image,
        :background_blur,
        :background_scale,
        :animation_type,
        :animation_path,
        :animation_fps,
        :animation_loop,
        :animation_blend,
        # Add other preference keys as needed
        :prompt,
        :welcome_message,
        :command_history_size,
        :enable_command_history,
        :enable_syntax_highlighting,
        :enable_fullscreen,
        :accessibility_mode
      ])

    UserPreferences.set(:terminal_config, pref_data)
  end
end

# --- Code previously after end ---
