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

    # Create a new theme with adapted palette
    %Theme{
      theme
      | name: "#{theme.name} (Adapted)",
        palette: adapted_palette
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

  # Private Helpers

  defp detect_color_support_impl do
    cond do
      # Check for true color support
      check_if_true_color_supported() ->
        :true_color

      # Check for 256 color support
      check_if_256_colors_supported() ->
        :ansi_256

      # Check for basic color support
      check_if_16_colors_supported() ->
        :ansi_16

      # No color support
      true ->
        :no_color
    end
  end

  defp check_if_true_color_supported do
    # Check COLORTERM environment variable
    case System.get_env("COLORTERM") do
      "truecolor" -> true
      "24bit" -> true
      _ -> false
    end
  end

  defp check_if_256_colors_supported do
    # Check TERM environment variable
    case System.get_env("TERM") do
      term when term in @ansi_256_terminals -> true
      _ -> false
    end
  end

  defp check_if_16_colors_supported do
    # Check TERM environment variable
    case System.get_env("TERM") do
      term when term in @ansi_16_terminals -> true
      _ -> false
    end
  end

  defp detect_terminal_background_impl do
    # Try to detect background color using ANSI escape sequences
    case System.get_env("COLORFGBG") do
      nil ->
        :unknown

      value ->
        case String.split(value, ";") do
          [_, bg] when bg in ["0", "1", "2", "3", "4", "5", "6", "7"] ->
            :dark

          [_, bg] when bg in ["8", "9", "10", "11", "12", "13", "14", "15"] ->
            :light

          _ ->
            :unknown
        end
    end
  end

  defp get_cached_capability(key) do
    case :ets.lookup(@capabilities_cache_name, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  defp cache_capability(key, value) do
    :ets.insert(@capabilities_cache_name, {key, value})
  end
end
