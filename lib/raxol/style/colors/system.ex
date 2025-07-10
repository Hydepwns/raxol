defmodule Raxol.Style.Colors.System do
  @moduledoc """
  Core color system for the Raxol terminal emulator.

  This module provides a robust color system that:
  - Manages color palettes with semantic naming
  - Provides accessible color alternatives for high contrast mode
  - Supports theme customization
  - Calculates contrast ratios for text/background combinations
  - Automatically adjusts colors for optimal readability
  - Integrates with the accessibility module

  ## Usage

  ```elixir
  # Initialize the color system
  ColorSystem.init()

  # Get a semantic color (will respect accessibility settings)
  color = ColorSystem.get_color(:primary)

  # Get a specific color variation
  hover_color = ColorSystem.get_color(:primary, :hover)

  # Register a custom theme
  ColorSystem.register_theme(%{
    primary: "#0077CC",
    secondary: "#00AAFF",
    background: "#001133",
    foreground: "#FFFFFF",
    accent: "#FF9900"
  })

  # Apply a theme
  ColorSystem.apply_theme(:ocean)
  ```
  """

  import Raxol.Guards

  alias Raxol.Style.Colors.Utilities
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Style.Colors.Color
  alias Raxol.UI.Theming.Theme

  defstruct [
    # ... existing code ...
  ]

  @default_theme :default

  @doc """
  Initialize the color system.

  This sets up the default themes, registers event handlers for accessibility changes,
  and establishes the default color palette.

  ## Options

  * `:theme` - The initial theme to use (default: `:default`)
  * `:high_contrast` - Whether to start in high contrast mode (default: from accessibility settings)

  ## Examples

      iex> ColorSystem.init()
      :ok

      iex> ColorSystem.init(theme: :dark)
      :ok
  """
  def init(opts \\ []) do
    # Get the initial theme (as an atom or struct)
    initial_theme_id = Keyword.get(opts, :theme, @default_theme)
    initial_theme = Theme.get(initial_theme_id)

    # Get high contrast setting from accessibility or options
    high_contrast =
      case Process.get(:accessibility_options) do
        nil ->
          Keyword.get(opts, :high_contrast, false)

        accessibility_options ->
          Keyword.get(
            opts,
            :high_contrast,
            accessibility_options[:high_contrast]
          )
      end

    # Set current theme in process (optional, for compatibility)
    Process.put(:color_system_current_theme, initial_theme.name)
    Process.put(:color_system_high_contrast, high_contrast)

    # Register event handlers for accessibility changes
    EventManager.register_handler(
      :accessibility_high_contrast,
      __MODULE__,
      :handle_high_contrast
    )

    # Apply the initial theme
    apply_theme(initial_theme.name, high_contrast: high_contrast)

    :ok
  end

  @doc """
  Get a color from the current theme.

  This function respects the current accessibility settings, automatically
  returning high-contrast alternatives when needed.

  ## Parameters

  * `color_name` - The semantic name of the color (e.g., `:primary`, `:error`)
  * `variant` - The variant of the color (e.g., `:base`, `:hover`, `:active`) (default: `:base`)

  ## Examples

      iex> ColorSystem.get_color(:primary)
      "#0077CC"

      iex> ColorSystem.get_color(:primary, :hover)
      "#0088DD"
  """
  def get_color(color_name, variant \\ :base) do
    current_theme = get_current_theme()

    # Check for high contrast mode first
    color =
      if get_high_contrast() do
        get_high_contrast_color(current_theme, color_name, variant)
      else
        get_standard_color(current_theme, color_name, variant)
      end

    case color do
      %Color{} = c -> c.hex
      hex when is_binary(hex) -> hex
      _ -> nil
    end
  end

  @doc """
  Register a custom theme.

  ## Parameters

  * `theme_attrs` - Map of theme attributes

  ## Examples

      iex> ColorSystem.register_theme(%{
      ...>   primary: "#0077CC",
      ...>   secondary: "#00AAFF",
      ...>   background: "#001133",
      ...>   foreground: "#FFFFFF",
      ...>   accent: "#FF9900"
      ...> })
      :ok
  """
  def register_theme(theme_attrs) do
    theme = Theme.new(theme_attrs)
    Theme.register(theme)
  end

  @doc """
  Applies a theme to the color system.

  ## Parameters

  - `theme_name` - The name of the theme to apply
  - `opts` - Additional options
    - `:high_contrast` - Whether to apply high contrast mode (default: current setting)

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def apply_theme(theme_name, opts \\ []) do
    high_contrast =
      Keyword.get(
        opts,
        :high_contrast,
        Process.get(:color_system_high_contrast, false)
      )

    theme = Theme.get(theme_name)
    # Always store the theme id (atom) in the process dictionary
    Process.put(:color_system_current_theme, theme.id)
    Process.put(:color_system_high_contrast, high_contrast)

    EventManager.dispatch(
      {:theme_changed, %{theme: theme, high_contrast: high_contrast}}
    )

    :ok
  end

  @doc """
  Handle high contrast mode changes from the accessibility module.
  """
  def handle_high_contrast({:accessibility_high_contrast, enabled}) do
    # Update high contrast setting
    Process.put(:color_system_high_contrast, enabled)

    # Re-apply current theme with new high contrast setting
    current_theme = get_current_theme()
    apply_theme(current_theme.name, high_contrast: enabled)

    EventManager.dispatch({:high_contrast_changed, enabled})
  end

  # Private functions

  defp get_current_theme do
    theme_name = Process.get(:color_system_current_theme, @default_theme)

    # Try both atom and string forms
    candidates =
      cond do
        is_binary(theme_name) -> [theme_name, String.to_atom(theme_name)]
        is_atom(theme_name) -> [theme_name, Atom.to_string(theme_name)]
        true -> [theme_name]
      end

    theme = Enum.find_value(candidates, fn name -> Theme.get(name) end)

    case theme do
      nil -> Theme.get(@default_theme)
      theme -> theme
    end
  end

  defp get_high_contrast do
    Process.get(:color_system_high_contrast, false)
  end

  defp get_standard_color(nil, _color_name, _variant), do: nil

  defp get_standard_color(theme, color_name, variant) do
    val =
      Map.get(theme.variants || %{}, {color_name, variant}) ||
        Map.get(theme.colors, color_name) ||
        Map.get(
          theme.variants || %{},
          {to_string(color_name), to_string(variant)}
        ) ||
        Map.get(theme.colors, to_string(color_name))

    case val do
      %Color{} = c -> c.hex
      hex when is_binary(hex) -> hex
      _ -> nil
    end
  end

  defp get_high_contrast_color(theme, color_name, variant) do
    # First try to get a specific high contrast variant
    val =
      Map.get(theme.variants || %{}, {color_name, variant, :high_contrast}) ||
        Map.get(
          theme.variants || %{},
          {to_string(color_name), to_string(variant), "high_contrast"}
        )

    case val do
      %Color{} = c ->
        c.hex

      hex when is_binary(hex) ->
        hex

      _ ->
        # If no specific high contrast variant, generate one from the standard color
        standard_color = get_standard_color(theme, color_name, variant)

        case standard_color do
          nil ->
            nil

          hex when is_binary(hex) ->
            color = Color.from_hex(hex)
            background = get_standard_color(theme, :background, :base)

            background_color =
              if background,
                do: Color.from_hex(background),
                else: Color.from_hex("#000000")

            # For high contrast mode, always generate a more contrasting color
            # Use a higher contrast requirement to ensure the color is noticeably different
            high_contrast_color =
              generate_high_contrast_color(color, background_color)

            high_contrast_color.hex

          _ ->
            standard_color
        end
    end
  end

  defp generate_high_contrast_color(color, background_color) do
    # Calculate current contrast ratio
    current_ratio = Utilities.contrast_ratio(color, background_color)

    # For high contrast mode, we want a ratio of at least 7.0 (AAA level)
    target_ratio = 7.0

    if current_ratio >= target_ratio do
      # If already high contrast, make it even more extreme
      # Use the increase_contrast function to make it more extreme
      Utilities.increase_contrast(color)
    else
      # If not high contrast, adjust it to meet the target ratio
      # Use a more aggressive adjustment to ensure the color is noticeably different
      adjusted_color =
        Utilities.adjust_for_contrast(color, background_color, :aaa, :normal)

      # If the adjustment didn't change the color (because it already met requirements),
      # force it to be more extreme
      if adjusted_color.hex == color.hex do
        Utilities.increase_contrast(color)
      else
        adjusted_color
      end
    end
  end

  @spec get_current_theme_name() :: atom() | String.t()
  def get_current_theme_name do
    Process.get(:color_system_current_theme, @default_theme)
  end

  @doc """
  Get a UI color by role (e.g., :primary_button) from the current theme.
  Resolves the role using the theme's ui_mappings, then fetches the color.
  Returns nil if the role or color is not found.
  """
  @spec get_ui_color(atom()) :: any()
  def get_ui_color(ui_role) do
    theme = get_current_theme()

    case Map.fetch(theme.ui_mappings || %{}, ui_role) do
      {:ok, color_name} when is_atom(color_name) ->
        get_color(color_name)

      {:ok, color_name} when is_binary(color_name) ->
        get_color(String.to_atom(color_name))

      _ ->
        nil
    end
  end

  @doc """
  Get all UI colors for the current theme as a map of role => color.
  """
  @spec get_all_ui_colors() :: map()
  def get_all_ui_colors() do
    theme = get_current_theme()

    if theme == nil do
      %{}
    else
      get_all_ui_colors(theme)
    end
  end

  @doc """
  Get all UI colors for a specific theme as a map of role => color.
  """
  def get_all_ui_colors(theme) do
    (theme.ui_mappings || %{})
    |> Enum.map(fn {role, color_name} ->
      color_atom =
        if is_atom(color_name), do: color_name, else: String.to_atom(color_name)

      {role, get_color_from_theme(theme, color_atom)}
    end)
    |> Enum.into(%{})
  end

  defp get_color_from_theme(theme, color_name, variant \\ :base) do
    val =
      Map.get(theme.variants || %{}, {color_name, variant}) ||
        Map.get(theme.colors, color_name)

    case val do
      %Color{} = c -> c
      hex when is_binary(hex) -> Color.from_hex(hex)
      _ -> nil
    end
  end

  # --- Color manipulation functions (stubs/implementations) ---
  def lighten_color(%Color{} = color, amount) do
    Color.lighten(color, amount)
  end

  def darken_color(%Color{} = color, amount) do
    Color.darken(color, amount)
  end

  def increase_contrast(%Color{} = color) do
    Utilities.increase_contrast(color)
  end

  def adjust_for_contrast(%Color{} = color, %Color{} = background, level, size) do
    Utilities.adjust_for_contrast(color, background, level, size)
  end

  def meets_contrast_requirements?(%Color{} = fg, %Color{} = bg, level, size) do
    Utilities.meets_contrast_requirements?(fg, bg, level, size)
  end

  # --- Theme creation stubs ---
  def create_dark_theme do
    %Theme{
      name: "dark",
      colors: %{
        primary: Color.from_hex("#90CAF9"),
        secondary: Color.from_hex("#B0BEC5"),
        background: Color.from_hex("#121212"),
        text: Color.from_hex("#FFFFFF")
      },
      ui_mappings: %{
        app_background: :background,
        surface_background: :background,
        primary_button: :primary,
        secondary_button: :secondary,
        text: :text
      },
      metadata: %{dark_mode: true}
    }
  end

  def create_high_contrast_theme do
    %Theme{
      name: "high_contrast",
      colors: %{
        primary: Color.from_hex("#FFFF00"),
        secondary: Color.from_hex("#000000"),
        background: Color.from_hex("#000000"),
        text: Color.from_hex("#FFFFFF")
      },
      ui_mappings: %{
        app_background: :background,
        surface_background: :background,
        primary_button: :primary,
        secondary_button: :secondary,
        text: :text
      },
      metadata: %{high_contrast: true}
    }
  end
end
