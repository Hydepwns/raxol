defmodule Raxol.Terminal.Color.TrueColor.AnsiCodes do
  @moduledoc """
  Low-level ANSI color code helpers: 256-color and 16-color mapping,
  hex string parsing, and hex formatting.
  """

  @doc """
  Maps an 8-bit RGB color to a 256-color palette index.
  """
  @spec to_256(0..255, 0..255, 0..255) :: 0..255
  def to_256(r, g, b) when r == g and g == b do
    # Grayscale ramp
    232 + div(r * 23, 255)
  end

  def to_256(r, g, b) do
    # 6x6x6 color cube
    r_index = div(r * 5, 255)
    g_index = div(g * 5, 255)
    b_index = div(b * 5, 255)
    16 + 36 * r_index + 6 * g_index + b_index
  end

  @doc """
  Maps an 8-bit RGB color to the nearest 16-color ANSI code (foreground).
  """
  @spec to_16(0..255, 0..255, 0..255) :: 30..97
  def to_16(r, g, b) do
    brightness = (r + g + b) / 3
    map_color(r, g, b, brightness)
  end

  @doc """
  Parses a 6-char hex string to `{:ok, {r, g, b}}` or `{:error, :invalid_hex}`.
  """
  def parse_hex_6(hex) do
    with {r, ""} <- Integer.parse(String.slice(hex, 0, 2), 16),
         {g, ""} <- Integer.parse(String.slice(hex, 2, 2), 16),
         {b, ""} <- Integer.parse(String.slice(hex, 4, 2), 16) do
      {:ok, r, g, b, 255}
    else
      _ -> {:error, :invalid_hex}
    end
  end

  @doc """
  Parses an 8-char hex string to `{:ok, r, g, b, a}` or `{:error, :invalid_hex}`.
  """
  def parse_hex_8(hex) do
    with {r, ""} <- Integer.parse(String.slice(hex, 0, 2), 16),
         {g, ""} <- Integer.parse(String.slice(hex, 2, 2), 16),
         {b, ""} <- Integer.parse(String.slice(hex, 4, 2), 16),
         {a, ""} <- Integer.parse(String.slice(hex, 6, 2), 16) do
      {:ok, r, g, b, a}
    else
      _ -> {:error, :invalid_hex}
    end
  end

  @doc """
  Parses a 3-char hex string to `{:ok, r, g, b, 255}` or `{:error, :invalid_hex}`.
  """
  def parse_hex_3(hex) do
    with {r, ""} <- Integer.parse(String.slice(hex, 0, 1), 16),
         {g, ""} <- Integer.parse(String.slice(hex, 1, 1), 16),
         {b, ""} <- Integer.parse(String.slice(hex, 2, 1), 16) do
      {:ok, r * 17, g * 17, b * 17, 255}
    else
      _ -> {:error, :invalid_hex}
    end
  end

  @doc """
  Parses a 4-char hex string to `{:ok, r, g, b, a}` or `{:error, :invalid_hex}`.
  """
  def parse_hex_4(hex) do
    with {r, ""} <- Integer.parse(String.slice(hex, 0, 1), 16),
         {g, ""} <- Integer.parse(String.slice(hex, 1, 1), 16),
         {b, ""} <- Integer.parse(String.slice(hex, 2, 1), 16),
         {a, ""} <- Integer.parse(String.slice(hex, 3, 1), 16) do
      {:ok, r * 17, g * 17, b * 17, a * 17}
    else
      _ -> {:error, :invalid_hex}
    end
  end

  @doc """
  Formats an RGB(A) tuple as a hex string (e.g. "#FF0000" or "#FF0000AA").
  """
  def format_hex(r, g, b, a) when a < 255 do
    "##{pad(r)}#{pad(g)}#{pad(b)}#{pad(a)}"
  end

  def format_hex(r, g, b, _a) do
    "##{pad(r)}#{pad(g)}#{pad(b)}"
  end

  @doc """
  Pads an integer to a 2-char uppercase hex string.
  """
  def pad(value) do
    value
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
    |> String.upcase()
  end

  # -- Private 16-color mapping --

  defp map_color(r, g, b, brightness) when r > 128 and g < 128 and b < 128,
    do: if(brightness > 128, do: 91, else: 31)

  defp map_color(r, g, b, brightness) when r < 128 and g > 128 and b < 128,
    do: if(brightness > 128, do: 92, else: 32)

  defp map_color(r, g, b, brightness) when r < 128 and g < 128 and b > 128,
    do: if(brightness > 128, do: 94, else: 34)

  defp map_color(r, g, b, brightness) when r > 128 and g > 128 and b < 128,
    do: if(brightness > 128, do: 93, else: 33)

  defp map_color(r, g, b, brightness) when r > 128 and g < 128 and b > 128,
    do: if(brightness > 128, do: 95, else: 35)

  defp map_color(r, g, b, brightness) when r < 128 and g > 128 and b > 128,
    do: if(brightness > 128, do: 96, else: 36)

  defp map_color(_r, _g, _b, brightness) when brightness < 64, do: 30
  defp map_color(_r, _g, _b, brightness) when brightness > 192, do: 37

  defp map_color(_r, _g, _b, brightness),
    do: if(brightness > 128, do: 97, else: 37)
end
