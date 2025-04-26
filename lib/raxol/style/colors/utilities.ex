defmodule Raxol.Style.Colors.Utilities do
  @moduledoc """
  Provides basic color utility functions.

  Includes checks for dark colors, brightness, luminance, and hex format.

  ## Examples

  ```elixir
  alias Raxol.Style.Colors.{Color, Utilities}

  # Check if a color is dark
  Utilities.dark_color?("#333333") # true

  # Get perceived brightness
  Utilities.brightness(Color.from_hex("#FF0000")) # 76

  # Check hex format
  Utilities.hex_color?("#ABC") # true
  Utilities.hex_color?("blue") # false
  """

  alias Raxol.Style.Colors.Color
  alias Raxol.Style.Colors.Accessibility

  @doc """
  Calculates the relative luminance of a color according to WCAG guidelines.

  ## Parameters

  - `color` - The color to calculate luminance for (hex string or Color struct)

  ## Returns

  - A float between 0 and 1 representing the relative luminance

  ## Examples

      iex> Raxol.Style.Colors.Utilities.relative_luminance("#000000")
      0.0

      iex> Raxol.Style.Colors.Utilities.relative_luminance("#FFFFFF")
      1.0
  """
  def relative_luminance(color) when is_binary(color) do
    color = Color.from_hex(color)
    relative_luminance(color)
  end

  def relative_luminance(%Color{r: r, g: g, b: b}) do
    # Convert RGB values to relative luminance
    r =
      if r <= 10,
        do: r / 255 / 12.92,
        else: :math.pow((r / 255 + 0.055) / 1.055, 2.4)

    g =
      if g <= 10,
        do: g / 255 / 12.92,
        else: :math.pow((g / 255 + 0.055) / 1.055, 2.4)

    b =
      if b <= 10,
        do: b / 255 / 12.92,
        else: :math.pow((b / 255 + 0.055) / 1.055, 2.4)

    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  @doc """
  Calculates the contrast ratio between two colors according to WCAG guidelines.

  ## Parameters

  - `color1` - The first color (hex string or Color struct)
  - `color2` - The second color (hex string or Color struct)

  ## Returns

  - A float representing the contrast ratio (1:1 to 21:1)

  ## Examples

      iex> Raxol.Style.Colors.Utilities.contrast_ratio("#000000", "#FFFFFF")
      21.0

      iex> Raxol.Style.Colors.Utilities.contrast_ratio("#777777", "#999999")
      1.3
  """
  def contrast_ratio(color1, color2)
      when is_binary(color1) or is_binary(color2) do
    color1 = if is_binary(color1), do: Color.from_hex(color1), else: color1
    color2 = if is_binary(color2), do: Color.from_hex(color2), else: color2
    contrast_ratio(color1, color2)
  end

  def contrast_ratio(%Color{} = color1, %Color{} = color2) do
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)

    lighter = max(l1, l2)
    darker = min(l1, l2)

    (lighter + 0.05) / (darker + 0.05)
  end

  @doc """
  Checks if a color is considered dark.

  Uses relative luminance (a value < 0.5 is considered dark).

  ## Parameters

  - `color` - The color to check (hex string or Color struct)

  ## Returns

  - `true` if the color is dark, `false` otherwise

  ## Examples

      iex> Raxol.Style.Colors.Utilities.dark_color?("#000000")
      true

      iex> Raxol.Style.Colors.Utilities.dark_color?("#FFFFFF")
      false
  """
  def dark_color?(color) when is_binary(color) do
    # Delegate to Accessibility module for consistent calculation
    case Color.from_hex(color) do
      %Color{} = c -> dark_color?(c)
      _ -> true # Treat invalid hex as dark?
    end
  end

  def dark_color?(%Color{} = color) do
    # Use the canonical luminance calculation
    Accessibility.relative_luminance(color) < 0.5
  end

  @doc """
  Calculates the perceived brightness of a color.

  Returns a value between 0 (darkest) and 255 (brightest).

  ## Parameters

  - `color` - The color to analyze

  ## Examples

      iex> black = Raxol.Style.Colors.Color.from_hex("#000000")
      iex> Raxol.Style.Colors.Utilities.brightness(black)
      0

      iex> white = Raxol.Style.Colors.Color.from_hex("#FFFFFF")
      iex> Raxol.Style.Colors.Utilities.brightness(white)
      255
  """
  def brightness(color) when is_binary(color) do
    case Color.from_hex(color) do
      %Color{} = c -> brightness(c)
      _ -> 0 # Default to black brightness for invalid hex
    end
  end

  def brightness(%Color{r: r, g: g, b: b}) do
    # Formula: (299*R + 587*G + 114*B) / 1000
    # Simplified to be in 0-255 range
    round((299 * r + 587 * g + 114 * b) / 1000)
  end

  @doc """
  Calculates the relative luminance of a color according to WCAG.

  Returns a value between 0 (darkest) and 1 (brightest).

  ## Parameters

  - `color` - The color to analyze

  ## Examples

      iex> black = Raxol.Style.Colors.Color.from_hex("#000000")
      iex> Raxol.Style.Colors.Utilities.luminance(black)
      0.0

      iex> white = Raxol.Style.Colors.Color.from_hex("#FFFFFF")
      iex> Raxol.Style.Colors.Utilities.luminance(white)
      1.0
  """
  def luminance(color) when is_binary(color) do
    # Delegate to Accessibility module
    Accessibility.relative_luminance(color)
  end

  def luminance(%Color{} = color) do
    Accessibility.relative_luminance(color)
  end

  @doc """
  Checks if a hex string is a valid hex color.

  ## Parameters

  - `hex_string` - The hex string to check

  ## Returns

  - `true` if the hex string is a valid hex color, `false` otherwise

  ## Examples

      iex> Raxol.Style.Colors.Utilities.hex_color?("#FF00AA")
      true
      iex> Raxol.Style.Colors.Utilities.hex_color?("blue")
      false
  """
  @spec hex_color?(String.t()) :: boolean()
  def hex_color?(hex_string) when is_binary(hex_string) do
    # Regex for #RGB, #RGBA, #RRGGBB, #RRGGBBAA
    ~r/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
    |> Regex.match?(hex_string)
  end
end
