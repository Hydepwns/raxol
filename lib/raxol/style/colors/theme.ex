defmodule Raxol.Style.Colors.Theme do
  @moduledoc """
  Manages complete color themes with support for hot-swapping.
  
  A theme in Raxol consists of a palette and a set of UI element mappings
  that define how colors are applied to different parts of the UI.
  Themes can be switched at runtime, allowing for easy customization.
  
  ## Examples
  
  ```elixir
  # Get the current theme
  current = Raxol.Style.Colors.Theme.current_theme()
  
  # Create a theme from a palette
  palette = Raxol.Style.Colors.Palette.nord()
  theme = Raxol.Style.Colors.Theme.from_palette(palette, "My Nord Theme")
  
  # Switch to a different theme
  Raxol.Style.Colors.Theme.apply_theme(theme)
  
  # Create and switch to a dark variant
  dark_theme = Raxol.Style.Colors.Theme.dark_variant(theme)
  Raxol.Style.Colors.Theme.apply_theme(dark_theme)
  
  # Save a theme for later use
  Raxol.Style.Colors.Theme.save_theme(theme, "my_theme.json")
  saved_theme = Raxol.Style.Colors.Theme.load_theme("my_theme.json")
  ```
  """
  
  alias Raxol.Style.Colors.{Color, Palette}
  
  defstruct [
    :name,
    :palette,
    :ui_mappings,     # Map of UI element names to colors
    :dark_mode,       # Boolean indicating dark/light theme
    :high_contrast    # Boolean for high contrast mode
  ]
  
  @type ui_element :: atom()
  @type color_ref :: atom()
  
  @type t :: %__MODULE__{
    name: String.t(),
    palette: Palette.t(),
    ui_mappings: %{optional(ui_element()) => color_ref()},
    dark_mode: boolean(),
    high_contrast: boolean()
  }
  
  # Default themes registry (in-memory storage)
  @themes_registry_name :raxol_themes_registry
  
  # Default UI elements that should be defined in any theme
  @default_ui_elements [
    :app_background,
    :app_foreground,
    :panel_background,
    :panel_foreground,
    :panel_border,
    :header_background,
    :header_foreground,
    :footer_background,
    :footer_foreground,
    :selection_background,
    :selection_foreground,
    :primary_button_background,
    :primary_button_foreground,
    :secondary_button_background,
    :secondary_button_foreground,
    :input_background,
    :input_foreground,
    :input_border,
    :error,
    :warning,
    :success,
    :info,
    :link
  ]
  
  @doc """
  Initializes the themes registry and loads the default theme.
  This should be called when the application starts.
  """
  def init do
    # Create or reset the ETS table for themes
    if :ets.whereis(@themes_registry_name) != :undefined do
      :ets.delete(@themes_registry_name)
    end
    
    :ets.new(@themes_registry_name, [:named_table, :set, :public])
    
    # Register standard themes
    register_standard_themes()
    
    # Set default theme
    default_theme = standard_theme()
    set_current_theme(default_theme)
    
    :ok
  end
  
  @doc """
  Registers all standard themes in the registry.
  """
  def register_standard_themes do
    # Create and register standard themes from all available palettes
    [
      standard_theme(),
      from_palette(Palette.solarized(), "Solarized"),
      from_palette(Palette.nord(), "Nord"),
      from_palette(Palette.dracula(), "Dracula")
    ]
    |> Enum.each(&register_theme/1)
  end
  
  @doc """
  Returns the standard default theme using the ANSI 16 palette.
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.standard_theme()
      iex> theme.name
      "Standard"
  """
  def standard_theme do
    palette = Palette.standard_16()
    
    ui_mappings = %{
      app_background: :black,
      app_foreground: :white,
      panel_background: :bright_black,
      panel_foreground: :bright_white,
      panel_border: :blue,
      header_background: :blue,
      header_foreground: :white,
      footer_background: :bright_black,
      footer_foreground: :white,
      selection_background: :blue,
      selection_foreground: :white,
      primary_button_background: :blue,
      primary_button_foreground: :white,
      secondary_button_background: :bright_black,
      secondary_button_foreground: :white,
      input_background: :black,
      input_foreground: :white,
      input_border: :blue,
      error: :red,
      warning: :yellow,
      success: :green,
      info: :cyan,
      link: :bright_blue
    }
    
    %__MODULE__{
      name: "Standard",
      palette: palette,
      ui_mappings: ui_mappings,
      dark_mode: true,
      high_contrast: false
    }
  end
  
  @doc """
  Creates a theme from a palette with auto-generated UI mappings.
  
  ## Parameters
  
  - `palette` - The color palette to use for the theme
  - `name` - The name of the theme (defaults to the palette name)
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.nord()
      iex> theme = Raxol.Style.Colors.Theme.from_palette(palette)
      iex> theme.name
      "Nord"
  """
  def from_palette(%Palette{} = palette, name \\ nil) do
    theme_name = name || palette.name
    
    # Determine if this is a dark mode theme based on the background color
    background_color = Palette.get_color(palette, palette.background)
    is_dark = is_dark_color?(background_color)
    
    # Generate UI mappings based on the palette's colors
    ui_mappings = generate_ui_mappings_from_palette(palette)
    
    %__MODULE__{
      name: theme_name,
      palette: palette,
      ui_mappings: ui_mappings,
      dark_mode: is_dark,
      high_contrast: false
    }
  end
  
  @doc """
  Applies a theme to the application, making it the current theme.
  
  ## Parameters
  
  - `theme` - The theme to apply
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.from_palette(Raxol.Style.Colors.Palette.nord())
      iex> Raxol.Style.Colors.Theme.apply_theme(theme)
      :ok
  """
  def apply_theme(%__MODULE__{} = theme) do
    # Register the theme if it's not already registered
    if get_theme(theme.name) == nil do
      register_theme(theme)
    end
    
    # Set as current theme
    set_current_theme(theme)
    
    # Trigger a theme change event (this would be implemented in a real event system)
    # For now, we'll just return :ok
    :ok
  end
  
  @doc """
  Switches to a registered theme by name.
  
  ## Parameters
  
  - `theme_name` - The name of the theme to switch to
  
  ## Examples
  
      iex> Raxol.Style.Colors.Theme.switch_theme("Nord")
      :ok
  """
  def switch_theme(theme_name) when is_binary(theme_name) do
    case get_theme(theme_name) do
      nil -> {:error, :theme_not_found}
      theme -> apply_theme(theme)
    end
  end
  
  @doc """
  Registers a theme in the themes registry.
  
  ## Parameters
  
  - `theme` - The theme to register
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.from_palette(Raxol.Style.Colors.Palette.nord())
      iex> Raxol.Style.Colors.Theme.register_theme(theme)
      :ok
  """
  def register_theme(%__MODULE__{name: name} = theme) do
    # Validate required UI elements
    case validate_required_elements(theme) do
      :ok ->
        Registry.register(@themes_registry_name, name, theme)
        :ok
      {:error, missing} ->
        {:error, "Theme missing required elements: #{Enum.join(missing, ", ")}"}
    end
  end
  
  defp validate_required_elements(theme) do
    missing = Enum.filter(@default_ui_elements, fn element ->
      not Map.has_key?(theme.colors, element)
    end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, missing}
    end
  end
  
  @doc """
  Gets a theme from the registry by name.
  
  ## Parameters
  
  - `theme_name` - The name of the theme to get
  
  ## Examples
  
      iex> Raxol.Style.Colors.Theme.register_theme(Raxol.Style.Colors.Theme.standard_theme())
      iex> theme = Raxol.Style.Colors.Theme.get_theme("Standard")
      iex> theme.name
      "Standard"
  """
  def get_theme(theme_name) when is_binary(theme_name) do
    case :ets.lookup(@themes_registry_name, theme_name) do
      [{^theme_name, theme}] -> theme
      [] -> nil
    end
  end
  
  @doc """
  Returns the currently active theme.
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.current_theme()
      iex> is_map(theme)
      true
  """
  def current_theme do
    case :ets.lookup(@themes_registry_name, :current) do
      [{:current, theme}] -> theme
      [] -> standard_theme()
    end
  end
  
  @doc """
  Creates a light variant of a theme.
  
  ## Parameters
  
  - `theme` - The theme to create a light variant from
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.standard_theme()
      iex> light = Raxol.Style.Colors.Theme.light_variant(theme)
      iex> light.dark_mode
      false
  """
  def light_variant(%__MODULE__{dark_mode: true} = theme) do
    # Create a light variant of the palette
    light_palette = create_light_palette_variant(theme.palette)
    
    # Create new UI mappings for the light palette
    ui_mappings = generate_ui_mappings_from_palette(light_palette)
    
    %__MODULE__{
      name: "#{theme.name} Light",
      palette: light_palette,
      ui_mappings: ui_mappings,
      dark_mode: false,
      high_contrast: theme.high_contrast
    }
  end
  
  def light_variant(%__MODULE__{dark_mode: false} = theme) do
    # Already a light theme, return as is
    theme
  end
  
  @doc """
  Creates a dark variant of a theme.
  
  ## Parameters
  
  - `theme` - The theme to create a dark variant from
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.from_palette(Raxol.Style.Colors.Palette.solarized())
      iex> dark = Raxol.Style.Colors.Theme.dark_variant(theme)
      iex> dark.dark_mode
      true
  """
  def dark_variant(%__MODULE__{dark_mode: false} = theme) do
    # Create a dark variant of the palette
    dark_palette = create_dark_palette_variant(theme.palette)
    
    # Create new UI mappings for the dark palette
    ui_mappings = generate_ui_mappings_from_palette(dark_palette)
    
    %__MODULE__{
      name: "#{theme.name} Dark",
      palette: dark_palette,
      ui_mappings: ui_mappings,
      dark_mode: true,
      high_contrast: theme.high_contrast
    }
  end
  
  def dark_variant(%__MODULE__{dark_mode: true} = theme) do
    # Already a dark theme, return as is
    theme
  end
  
  @doc """
  Creates a high contrast variant of a theme.
  
  ## Parameters
  
  - `theme` - The theme to create a high contrast variant from
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.standard_theme()
      iex> high_contrast = Raxol.Style.Colors.Theme.high_contrast_variant(theme)
      iex> high_contrast.high_contrast
      true
  """
  def high_contrast_variant(%__MODULE__{high_contrast: false} = theme) do
    # Create a high contrast variant of the palette
    high_contrast_palette = create_high_contrast_palette_variant(theme.palette)
    
    # Create new UI mappings with higher contrast
    ui_mappings = generate_high_contrast_ui_mappings(high_contrast_palette)
    
    %__MODULE__{
      name: "#{theme.name} High Contrast",
      palette: high_contrast_palette,
      ui_mappings: ui_mappings,
      dark_mode: theme.dark_mode,
      high_contrast: true
    }
  end
  
  def high_contrast_variant(%__MODULE__{high_contrast: true} = theme) do
    # Already a high contrast theme, return as is
    theme
  end
  
  @doc """
  Saves a theme to a JSON file.
  
  ## Parameters
  
  - `theme` - The theme to save
  - `path` - The file path to save to
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.standard_theme()
      iex> Raxol.Style.Colors.Theme.save_theme(theme, "standard_theme.json")
      :ok
  """
  def save_theme(%__MODULE__{} = theme, path) when is_binary(path) do
    # Convert theme to serializable format
    serialized = serialize_theme(theme)
    
    # Convert to JSON and write to file
    with {:ok, json} <- Jason.encode(serialized, pretty: true),
         :ok <- File.write(path, json) do
      :ok
    else
      error -> error
    end
  end
  
  @doc """
  Loads a theme from a JSON file.
  
  ## Parameters
  
  - `path` - The file path to load from
  
  ## Examples
  
      iex> Raxol.Style.Colors.Theme.save_theme(Raxol.Style.Colors.Theme.standard_theme(), "temp_theme.json")
      iex> {:ok, theme} = Raxol.Style.Colors.Theme.load_theme("temp_theme.json")
      iex> theme.name
      "Standard"
  """
  def load_theme(path) when is_binary(path) do
    with {:ok, json} <- File.read(path),
         {:ok, data} <- Jason.decode(json),
         {:ok, theme} <- deserialize_theme(data) do
      {:ok, theme}
    else
      error -> error
    end
  end
  
  @doc """
  Gets a resolved color for a UI element.
  
  ## Parameters
  
  - `theme` - The theme to get the color from
  - `ui_element` - The UI element to get the color for
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.standard_theme()
      iex> color = Raxol.Style.Colors.Theme.get_ui_color(theme, :error)
      iex> color.hex
      "#800000"
  """
  def get_ui_color(%__MODULE__{ui_mappings: ui_mappings, palette: palette}, ui_element) do
    case Map.get(ui_mappings, ui_element) do
      nil -> 
        # Return a default color if the UI element is not defined
        Palette.get_color(palette, palette.foreground)
      color_ref ->
        Palette.get_color(palette, color_ref)
    end
  end
  
  # Private functions
  
  # Sets the current theme in the registry
  defp set_current_theme(%__MODULE__{} = theme) do
    :ets.insert(@themes_registry_name, {:current, theme})
  end
  
  # Determines if a color is dark based on its luminance
  defp is_dark_color?(%Color{r: r, g: g, b: b}) do
    # Calculate relative luminance using the formula:
    # L = 0.2126 * R + 0.7152 * G + 0.0722 * B
    # where R, G, B are normalized to 0..1
    luminance = (0.2126 * r / 255) + (0.7152 * g / 255) + (0.0722 * b / 255)
    luminance < 0.5
  end
  
  # Generates UI mappings from a palette
  defp generate_ui_mappings_from_palette(%Palette{} = palette) do
    # This is a simplified implementation; in a real implementation,
    # this would consider the palette's color theory and generate
    # appropriate mappings for all UI elements
    
    is_dark = is_dark_color?(Palette.get_color(palette, palette.background))
    
    %{
      app_background: palette.background,
      app_foreground: palette.foreground,
      panel_background: get_lighter_or_darker(palette, palette.background, 0.2, is_dark),
      panel_foreground: palette.foreground,
      panel_border: palette.primary,
      header_background: palette.primary,
      header_foreground: get_contrasting_color(palette, palette.primary),
      footer_background: get_lighter_or_darker(palette, palette.background, 0.2, is_dark),
      footer_foreground: palette.foreground,
      selection_background: palette.primary,
      selection_foreground: get_contrasting_color(palette, palette.primary),
      primary_button_background: palette.primary,
      primary_button_foreground: get_contrasting_color(palette, palette.primary),
      secondary_button_background: palette.secondary,
      secondary_button_foreground: get_contrasting_color(palette, palette.secondary),
      input_background: get_lighter_or_darker(palette, palette.background, 0.1, is_dark),
      input_foreground: palette.foreground,
      input_border: palette.primary,
      error: find_color_in_palette(palette, [:red, :bright_red]),
      warning: find_color_in_palette(palette, [:yellow, :bright_yellow, :orange]),
      success: find_color_in_palette(palette, [:green, :bright_green]),
      info: find_color_in_palette(palette, [:blue, :bright_blue, :cyan, :bright_cyan]),
      link: find_color_in_palette(palette, [:blue, :bright_blue, :cyan])
    }
  end
  
  # Finds a color in the palette by trying multiple keys
  defp find_color_in_palette(%Palette{colors: colors} = palette, possible_keys) do
    Enum.find_value(possible_keys, palette.primary, fn key ->
      if Map.has_key?(colors, key), do: key, else: nil
    end)
  end
  
  # Gets a lighter or darker color reference from the palette
  defp get_lighter_or_darker(%Palette{colors: _colors} = palette, color_ref, amount, is_dark) do
    # Get the base color from the palette
    base_color = Palette.get_color(palette, color_ref)
    
    # Apply lightening or darkening based on is_dark flag
    if is_dark do
      Color.darken(base_color, amount)
    else
      Color.lighten(base_color, amount)
    end
  end
  
  # Finds the closest color in a palette to a given color
  defp find_closest_color_in_palette(%Palette{colors: colors}, %Color{} = target) do
    colors
    |> Enum.map(fn {key, color} -> {key, color_distance(color, target)} end)
    |> Enum.min_by(fn {_, distance} -> distance end, fn -> nil end)
    |> case do
      {key, _} -> key
      nil -> nil
    end
  end
  
  # Calculates distance between colors in RGB space
  defp color_distance(%Color{r: r1, g: g1, b: b1}, %Color{r: r2, g: g2, b: b2}) do
    :math.sqrt(:math.pow(r1 - r2, 2) + :math.pow(g1 - g2, 2) + :math.pow(b1 - b2, 2))
  end
  
  # Gets a contrasting color for text based on background
  defp get_contrasting_color(%Palette{} = palette, background_ref) do
    background = Palette.get_color(palette, background_ref)
    
    # Check if the background is dark, and return an appropriate foreground color
    if is_dark_color?(background) do
      find_color_in_palette(palette, [:white, :bright_white, palette.foreground])
    else
      find_color_in_palette(palette, [:black, :bright_black, palette.background])
    end
  end
  
  # Creates a light palette variant
  defp create_light_palette_variant(%Palette{} = palette) do
    # In a real implementation, this would create a proper light variant
    # For now, we'll just invert the background and foreground
    colors = palette.colors
    
    # Get current background and foreground
    bg = Palette.get_color(palette, palette.background)
    fg = Palette.get_color(palette, palette.foreground)
    
    # Create new background (lightened) and foreground (darkened)
    new_bg = Color.lighten(bg, 0.8)
    new_fg = Color.darken(fg, 0.8)
    
    # Find a light background and dark foreground in the palette or add them
    new_bg_key = find_closest_color_in_palette(palette, new_bg) || :light_background
    new_fg_key = find_closest_color_in_palette(palette, new_fg) || :dark_foreground
    
    colors = Map.put(colors, new_bg_key, new_bg)
    colors = Map.put(colors, new_fg_key, new_fg)
    
    %Palette{
      palette |
      name: "#{palette.name} Light",
      colors: colors,
      background: new_bg_key,
      foreground: new_fg_key
    }
  end
  
  # Creates a dark palette variant
  defp create_dark_palette_variant(%Palette{} = palette) do
    # In a real implementation, this would create a proper dark variant
    # For now, we'll just invert the background and foreground
    colors = palette.colors
    
    # Get current background and foreground
    bg = Palette.get_color(palette, palette.background)
    fg = Palette.get_color(palette, palette.foreground)
    
    # Create new background (darkened) and foreground (lightened)
    new_bg = Color.darken(bg, 0.8)
    new_fg = Color.lighten(fg, 0.8)
    
    # Find a dark background and light foreground in the palette or add them
    new_bg_key = find_closest_color_in_palette(palette, new_bg) || :dark_background
    new_fg_key = find_closest_color_in_palette(palette, new_fg) || :light_foreground
    
    colors = Map.put(colors, new_bg_key, new_bg)
    colors = Map.put(colors, new_fg_key, new_fg)
    
    %Palette{
      palette |
      name: "#{palette.name} Dark",
      colors: colors,
      background: new_bg_key,
      foreground: new_fg_key
    }
  end
  
  # Creates a high contrast palette variant
  defp create_high_contrast_palette_variant(%Palette{} = palette) do
    # In a real implementation, this would enhance contrast between colors
    # For now, just adjust the backgrounds and foregrounds
    colors = palette.colors
    
    # Get current background and foreground
    bg = Palette.get_color(palette, palette.background)
    fg = Palette.get_color(palette, palette.foreground)
    
    # Make background darker/lighter based on current theme
    new_bg = if is_dark_color?(bg), do: Color.darken(bg, 0.3), else: Color.lighten(bg, 0.3)
    # Make foreground more contrasting
    new_fg = if is_dark_color?(bg), do: Color.lighten(fg, 0.3), else: Color.darken(fg, 0.3)
    
    # Find or create keys for these colors
    new_bg_key = find_closest_color_in_palette(palette, new_bg) || :high_contrast_background
    new_fg_key = find_closest_color_in_palette(palette, new_fg) || :high_contrast_foreground
    
    colors = Map.put(colors, new_bg_key, new_bg)
    colors = Map.put(colors, new_fg_key, new_fg)
    
    %Palette{
      palette |
      name: "#{palette.name} High Contrast",
      colors: colors,
      background: new_bg_key,
      foreground: new_fg_key
    }
  end
  
  # Generates UI mappings optimized for high contrast
  defp generate_high_contrast_ui_mappings(%Palette{} = palette) do
    # Start with the standard mappings
    base_mappings = generate_ui_mappings_from_palette(palette)
    
    # Override with high contrast versions
    # This would be more sophisticated in a real implementation
    is_dark = is_dark_color?(Palette.get_color(palette, palette.background))
    
    # Get high contrast foreground color
    contrast_fg = if is_dark do
      find_color_in_palette(palette, [:white, :bright_white, palette.foreground])
    else
      find_color_in_palette(palette, [:black, :bright_black, palette.background])
    end
    
    # Enhanced colors for high contrast
    Map.merge(base_mappings, %{
      app_foreground: contrast_fg,
      panel_foreground: contrast_fg,
      header_foreground: contrast_fg,
      selection_foreground: contrast_fg,
      primary_button_foreground: contrast_fg,
      secondary_button_foreground: contrast_fg,
      input_foreground: contrast_fg
    })
  end
  
  # Serializes a theme to a format that can be converted to JSON
  defp serialize_theme(%__MODULE__{} = theme) do
    # Basic serialization - in a real implementation, this would be more robust
    %{
      "name" => theme.name,
      "dark_mode" => theme.dark_mode,
      "high_contrast" => theme.high_contrast,
      "palette" => %{
        "name" => theme.palette.name,
        "primary" => to_string(theme.palette.primary),
        "secondary" => to_string(theme.palette.secondary),
        "background" => to_string(theme.palette.background),
        "foreground" => to_string(theme.palette.foreground),
        "colors" => serialize_colors(theme.palette.colors)
      },
      "ui_mappings" => serialize_ui_mappings(theme.ui_mappings)
    }
  end
  
  # Serializes a map of colors to a JSON-compatible format
  defp serialize_colors(colors) do
    colors
    |> Enum.map(fn {key, color} -> 
      {to_string(key), %{
        "r" => color.r,
        "g" => color.g,
        "b" => color.b,
        "hex" => color.hex
      }}
    end)
    |> Map.new()
  end
  
  # Serializes UI mappings to a JSON-compatible format
  defp serialize_ui_mappings(ui_mappings) do
    ui_mappings
    |> Enum.map(fn {key, color_ref} -> {to_string(key), to_string(color_ref)} end)
    |> Map.new()
  end
  
  # Deserializes a theme from a JSON format
  defp deserialize_theme(data) do
    with {:ok, palette} <- deserialize_palette(data["palette"]),
         {:ok, ui_mappings} <- deserialize_ui_mappings(data["ui_mappings"]) do
      theme = %__MODULE__{
        name: data["name"],
        palette: palette,
        ui_mappings: ui_mappings,
        dark_mode: data["dark_mode"],
        high_contrast: data["high_contrast"]
      }
      
      {:ok, theme}
    else
      error -> error
    end
  end
  
  # Deserializes a palette from a JSON format
  defp deserialize_palette(data) do
    colors = deserialize_colors(data["colors"])
    
    palette = %Palette{
      name: data["name"],
      colors: colors,
      primary: String.to_atom(data["primary"]),
      secondary: String.to_atom(data["secondary"]),
      background: String.to_atom(data["background"]),
      foreground: String.to_atom(data["foreground"])
    }
    
    {:ok, palette}
  end
  
  # Deserializes a map of colors from a JSON format
  defp deserialize_colors(colors_data) do
    colors_data
    |> Enum.map(fn {key, color_data} ->
      color = Color.from_rgb(
        color_data["r"],
        color_data["g"],
        color_data["b"]
      )
      
      {String.to_atom(key), color}
    end)
    |> Map.new()
  end
  
  # Deserializes UI mappings from a JSON format
  defp deserialize_ui_mappings(ui_mappings_data) do
    ui_mappings = ui_mappings_data
    |> Enum.map(fn {key, color_ref} -> 
      {String.to_atom(key), String.to_atom(color_ref)}
    end)
    |> Map.new()
    
    {:ok, ui_mappings}
  end
end 