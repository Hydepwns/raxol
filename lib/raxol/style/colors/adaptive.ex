defmodule Raxol.Style.Colors.Adaptive do
  @moduledoc """
  Detects terminal capabilities and adapts color schemes accordingly.
  
  This module provides functionality to detect what color capabilities are
  supported by the current terminal and adapt colors and themes to work
  optimally with the detected capabilities.
  
  ## Examples
  
  ```elixir
  # Check if the terminal supports true color
  if Raxol.Style.Colors.Adaptive.supports_true_color?() do
    # Use true color features
  else
    # Fall back to 256 colors or 16 colors
  end
  
  # Adapt a color to the current terminal capabilities
  color = Raxol.Style.Colors.Color.from_hex("#FF5500")
  adapted_color = Raxol.Style.Colors.Adaptive.adapt_color(color)
  
  # Check if we're in a dark terminal
  if Raxol.Style.Colors.Adaptive.is_dark_terminal?() do
    # Use light text on dark background
  else
    # Use dark text on light background
  end
  ```
  """
  
  alias Raxol.Style.Colors.{Color, Palette, Theme, Utilities}
  
  # Environment variables to check for color support
  @colorterm_vars ["COLORTERM"]
  @term_vars ["TERM", "TERM_PROGRAM", "TERM_PROGRAM_VERSION"]
  
  # Cache for capabilities to avoid repeated detection
  @capabilities_cache_name :raxol_terminal_capabilities
  
  # Known terminals with true color support
  @true_color_terminals [
    "xterm-kitty",
    "wezterm",
    "alacritty",
    "iterm2",
    "konsole",
    "gnome-terminal",
    "vte",
    "foot",
    "st",
    "terminator",
    "xterm-256color",
    "rxvt-unicode-256color"
  ]
  
  # Known terminals with 256 color support
  @ansi_256_terminals [
    "xterm-256color",
    "rxvt-256color",
    "screen-256color",
    "tmux-256color",
    "putty-256color"
  ]
  
  # Known terminals with basic color support
  @ansi_16_terminals [
    "xterm",
    "rxvt",
    "screen",
    "tmux",
    "putty",
    "linux",
    "cygwin"
  ]
  
  @doc """
  Detects the color support level of the current terminal.
  
  Returns one of:
  - `:true_color` - 24-bit color (16 million colors)
  - `:ansi_256` - 256 colors
  - `:ansi_16` - 16 colors
  - `:no_color` - No color support
  
  ## Examples
  
      iex> Raxol.Style.Colors.Adaptive.detect_color_support()
      :true_color  # Depends on your terminal
  """
  def detect_color_support do
    # Check if we have a cached result
    case get_cached_capability(:color_support) do
      nil ->
        # No cached result, detect color support
        support = detect_color_support_impl()
        cache_capability(:color_support, support)
        support
      support ->
        support
    end
  end
  
  @doc """
  Checks if the terminal supports true color (24-bit color).
  
  ## Examples
  
      iex> Raxol.Style.Colors.Adaptive.supports_true_color?()
      true  # Depends on your terminal
  """
  def supports_true_color? do
    detect_color_support() == :true_color
  end
  
  @doc """
  Checks if the terminal supports 256 colors.
  
  ## Examples
  
      iex> Raxol.Style.Colors.Adaptive.supports_256_colors?()
      true  # Depends on your terminal
  """
  def supports_256_colors? do
    support = detect_color_support()
    support == :true_color or support == :ansi_256
  end
  
  @doc """
  Detects the terminal background color (light or dark).
  
  Returns one of:
  - `:dark` - Dark background
  - `:light` - Light background
  - `:unknown` - Unable to determine
  
  ## Examples
  
      iex> Raxol.Style.Colors.Adaptive.terminal_background()
      :dark  # Depends on your terminal
  """
  def terminal_background do
    # Check if we have a cached result
    case get_cached_capability(:background) do
      nil ->
        # No cached result, detect background
        background = detect_terminal_background_impl()
        cache_capability(:background, background)
        background
      background ->
        background
    end
  end
  
  @doc """
  Checks if the terminal has a dark background.
  
  ## Examples
  
      iex> Raxol.Style.Colors.Adaptive.is_dark_terminal?()
      true  # Depends on your terminal
  """
  def is_dark_terminal? do
    terminal_background() == :dark
  end
  
  @doc """
  Adapts a color to the current terminal capabilities.
  
  If the terminal does not support the full color range, this will
  convert the color to the best available representation.
  
  ## Parameters
  
  - `color` - The color to adapt
  
  ## Examples
  
      iex> color = Raxol.Style.Colors.Color.from_hex("#FF5500")
      iex> adapted = Raxol.Style.Colors.Adaptive.adapt_color(color)
      iex> adapted.hex
      "#FF5500"  # If terminal supports true color, otherwise closest supported color
  """
  def adapt_color(%Color{} = color) do
    case detect_color_support() do
      :true_color ->
        # Terminal supports true color, no need to adapt
        color
      :ansi_256 ->
        # Convert to the closest ANSI 256 color
        ansi_code = Color.to_ansi_256(color)
        Color.from_ansi(ansi_code)
      :ansi_16 ->
        # Convert to the closest ANSI 16 color
        ansi_code = Color.to_ansi_16(color)
        Color.from_ansi(ansi_code)
      :no_color ->
        # No color support, return greyscale value using luminance
        luminance = Utilities.luminance(color)
        grey_value = round(luminance * 255)
        Color.from_rgb(grey_value, grey_value, grey_value)
    end
  end
  
  @doc """
  Adapts a palette to the current terminal capabilities.
  
  ## Parameters
  
  - `palette` - The palette to adapt
  
  ## Examples
  
      iex> palette = Raxol.Style.Colors.Palette.nord()
      iex> adapted = Raxol.Style.Colors.Adaptive.adapt_palette(palette)
      iex> adapted.name
      "Nord (Adapted)"  # Adapted to terminal capabilities
  """
  def adapt_palette(%Palette{} = palette) do
    # Adapt each color in the palette
    adapted_colors = Map.new(palette.colors, fn {key, color} ->
      {key, adapt_color(color)}
    end)
    
    # Create a new palette with adapted colors
    %Palette{
      palette |
      name: "#{palette.name} (Adapted)",
      colors: adapted_colors
    }
  end
  
  @doc """
  Adapts a theme to the current terminal capabilities.
  
  ## Parameters
  
  - `theme` - The theme to adapt
  
  ## Examples
  
      iex> theme = Raxol.Style.Colors.Theme.from_palette(Raxol.Style.Colors.Palette.nord())
      iex> adapted = Raxol.Style.Colors.Adaptive.adapt_theme(theme)
      iex> adapted.name
      "Nord (Adapted)"  # Adapted to terminal capabilities
  """
  def adapt_theme(%Theme{} = theme) do
    # Adapt the palette
    adapted_palette = adapt_palette(theme.palette)
    
    # Check if we should switch to a dark or light variant
    current_is_dark = theme.dark_mode
    terminal_is_dark = is_dark_terminal?()
    
    adapted_theme = %Theme{
      theme |
      name: "#{theme.name} (Adapted)",
      palette: adapted_palette
    }
    
    # If the terminal background conflicts with the theme, switch the theme variant
    cond do
      current_is_dark && not terminal_is_dark ->
        # Current theme is dark but terminal is light, switch to light variant
        Theme.light_variant(adapted_theme)
      not current_is_dark && terminal_is_dark ->
        # Current theme is light but terminal is dark, switch to dark variant
        Theme.dark_variant(adapted_theme)
      true ->
        # Theme matches terminal, no need to switch
        adapted_theme
    end
  end
  
  @doc """
  Gets the optimal color format for the current terminal.
  
  Returns one of:
  - `:true_color` - Use 24-bit color format
  - `:ansi_256` - Use 256-color format
  - `:ansi_16` - Use 16-color format
  - `:no_color` - No colors (monochrome)
  
  ## Examples
  
      iex> Raxol.Style.Colors.Adaptive.get_optimal_format()
      :true_color  # Depends on your terminal
  """
  def get_optimal_format do
    detect_color_support()
  end
  
  @doc """
  Initialize the terminal capabilities cache.
  This should be called when the application starts.
  """
  def init do
    # Create or reset the ETS table for terminal capabilities
    if :ets.whereis(@capabilities_cache_name) != :undefined do
      :ets.delete(@capabilities_cache_name)
    end
    
    :ets.new(@capabilities_cache_name, [:named_table, :set, :public])
    :ok
  end
  
  @doc """
  Forces a re-detection of terminal capabilities by clearing the cache.
  
  ## Examples
  
      iex> Raxol.Style.Colors.Adaptive.reset_detection()
      :ok
  """
  def reset_detection do
    if :ets.whereis(@capabilities_cache_name) != :undefined do
      :ets.delete_all_objects(@capabilities_cache_name)
    else
      init()
    end
    
    :ok
  end
  
  # Private implementation
  
  # Implementation of the color support detection
  defp detect_color_support_impl do
    # Check for NO_COLOR environment variable (https://no-color.org/)
    if System.get_env("NO_COLOR") do
      :no_color
    else
      # Check for true color support
      colorterm = get_env_value(@colorterm_vars)
      term = get_env_value(@term_vars)
      term_program = System.get_env("TERM_PROGRAM")
      term_program_version = System.get_env("TERM_PROGRAM_VERSION")
      
      cond do
        # Check for explicit true color support
        colorterm in ["truecolor", "24bit"] ->
          :true_color
          
        # Check for terminals known to support true color
        term in @true_color_terminals ->
          :true_color
          
        # Check for specific terminal programs with true color support
        term_program in ["iTerm.app", "WezTerm", "vscode"] ->
          :true_color
          
        # Check for terminals that might support true color
        String.contains?(to_string(term || ""), "256color") ->
          check_if_true_color_supported(term, term_program, term_program_version) || :ansi_256
          
        # Check for basic color support
        term in @ansi_16_terminals or String.contains?(to_string(term || ""), "color") ->
          :ansi_16
          
        # Default to no color
        true ->
          :no_color
      end
    end
  end
  
  # More specific checks for true color support
  defp check_if_true_color_supported(term, term_program, term_program_version) do
    cond do
      # Check for specific terminal that we know supports true color
      term in ["xterm-256color"] and term_program in ["iTerm.app", "WezTerm", "vscode"] ->
        :true_color
        
      # Check for specific version requirements
      term_program == "iTerm.app" and term_program_version != nil ->
        # iTerm2 3.0+ supports true color
        case Version.parse(term_program_version) do
          {:ok, version} -> version.major >= 3
          _ -> false
        end
        
      # Check for specific terminal capabilities
      term in ["xterm-256color"] and System.get_env("COLORTERM") == "truecolor" ->
        :true_color
        
      true ->
        nil
    end
  end
  
  # Check if an environment variable is set to a specific value
  defp is_env_set(var, values) do
    env_value = System.get_env(var)
    env_value != nil and env_value in values
  end
  
  # Get the first non-nil environment variable from a list
  defp get_env_value(vars) do
    Enum.find_value(vars, fn var -> System.get_env(var) end)
  end
  
  # Implementation of terminal background detection
  defp detect_terminal_background_impl do
    # Try to detect background color from environment
    case System.get_env("COLORFGBG") do
      nil ->
        # Try to detect from terminal capabilities
        case detect_color_support() do
          :no_color -> :unknown
          _ -> detect_background_from_capabilities()
        end
      colorfgbg ->
        # Parse COLORFGBG value (format: "15;0" where 15 is foreground and 0 is background)
        case String.split(colorfgbg, ";") do
          [_, bg] when bg in ["0", "8"] -> :dark
          [_, bg] when bg in ["7", "15"] -> :light
          _ -> :unknown
        end
    end
  end
  
  defp detect_background_from_capabilities do
    # Create test colors
    black = Color.from_hex("#000000")
    white = Color.from_hex("#FFFFFF")
    
    # Try to detect by testing contrast with black and white
    case {adapt_color(black), adapt_color(white)} do
      {%Color{} = adapted_black, %Color{} = adapted_white} ->
        # If adapted colors are different, terminal is likely dark
        if Utilities.contrast_ratio(adapted_black, adapted_white) > 10 do
          :dark
        else
          :light
        end
      _ ->
        :unknown
    end
  end
  
  # Cache a capability value
  defp cache_capability(key, value) do
    if :ets.whereis(@capabilities_cache_name) == :undefined do
      init()
    end
    
    :ets.insert(@capabilities_cache_name, {key, value})
  end
  
  # Get a cached capability value
  defp get_cached_capability(key) do
    if :ets.whereis(@capabilities_cache_name) == :undefined do
      init()
      nil
    else
      case :ets.lookup(@capabilities_cache_name, key) do
        [{^key, value}] -> value
        [] -> nil
      end
    end
  end
end 