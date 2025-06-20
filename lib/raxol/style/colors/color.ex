defmodule Raxol.Style.Colors.Color do
  @moduledoc """
  Core color representation and manipulation module.

  This module provides a unified interface for working with colors in Raxol,
  supporting various color formats and operations.

  ## Color Formats

  - RGB: `{r, g, b}` where each component is 0-255
  - RGBA: `{r, g, b, a}` where alpha is 0-255
  - Hex: `"#RRGGBB"` or `"#RRGGBBAA"`
  - ANSI: 0-255 for 256-color mode, 0-15 for basic colors
  - Named: `:red`, `:blue`, etc.

  ## Examples

      iex> Color.from_hex("#FF0000")
      %Color{r: 255, g: 0, b: 0, hex: "#FF0000"}

      iex> Color.from_rgb(255, 0, 0)
      %Color{r: 255, g: 0, b: 0, hex: "#FF0000"}

      iex> Color.from_ansi(1)
      %Color{r: 205, g: 0, b: 0, hex: "#CD0000", ansi_code: 1}
  """

  alias Raxol.Style.Colors.Formats

  @derive Jason.Encoder
  defstruct [
    # RGB components (0-255)
    :r,
    :g,
    :b,
    # Alpha component (0-255, optional)
    :a,
    # ANSI color code if applicable
    :ansi_code,
    # Hex representation
    :hex,
    # Optional name for predefined colors
    :name
  ]

  @type t :: %__MODULE__{
          r: integer(),
          g: integer(),
          b: integer(),
          a: integer() | nil,
          ansi_code: integer() | nil,
          hex: String.t(),
          name: String.t() | nil
        }

  @doc """
  Creates a color from a hex string.

  ## Examples

      iex> Color.from_hex("#FF0000")
      %Color{r: 255, g: 0, b: 0, hex: "#FF0000"}

      iex> Color.from_hex("#FF000080")
      %Color{r: 255, g: 0, b: 0, a: 128, hex: "#FF000080"}
  """
  @spec from_hex(String.t()) :: t() | {:error, :invalid_hex}
  def from_hex(hex_string) when is_binary(hex_string) do
    try do
      case Formats.from_hex(hex_string) do
        {r, g, b} -> from_rgb(r, g, b)
        {r, g, b, a} -> from_rgba(r, g, b, a)
        {:error, :invalid_hex} = err -> err
      end
    rescue
      ArgumentError -> {:error, :invalid_hex}
    end
  end

  @doc """
  Creates a color from RGB values.

  ## Examples

      iex> Color.from_rgb(255, 0, 0)
      %Color{r: 255, g: 0, b: 0, hex: "#FF0000"}
  """
  @spec from_rgb(integer(), integer(), integer()) :: t()
  def from_rgb(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    hex = Formats.to_hex({r, g, b})
    %__MODULE__{r: r, g: g, b: b, hex: hex}
  end

  @doc """
  Creates a color from RGBA values.

  ## Examples

      iex> Color.from_rgba(255, 0, 0, 128)
      %Color{r: 255, g: 0, b: 0, a: 128, hex: "#FF000080"}
  """
  @spec from_rgba(integer(), integer(), integer(), integer()) :: t()
  def from_rgba(r, g, b, a)
      when r in 0..255 and g in 0..255 and b in 0..255 and a in 0..255 do
    hex = Formats.to_hex({r, g, b, a})
    %__MODULE__{r: r, g: g, b: b, a: a, hex: hex}
  end

  @doc """
  Creates a color from an ANSI color code.

  ## Examples

      iex> Color.from_ansi(1)
      %Color{r: 205, g: 0, b: 0, hex: "#CD0000", ansi_code: 1}
  """
  @spec from_ansi(integer()) :: t()
  def from_ansi(code) when code in 0..255 do
    {r, g, b} = Formats.ansi_to_rgb(code)
    hex = Formats.to_hex({r, g, b})
    %__MODULE__{r: r, g: g, b: b, hex: hex, ansi_code: code}
  end

  @doc """
  Converts a color to its hex representation.

  ## Examples

      iex> color = Color.from_rgb(255, 0, 0)
      iex> Color.to_hex(color)
      "#FF0000"
  """
  def to_hex(%__MODULE__{r: r, g: g, b: b}) do
    Formats.to_hex({r, g, b})
  end

  @doc """
  Converts a color to the closest ANSI 16-color code.

  ## Examples

      iex> color = Color.from_rgb(255, 0, 0)
      iex> Color.to_ansi_16(color)
      9
  """
  def to_ansi_16(%__MODULE__{r: r, g: g, b: b}) do
    ansi_16_palette = [
      # Black
      {0, {0, 0, 0}},
      # Red
      {1, {205, 0, 0}},
      # Green
      {2, {0, 205, 0}},
      # Yellow
      {3, {205, 205, 0}},
      # Blue
      {4, {0, 0, 238}},
      # Magenta
      {5, {205, 0, 205}},
      # Cyan
      {6, {0, 205, 205}},
      # White (light gray)
      {7, {229, 229, 229}},
      # Bright Black (dark gray)
      {8, {127, 127, 127}},
      # Bright Red
      {9, {255, 0, 0}},
      # Bright Green
      {10, {0, 255, 0}},
      # Bright Yellow
      {11, {255, 255, 0}},
      # Bright Blue
      {12, {92, 92, 255}},
      # Bright Magenta
      {13, {255, 0, 255}},
      # Bright Cyan
      {14, {0, 255, 255}},
      # Bright White
      {15, {255, 255, 255}}
    ]

    {index, _} =
      Enum.min_by(ansi_16_palette, fn {_idx, {pr, pg, pb}} ->
        (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb)
      end)

    index
  end

  @doc """
  Converts a color to the closest ANSI 256-color code.

  ## Examples

      iex> color = Color.from_rgb(255, 0, 0)
      iex> Color.to_ansi_256(color)
      196
  """
  def to_ansi_256(%__MODULE__{r: r, g: g, b: b}) do
    Formats.rgb_to_ansi({r, g, b})
  end

  @doc """
  Converts a color to an ANSI code (currently defaults to 256-color code).
  The `type` parameter (:foreground or :background) is currently ignored.

  NOTE: This is a placeholder. Implement proper ANSI sequence generation based on type and terminal capabilities in the future.
  """
  @spec to_ansi(t(), :foreground | :background) :: integer()
  def to_ansi(%__MODULE__{} = color, _type) do
    to_ansi_256(color)
  end

  @doc """
  Lightens a color by the specified amount.

  ## Examples

      iex> Color.from_hex("#000000") |> Color.lighten(0.5)
      %Color{r: 128, g: 128, b: 128, hex: "#808080"}
  """
  @spec lighten(t(), float()) :: t()
  def lighten(%__MODULE__{} = color, amount) when amount >= 0 and amount <= 1 do
    r = round(color.r + (255 - color.r) * amount)
    g = round(color.g + (255 - color.g) * amount)
    b = round(color.b + (255 - color.b) * amount)
    from_rgb(r, g, b)
  end

  @doc """
  Darkens a color by the specified amount.

  ## Examples

      iex> Color.from_hex("#FFFFFF") |> Color.darken(0.5)
      %Color{r: 128, g: 128, b: 128, hex: "#808080"}
  """
  @spec darken(t(), float()) :: t()
  def darken(%__MODULE__{} = color, amount) when amount >= 0 and amount <= 1 do
    r = round(color.r * (1 - amount))
    g = round(color.g * (1 - amount))
    b = round(color.b * (1 - amount))
    from_rgb(r, g, b)
  end

  @doc """
  Blends two colors with the specified alpha value.

  ## Examples

      iex> Color.blend(Color.from_hex("#FF0000"), Color.from_hex("#0000FF"), 0.5)
      %Color{r: 128, g: 0, b: 128, hex: "#800080"}
  """
  @spec blend(t(), t(), float()) :: t()
  def blend(%__MODULE__{} = color1, %__MODULE__{} = color2, alpha)
      when is_float(alpha) and alpha >= 0.0 and alpha <= 1.0 do
    # Simple linear interpolation for each component
    r = round(color1.r * (1 - alpha) + color2.r * alpha)
    g = round(color1.g * (1 - alpha) + color2.g * alpha)
    b = round(color1.b * (1 - alpha) + color2.b * alpha)

    # Alpha blending for the 'a' component if both have it
    a1 = color1.a || 255
    a2 = color2.a || 255
    blended_a_float = a1 * (1 - alpha) + a2 * alpha
    blended_a = round(blended_a_float)

    # Decide if the result should have an alpha component
    if color1.a != nil or color2.a != nil or blended_a != 255 do
      from_rgba(r, g, b, blended_a)
    else
      from_rgb(r, g, b)
    end
  end

  @doc """
  Alias for blend/3. Blends two colors with the specified alpha value.

  ## Examples

      iex> Color.alpha_blend(Color.from_hex("#FF0000"), Color.from_hex("#0000FF"), 0.5)
      %Color{r: 128, g: 0, b: 128, hex: "#800080"}
  """
  @spec alpha_blend(t(), t(), float()) :: t()
  def alpha_blend(%__MODULE__{} = color1, %__MODULE__{} = color2, alpha)
      when is_float(alpha) and alpha >= 0.0 and alpha <= 1.0 do
    blend(color1, color2, alpha)
  end

  @doc """
  Returns the complementary color.

  ## Examples

      iex> Color.from_hex("#FF0000") |> Color.complement()
      %Color{r: 0, g: 255, b: 255, hex: "#00FFFF"}
  """
  @spec complement(t()) :: t()
  def complement(%__MODULE__{} = color) do
    from_rgb(255 - color.r, 255 - color.g, 255 - color.b)
  end

  @doc """
  Mixes two colors with the specified weight (0.0 to 1.0).

  ## Examples

      iex> color1 = Color.from_rgb(255, 0, 0)
      iex> color2 = Color.from_rgb(0, 0, 255)
      iex> mixed = Color.mix(color1, color2, 0.5)
      iex> {mixed.r, mixed.g, mixed.b}
      {127, 0, 127}
  """
  def mix(
        %__MODULE__{r: r1, g: g1, b: b1},
        %__MODULE__{r: r2, g: g2, b: b2},
        weight \\ 0.5
      )
      when weight >= 0 and weight <= 1 do
    new_r = trunc(r1 * (1 - weight) + r2 * weight)
    new_g = trunc(g1 * (1 - weight) + g2 * weight)
    new_b = trunc(b1 * (1 - weight) + b2 * weight)

    from_rgb(new_r, new_g, new_b)
  end
end
