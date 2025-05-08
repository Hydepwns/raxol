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

  # Cache for capabilities to avoid repeated detection
  @capabilities_cache_name :raxol_terminal_capabilities

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
  Initializes the terminal capabilities cache.

  This should be called once, usually during application startup.
  It creates the ETS table used for caching detected capabilities.
  """
  def init do
    # Create the ETS table if it doesn't already exist
    if :ets.info(@capabilities_cache_name) == :undefined do
      :ets.new(@capabilities_cache_name, [
        :set,
        :public,
        :named_table,
        read_concurrency: true
      ])
    end

    :ok
  end

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
    # Ensure cache is initialized
    init()

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

      # Add a catch-all clause to handle unexpected values or return the original color
      # This specifically addresses the :truecolor atom potentially causing CaseClauseError
      # if detect_color_support somehow returns it directly instead of the logic above.
      # Although, the main issue is likely in the caller handling the :true_color Color struct.
      # For now, just ensure this case doesn't crash.
      other ->
        # Return original color if support level is unknown/unexpected
        color
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
    adapted_colors =
      Map.new(palette.colors, fn {key, color} ->
        {key, adapt_color(color)}
      end)

    # Create a new palette with adapted colors
    %Palette{
      palette
      | name: "#{palette.name} (Adapted)",
        colors: adapted_colors
    }
  end

  @doc """
  Adapts a theme to the current terminal capabilities and background.

  ## Parameters

  - `theme` - The theme to adapt

  ## Examples

      iex> theme = Raxol.Style.Colors.Theme.from_palette(Raxol.Style.Colors.Palette.nord())
      iex> adapted = Raxol.Style.Colors.Adaptive.adapt_theme(theme)
      iex> adapted.name
      "Nord (Adapted)"  # Adapted to terminal capabilities
  """
  def adapt_theme(%Theme{} = theme) do
    # Create a temporary Palette struct from the theme's palette map
    # Use the theme's name for the temporary palette
    temp_palette_struct = %Palette{name: theme.name, colors: theme.palette}

    # Adapt the palette based on color support
    adapted_palette_struct = adapt_palette(temp_palette_struct)

    # Return a new theme with the adapted palette map and name
    %Theme{
      theme
      | name: adapted_palette_struct.name,
        palette: adapted_palette_struct.colors
        # Keep original dark_mode, ui_mappings etc.
    }
  end

  @doc """
  Gets the optimal color format for the current terminal.

  Returns one of:
  - `:true_color` - 24-bit color (16 million colors)
  - `:ansi_256` - 256 colors
  - `:ansi_16` - 16 colors
  - `:no_color` - No color support

  ## Examples

      iex> Raxol.Style.Colors.Adaptive.optimal_format()
      :true_color  # Depends on your terminal
  """
  def optimal_format do
    detect_color_support()
  end

  @doc """
  Resets the cached terminal capabilities.

  This forces the next call to detection functions to re-evaluate
  the terminal environment.
  """
  def reset_detection do
    # Only delete if the table exists
    if :ets.info(@capabilities_cache_name) != :undefined do
      :ets.delete(@capabilities_cache_name)
    end

    # Re-create the table after deleting it (or ensure it exists)
    init()
    :ok
  end

  @doc """
  Gets the optimal color format for the current terminal.

  Returns one of:
  - `:true_color` - 24-bit color (16 million colors)
  - `:ansi_256` - 256 colors
  - `:ansi_16`

  ## Examples

      iex> Raxol.Style.Colors.Adaptive.get_optimal_format()
      :true_color  # Depends on your terminal
  """
  def get_optimal_format do
    detect_color_support()
  end

  # Private Helpers

  defp detect_color_support_impl do
    cond do
      # Highest priority: NO_COLOR environment variable or TERM=dumb
      System.get_env("NO_COLOR") != nil or System.get_env("TERM") == "dumb" ->
        :no_color

      # Check COLORTERM explicitly first
      System.get_env("COLORTERM") in ["truecolor", "24bit"] ->
        :true_color

      # Check other indicators
      check_if_other_true_color_indicators() ->
        :true_color

      check_if_256_colors_supported() ->
        :ansi_256

      check_if_16_colors_supported() ->
        :ansi_16

      # Default: Assume no color support if none of the above match
      true ->
        :no_color
    end
  end

  defp check_if_other_true_color_indicators() do
    # Check TERM_PROGRAM first, as it's often more specific
    term_program = System.get_env("TERM_PROGRAM")
    # Add other known truecolor programs
    term_program_check =
      term_program in ["iTerm.app", "vscode", "Apple_Terminal", "WezTerm"]

    # Then check TERM if TERM_PROGRAM didn't match
    term = System.get_env("TERM")
    # Add other known truecolor TERM values
    term_check = term in ["xterm-truecolor", "iterm", "kitty"]

    term_program_check or term_check
    # Consider checking for VTE_VERSION or similar environment variables
    # || (System.get_env("VTE_VERSION") != nil && ...)
  end

  defp check_if_256_colors_supported() do
    term = System.get_env("TERM")
    # Check TERM against known 256-color terminals
    # Check tput colors (more reliable but requires tput)
    # This is a simplification; real tput check is more involved
    # check_tput_colors(256)
    # Heuristic: Check if TERM string contains "256"
    term in @ansi_256_terminals or
      (term != nil && String.contains?(term, "256"))
  end

  defp check_if_16_colors_supported() do
    term = System.get_env("TERM")
    # Check TERM against known 16-color terminals
    # or check_tput_colors(16) ...
    term in @ansi_16_terminals
    # Many terminals support at least 16 colors by default
  end

  defp detect_terminal_background_impl do
    # Simple check based on COLORFGBG (common in rxvt and derivatives)
    case System.get_env("COLORFGBG") do
      # Format is usually "fg;bg" or "fg;bg;attrs"
      fgbg when is_binary(fgbg) ->
        case String.split(fgbg, ";") do
          # Check background part (second element)
          [_fg, bg | _] ->
            case Integer.parse(bg) do
              # 0-7 are typically dark colors in standard ANSI palette
              {val, ""} when val >= 0 and val <= 7 -> :dark
              # 8-15 are typically light colors
              {val, ""} when val >= 8 and val <= 15 -> :light
              # Cannot parse or out of range
              _ -> :unknown
            end

          # Unexpected format
          _ ->
            :unknown
        end

      nil ->
        # Add other detection methods here if needed (e.g., OSC 11 query, specific terminal env vars)
        # Default if no information found
        :unknown
    end
  end

  defp get_cached_capability(key) do
    # Implementation depends on how you store the cache (ETS assumed)
    case :ets.lookup(@capabilities_cache_name, key) do
      [{^key, value}] -> value
      # Not found
      [] -> nil
    end
  end

  defp cache_capability(key, value) do
    # Implementation depends on how you store the cache (ETS assumed)
    :ets.insert(@capabilities_cache_name, {key, value})
  end
end
