defmodule Raxol.Terminal.ANSI.SixelPatternMap do
  @moduledoc '''
  Provides a mapping from Sixel characters to their 6-bit pixel patterns.
  '''

  @doc '''
  Gets the 6-bit integer pattern for a given Sixel character code.
  '''
  @spec get_pattern(integer()) :: non_neg_integer() | nil
  def get_pattern(char_code) when char_code >= ?\? and char_code <= ?\~ do
    char_code - ?\?
  end

  def get_pattern(_) do
    nil
  end

  @doc '''
  Converts a 6-bit integer pattern into a list of 6 pixel values (0 or 1).
  '''
  @spec pattern_to_pixels(non_neg_integer()) :: list(0 | 1)
  def pattern_to_pixels(pattern) when pattern >= 0 and pattern <= 63 do
    for i <- 0..5, do: Bitwise.band(Bitwise.bsr(pattern, i), 1)
  end
end
