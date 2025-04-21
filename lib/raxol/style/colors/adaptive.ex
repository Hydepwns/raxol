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

    # Determine the target dark_mode based on terminal background
    target_dark_mode =
      case terminal_background() do
        :dark -> true
        :light -> false
        # Keep original if unknown
        :unknown -> theme.dark_mode
      end

    # Create a new theme with adapted palette and potentially flipped dark_mode
    %Theme{
      theme
      | name: "#{theme.name} (Adapted)",
        palette: adapted_palette,
        dark_mode: target_dark_mode
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
  - `:ansi_16` - 16 colors
  - `:no_color` - No color support

  This is currently an alias for `detect_color_support/0`.
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

      # Then check TERM for 256 colors
      check_if_256_colors_supported() ->
        :ansi_256

      # Then check TERM for 16 colors
      check_if_16_colors_supported() ->
        :ansi_16

      # Finally, check other indicators for true color (TERM_PROGRAM, etc.)
      # This acts as a fallback if COLORTERM wasn't set but other hints exist.
      check_if_other_true_color_indicators() ->
        :true_color

      # Default: Assume no color support if none of the above match
      true ->
        :no_color
    end
  end

  # Renamed from check_if_true_color_supported
  defp check_if_other_true_color_indicators do
    # Check TERM_PROGRAM (e.g., iTerm.app, vscode)
    case System.get_env("TERM_PROGRAM") do
      "iTerm.app" ->
        # Check version for older iTerm that might not support truecolor reliably
        case System.get_env("TERM_PROGRAM_VERSION") do
          version when is_binary(version) ->
            compare_versions(version, "3.0.0") != :lt

          # Assume truecolor if version is missing
          _ ->
            true
        end

      "vscode" ->
        true

      # macOS Terminal.app supports truecolor
      "Apple_Terminal" ->
        true

      # Add other known truecolor TERM_PROGRAM values here
      _ ->
        # Fallback: Check specific TERM values known for truecolor
        case System.get_env("TERM") do
          "xterm-kitty" -> true
          # Add other known truecolor TERM values here
          _ -> false
        end
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

  defp compare_versions(v1, v2) do
    v1_parts = String.split(v1, ".") |> Enum.map(&String.to_integer/1)
    v2_parts = String.split(v2, ".") |> Enum.map(&String.to_integer/1)

    # Simple lexicographical comparison for this example
    cond do
      v1_parts > v2_parts -> :gt
      v1_parts < v2_parts -> :lt
      true -> :eq
    end
  rescue
    # Treat parse errors as equal (or handle more robustly)
    _ -> :eq
  end
end
