defmodule Raxol.Terminal.ANSI.SixelPatternMap do
  @moduledoc """
  Provides a mapping from Sixel characters to their 6-bit pixel patterns.
  """

  # Sixel patterns are calculated directly from the character code.
  # The valid Sixel characters range from `?` (ASCII 63) to `~` (ASCII 126).
  # The pattern value is `char_code - 63`.

  import Bitwise

  @doc """
  Gets the 6-bit integer pattern for a given Sixel character code.

  Returns `nil` if the character code is outside the valid Sixel range (? to ~).
  Sixel characters range from ? (63) to ~ (126).
  """
  @spec get_pattern(integer()) :: non_neg_integer() | nil
  def get_pattern(char_code) when char_code >= ?\? and char_code <= ?\~ do
    # Pattern is simply the ASCII value minus 63
    char_code - ?\?
  end

  def get_pattern(_) do
    # Return nil for invalid characters (outside 63-126 range)
    nil
  end

  @doc """
  Converts a 6-bit integer pattern into a list of 6 pixel values (0 or 1).

  Bit 0 (LSB) corresponds to the top pixel.
  """
  @spec pattern_to_pixels(non_neg_integer()) :: list(0 | 1)
  def pattern_to_pixels(pattern) when pattern >= 0 and pattern <= 63 do
    for i <- 0..5, do: Bitwise.band(Bitwise.bsr(pattern, i), 1)
  end
end
