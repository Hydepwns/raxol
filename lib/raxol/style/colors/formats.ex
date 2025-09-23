defmodule Raxol.Style.Colors.Formats do
  @moduledoc """
  Color format conversion utilities.

  This module provides functions for converting between different color formats:
  - RGB/RGBA tuples
  - Hex strings
  - ANSI color codes
  - Named colors
  """

  @doc """
  Converts a color to its hex representation.

  ## Examples

      iex> Formats.to_hex({255, 0, 0})
      "#FF0000"

      iex> Formats.to_hex({255, 0, 0, 128})
      "#FF000080"
  """
  @spec to_hex({byte(), byte(), byte()} | {byte(), byte(), byte(), byte()}) :: String.t()
  def to_hex({r, g, b})
      when r in 0..255//1 and g in 0..255//1 and b in 0..255//1 do
    r_hex = Integer.to_string(r, 16) |> String.pad_leading(2, "0")
    g_hex = Integer.to_string(g, 16) |> String.pad_leading(2, "0")
    b_hex = Integer.to_string(b, 16) |> String.pad_leading(2, "0")
    "#" <> String.upcase(r_hex <> g_hex <> b_hex)
  end

  def to_hex({r, g, b, a})
      when r in 0..255//1 and g in 0..255//1 and b in 0..255//1 and
             a in 0..255//1 do
    base = to_hex({r, g, b})
    a_hex = Integer.to_string(a, 16) |> String.pad_leading(2, "0")
    base <> String.upcase(a_hex)
  end

  @doc """
  Parses a hex string into RGB/RGBA values.

  ## Examples

      iex> Formats.from_hex("#FF0000")
      {255, 0, 0}

      iex> Formats.from_hex("#FF000080")
      {255, 0, 0, 128}
  """
  @spec from_hex(String.t()) ::
          {integer(), integer(), integer()}
          | {integer(), integer(), integer(), integer()}
  def from_hex(hex_string) when is_binary(hex_string) do
    hex_string = String.trim_leading(hex_string, "#")

    case String.length(hex_string) do
      3 ->
        # Expand short RGB (e.g., F00 -> FF0000)
        [r, g, b] = String.graphemes(hex_string)
        expanded = r <> r <> g <> g <> b <> b
        parse_rgb_hex(expanded)

      4 ->
        # Expand short RGBA (e.g., F008 -> FF000088)
        [r, g, b, a] = String.graphemes(hex_string)
        expanded = r <> r <> g <> g <> b <> b <> a <> a
        parse_rgba_hex(expanded)

      6 ->
        case parse_rgb_hex(hex_string) do
          {r, g, b} -> {r, g, b}
          {:error, :invalid_hex} = err -> err
        end

      8 ->
        case parse_rgba_hex(hex_string) do
          {r, g, b, a} -> {r, g, b, a}
          {:error, :invalid_hex} = err -> err
        end

      _ ->
        {:error, :invalid_hex}
    end
  end

  @doc """
  Converts an ANSI color code to RGB values.

  ## Examples

      iex> Formats.ansi_to_rgb(1)
      {205, 0, 0}
  """
  @spec ansi_to_rgb(byte()) :: {integer(), integer(), integer()}
  def ansi_to_rgb(code) when code in 0..255//1 do
    case code do
      # Basic 16 colors
      # Black
      0 ->
        {0, 0, 0}

      # Red
      1 ->
        {205, 0, 0}

      # Green
      2 ->
        {0, 205, 0}

      # Yellow
      3 ->
        {205, 205, 0}

      # Blue
      4 ->
        {0, 0, 238}

      # Magenta
      5 ->
        {205, 0, 205}

      # Cyan
      6 ->
        {0, 205, 205}

      # White
      7 ->
        {229, 229, 229}

      # Bright Black
      8 ->
        {127, 127, 127}

      # Bright Red
      9 ->
        {255, 0, 0}

      # Bright Green
      10 ->
        {0, 255, 0}

      # Bright Yellow
      11 ->
        {255, 255, 0}

      # Bright Blue
      12 ->
        {92, 92, 255}

      # Bright Magenta
      13 ->
        {255, 0, 255}

      # Bright Cyan
      14 ->
        {0, 255, 255}

      # Bright White
      15 ->
        {255, 255, 255}

      # 216 colors (6x6x6 cube)
      n when n in 16..231//1 ->
        n = n - 16
        r = div(n, 36) * 51
        g = rem(div(n, 6), 6) * 51
        b = rem(n, 6) * 51
        {r, g, b}

      # 24 grayscale colors
      n when n in 232..255//1 ->
        value = (n - 232) * 10 + 8
        {value, value, value}
    end
  end

  @doc """
  Converts RGB values to an ANSI color code.

  ## Examples

      iex> Formats.rgb_to_ansi({255, 0, 0})
      196
  """
  @spec rgb_to_ansi({byte(), byte(), byte()}) :: pos_integer()
  def rgb_to_ansi({r, g, b})
      when r in 0..255//1 and g in 0..255//1 and b in 0..255//1 do
    # For now, we'll use a simple approximation
    # This could be improved with a more sophisticated color matching algorithm
    find_closest_ansi_256(r, g, b)
  end

  # --- Private Helpers ---

  defp parse_rgb_hex(hex) do
    case byte_size(hex) do
      6 ->
        <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>> = hex

        with {r, ""} <- Integer.parse(r, 16),
             {g, ""} <- Integer.parse(g, 16),
             {b, ""} <- Integer.parse(b, 16) do
          {r, g, b}
        else
          _ -> {:error, :invalid_hex}
        end

      _ ->
        {:error, :invalid_hex}
    end
  end

  defp parse_rgba_hex(hex) do
    case byte_size(hex) do
      8 ->
        <<r::binary-size(2), g::binary-size(2), b::binary-size(2),
          a::binary-size(2)>> = hex

        with {r, ""} <- Integer.parse(r, 16),
             {g, ""} <- Integer.parse(g, 16),
             {b, ""} <- Integer.parse(b, 16),
             {a, ""} <- Integer.parse(a, 16) do
          {r, g, b, a}
        else
          _ -> {:error, :invalid_hex}
        end

      _ ->
        {:error, :invalid_hex}
    end
  end

  defp find_closest_ansi_256(r, g, b) do
    # Simple implementation - could be improved with better color matching
    # For now, we'll use the 216-color cube
    r_index = div(r, 51)
    g_index = div(g, 51)
    b_index = div(b, 51)
    16 + r_index * 36 + g_index * 6 + b_index
  end
end
