defmodule Raxol.Style.Colors.Color do
  @moduledoc """
  Represents a color in various formats with conversion utilities.
  Supports ANSI 16/256 colors and True Color (24-bit).

  ## Examples

  ```elixir
  # Creating colors
  red = Raxol.Style.Colors.Color.from_hex("#FF0000")
  blue = Raxol.Style.Colors.Color.from_rgb(0, 0, 255)
  green = Raxol.Style.Colors.Color.from_ansi(2)

  # Converting colors
  hex_code = Raxol.Style.Colors.Color.to_hex(red)
  ansi_code = Raxol.Style.Colors.Color.to_ansi_256(blue)

  # Color operations
  light_red = Raxol.Style.Colors.Color.lighten(red, 0.2)
  dark_blue = Raxol.Style.Colors.Color.darken(blue, 0.3)
  purple = Raxol.Style.Colors.Color.mix(red, blue, 0.5)
  ```
  """

  @ansi_16_colors %{
    # black
    0 => {0, 0, 0},
    # red
    1 => {128, 0, 0},
    # green
    2 => {0, 128, 0},
    # yellow
    3 => {128, 128, 0},
    # blue
    4 => {0, 0, 128},
    # magenta
    5 => {128, 0, 128},
    # cyan
    6 => {0, 128, 128},
    # white
    7 => {192, 192, 192},
    # bright black (gray)
    8 => {128, 128, 128},
    # bright red
    9 => {255, 0, 0},
    # bright green
    10 => {0, 255, 0},
    # bright yellow
    11 => {255, 255, 0},
    # bright blue
    12 => {0, 0, 255},
    # bright magenta
    13 => {255, 0, 255},
    # bright cyan
    14 => {0, 255, 255},
    # bright white
    15 => {255, 255, 255}
  }

  @derive Jason.Encoder
  defstruct [
    # RGB components (0-255)
    :r,
    :g,
    :b,
    # ANSI color code if applicable
    :ansi_code,
    # Hex representation
    :hex,
    # Optional name for predefined colors
    :name,
    # Alpha component (0.0-1.0)
    a: 1.0
  ]

  @type t :: %__MODULE__{
          r: integer(),
          g: integer(),
          b: integer(),
          # Alpha component (0.0-1.0)
          a: float(),
          ansi_code: integer() | nil,
          hex: String.t(),
          name: String.t() | nil
        }

  @doc """
  Creates a color from a hex string.

  Accepts hex strings in the following formats:
  - "#RGB"
  - "#RRGGBB"
  - "RGB"
  - "RRGGBB"

  Returns `{:error, :invalid_hex}` if the string is invalid.

  ## Examples

      iex> Raxol.Style.Colors.Color.from_hex("#FF0000")
      %Raxol.Style.Colors.Color{r: 255, g: 0, b: 0, hex: "#FF0000"}

      iex> Raxol.Style.Colors.Color.from_hex("0F0")
      %Raxol.Style.Colors.Color{r: 0, g: 255, b: 0, hex: "#00FF00"}
  """
  @spec from_hex(binary()) :: t() | {:error, :invalid_hex}
  def from_hex(hex) when is_binary(hex) do
    hex = String.trim_leading(hex, "#")

    case String.length(hex) do
      6 ->
        try do
          <<r_h::binary-size(2), g_h::binary-size(2), b_h::binary-size(2)>> =
            hex

          r = String.to_integer(r_h, 16)
          g = String.to_integer(g_h, 16)
          b = String.to_integer(b_h, 16)
          from_rgb(r, g, b)
        rescue
          _ -> {:error, :invalid_hex}
        end

      3 ->
        try do
          <<r_h::binary-size(1), g_h::binary-size(1), b_h::binary-size(1)>> =
            hex

          r = String.to_integer(r_h <> r_h, 16)
          g = String.to_integer(g_h <> g_h, 16)
          b = String.to_integer(b_h <> b_h, 16)
          from_rgb(r, g, b)
        rescue
          _ -> {:error, :invalid_hex}
        end

      _ ->
        {:error, :invalid_hex}
    end
  end

  @doc """
  Converts a color to its hex representation.

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_rgb(255, 0, 0)
      iex> Raxol.Style.Colors.Color.to_hex(color)
      "#FF0000"
  """
  def to_hex(%__MODULE__{r: r, g: g, b: b}) do
    r_hex = Integer.to_string(r, 16) |> String.pad_leading(2, "0")
    g_hex = Integer.to_string(g, 16) |> String.pad_leading(2, "0")
    b_hex = Integer.to_string(b, 16) |> String.pad_leading(2, "0")
    "#" <> String.upcase(r_hex <> g_hex <> b_hex)
  end

  @doc """
  Creates a color from RGB values.

  ## Examples

      iex> Raxol.Style.Colors.Color.from_rgb(255, 0, 0)
      %Raxol.Style.Colors.Color{r: 255, g: 0, b: 0, hex: "#FF0000"}
  """
  @spec from_rgb(0..255, 0..255, 0..255) :: t()
  def from_rgb(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    hex =
      "#" <>
        ([r, g, b]
         |> Enum.map(&Integer.to_string(&1, 16))
         |> Enum.map(&String.pad_leading(&1, 2, "0"))
         |> Enum.join()
         |> String.upcase())

    %__MODULE__{r: r, g: g, b: b, a: 1.0, hex: hex}
  end

  @doc """
  Creates a color from an ANSI color code.

  ## Examples

      iex> Raxol.Style.Colors.Color.from_ansi(1)
      %Raxol.Style.Colors.Color{r: 128, g: 0, b: 0, ansi_code: 1, hex: "#800000"}
  """
  def from_ansi(code) when code in 0..15 do
    {r, g, b} = Map.get(@ansi_16_colors, code)

    r_hex = Integer.to_string(r, 16) |> String.pad_leading(2, "0")
    g_hex = Integer.to_string(g, 16) |> String.pad_leading(2, "0")
    b_hex = Integer.to_string(b, 16) |> String.pad_leading(2, "0")
    hex = ("#" <> r_hex <> g_hex <> b_hex) |> String.upcase()

    %__MODULE__{r: r, g: g, b: b, hex: hex, ansi_code: code}
  end

  @doc """
  Converts a color to the closest ANSI 16-color code.

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_rgb(255, 0, 0)
      iex> Raxol.Style.Colors.Color.to_ansi_16(color)
      9
  """
  def to_ansi_16(%__MODULE__{r: r, g: g, b: b}) do
    find_closest_ansi_16(r, g, b)
  end

  @doc """
  Converts a color to the closest ANSI 256-color code.

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_rgb(255, 0, 0)
      iex> Raxol.Style.Colors.Color.to_ansi_256(color)
      196
  """
  def to_ansi_256(%__MODULE__{r: r, g: g, b: b}) do
    # For simplicity, we'll just use 16-color codes for now
    # This should be expanded to handle proper 256-color conversion
    find_closest_ansi_16(r, g, b)
  end

  @doc """
  Converts a color to an ANSI code (currently defaults to 256-color code).
  The `type` parameter (:foreground or :background) is currently ignored.

  TODO: Implement proper ANSI sequence generation based on type and terminal capabilities.
  """
  @spec to_ansi(t(), :foreground | :background) :: integer()
  def to_ansi(%__MODULE__{} = color, _type) do
    to_ansi_256(color)
  end

  @doc """
  Lightens a color by the specified amount (0.0 to 1.0).

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_rgb(100, 100, 100)
      iex> lightened = Raxol.Style.Colors.Color.lighten(color, 0.5)
      iex> {lightened.r, lightened.g, lightened.b}
      {177, 177, 177}
  """
  def lighten(%__MODULE__{r: r, g: g, b: b} = _color, amount)
      when amount >= 0 and amount <= 1 do
    new_r = min(round(r + (255 - r) * amount), 255)
    new_g = min(round(g + (255 - g) * amount), 255)
    new_b = min(round(b + (255 - b) * amount), 255)

    from_rgb(new_r, new_g, new_b)
  end

  @doc """
  Darkens a color by the specified amount (0.0 to 1.0).

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_rgb(200, 200, 200)
      iex> darkened = Raxol.Style.Colors.Color.darken(color, 0.5)
      iex> {darkened.r, darkened.g, darkened.b}
      {100, 100, 100}
  """
  def darken(%__MODULE__{r: r, g: g, b: b} = _color, amount)
      when amount >= 0 and amount <= 1 do
    new_r = max(trunc(r * (1 - amount)), 0)
    new_g = max(trunc(g * (1 - amount)), 0)
    new_b = max(trunc(b * (1 - amount)), 0)

    from_rgb(new_r, new_g, new_b)
  end

  @doc """
  Blends two colors with the specified alpha value (0.0 to 1.0).

  ## Examples

      iex> color1 = Raxol.Style.Colors.Color.from_rgb(255, 0, 0)
      iex> color2 = Raxol.Style.Colors.Color.from_rgb(0, 0, 255)
      iex> blended = Raxol.Style.Colors.Color.alpha_blend(color1, color2, 0.5)
      iex> {blended.r, blended.g, blended.b}
      {127, 0, 127}
  """
  def alpha_blend(
        %__MODULE__{r: r1, g: g1, b: b1},
        %__MODULE__{r: r2, g: g2, b: b2},
        alpha
      )
      when alpha >= 0 and alpha <= 1 do
    new_r = trunc(r1 * (1 - alpha) + r2 * alpha)
    new_g = trunc(g1 * (1 - alpha) + g2 * alpha)
    new_b = trunc(b1 * (1 - alpha) + b2 * alpha)

    from_rgb(new_r, new_g, new_b)
  end

  @doc """
  Returns the complementary color.

  ## Examples

      iex> color = Raxol.Style.Colors.Color.from_rgb(255, 0, 0)
      iex> complement = Raxol.Style.Colors.Color.complement(color)
      iex> {complement.r, complement.g, complement.b}
      {0, 255, 255}
  """
  def complement(%__MODULE__{r: r, g: g, b: b}) do
    from_rgb(255 - r, 255 - g, 255 - b)
  end

  @doc """
  Mixes two colors with the specified weight (0.0 to 1.0).

  ## Examples

      iex> color1 = Raxol.Style.Colors.Color.from_rgb(255, 0, 0)
      iex> color2 = Raxol.Style.Colors.Color.from_rgb(0, 0, 255)
      iex> mixed = Raxol.Style.Colors.Color.mix(color1, color2, 0.5)
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

  # Private functions

  defp find_closest_ansi_16(r, g, b) do
    # Find the closest ANSI 16-color based on Euclidean distance in RGB space
    Enum.min_by(@ansi_16_colors, fn {_code, {ar, ag, ab}} ->
      :math.sqrt(
        :math.pow(r - ar, 2) + :math.pow(g - ag, 2) + :math.pow(b - ab, 2)
      )
    end)
    |> elem(0)
  end
end
