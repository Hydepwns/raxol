defmodule Raxol.Terminal.Configuration do
  @moduledoc """
  Manages the core Raxol terminal configuration struct.

  This module defines the main configuration structure and provides functions
  for creating and updating configuration based on defaults and user-provided options.

  It collaborates with other modules under `Raxol.Terminal.Config.*` for specific
  functionalities like defaults, profiles, capabilities detection, and applying
  settings to the running terminal.
  """

  alias Raxol.Terminal.Config.Defaults
  # Keep other aliases if needed by new/update or future getters/loaders
  # alias Raxol.Terminal.Config.Application
  # alias Raxol.Terminal.Config.Capabilities
  # alias Raxol.Terminal.Config.Profiles
  # alias Raxol.Terminal.Config.Validation, as: Validator
  # alias Raxol.Core.Preferences.Store

  require Logger

  @typep theme_map :: %{atom() => String.t()}

  @type terminal_type ::
          :iterm2
          | :windows_terminal
          | :xterm
          | :screen
          | :kitty
          | :alacritty
          | :konsole
          | :gnome_terminal
          | :vscode
          | :unknown
  @type color_mode :: :basic | :true_color | :palette
  @type background_type :: :solid | :transparent | :image | :animated
  @type animation_type :: :gif | :video | :shader | :particle

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          scrollback_height: non_neg_integer(),
          memory_limit: non_neg_integer(),
          cleanup_interval: non_neg_integer(),
          prompt: String.t(),
          welcome_message: String.t(),
          theme: theme_map(),
          command_history_size: non_neg_integer(),
          enable_command_history: boolean(),
          enable_syntax_highlighting: boolean(),
          enable_fullscreen: boolean(),
          accessibility_mode: boolean(),
          mouse_support: boolean(),
          bracketed_paste: boolean(),
          focus_support: boolean(),
          title_support: boolean(),
          unicode_support: boolean(),
          font_family: String.t(),
          font_size: integer(),
          line_height: float(),
          cursor_style: :block | :underline | :bar,
          cursor_blink: boolean(),
          batch_size: integer(),
          virtual_scroll: boolean(),
          ligatures: boolean(),
          font_rendering: :normal | :subpixel | :grayscale,
          cursor_color: String.t(),
          selection_color: String.t(),
          hyperlinks: boolean(),
          sixel_support: boolean(),
          image_support: boolean(),
          sound_support: boolean(),
          background_type: background_type(),
          background_opacity: float(),
          background_image: String.t() | nil,
          background_blur: float(),
          background_scale: :fit | :fill | :stretch
        }

  defstruct [
    :width,
    :height,
    :scrollback_height,
    :memory_limit,
    :cleanup_interval,
    :prompt,
    :welcome_message,
    :theme,
    :command_history_size,
    :enable_command_history,
    :enable_syntax_highlighting,
    :enable_fullscreen,
    :accessibility_mode,
    :mouse_support,
    :bracketed_paste,
    :focus_support,
    :title_support,
    :unicode_support,
    :font_family,
    :font_size,
    :line_height,
    :cursor_style,
    :cursor_blink,
    :batch_size,
    :virtual_scroll,
    :ligatures,
    :font_rendering,
    :cursor_color,
    :selection_color,
    :hyperlinks,
    :sixel_support,
    :image_support,
    :sound_support,
    :background_type,
    :background_opacity,
    :background_image,
    :background_blur,
    :background_scale
  ]

  @doc """
  Creates a new configuration struct, merging defaults with provided options.

  Fetches the base default configuration map and then merges any overrides
  provided in `opts`. The final result is converted into the `%__MODULE__{}` struct.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    base_config_map = Defaults.generate_default_config()

    merged_config_map =
      Enum.reduce(opts, base_config_map, fn {key, value}, acc ->
        if Map.has_key?(acc, key) or
             (key in __MODULE__.__struct__()) |> Map.keys() do
          Map.put(acc, key, value)
        else
          Logger.warning(
            "Ignoring unknown configuration option: #{inspect(key)}"
          )

          acc
        end
      end)

    struct_fields = __MODULE__.__struct__() |> Map.keys()
    config_for_struct = Map.take(merged_config_map, struct_fields)

    struct(__MODULE__, config_for_struct)
  end

  @doc """
  Updates an existing configuration struct with new values from a keyword list.
  """
  @spec update(t(), keyword()) :: t()
  def update(%__MODULE__{} = config, opts) do
    struct(config, opts)
  end

  # TODO: Add logic for loading/merging external config files (e.g., from TOML/YAML).
  #       This function would likely call Defaults.generate_default_config(),
  #       load the external file, merge them, and then call new/1 with the final map.
  # def load_from_file(path, opts \\ []) do ... end

  # TODO: Add simple getter functions for config values if direct access is discouraged.
  # def get_config_value(%__MODULE__{} = config, key) do Map.get(config, key) end
end
