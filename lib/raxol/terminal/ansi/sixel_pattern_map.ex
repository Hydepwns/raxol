defmodule Raxol.Terminal.ANSI.SixelPatternMap do
  @moduledoc """
  Provides a mapping from Sixel characters to their 6-bit pixel patterns.
  """

  # Define the patterns as a compile-time map for efficiency.
  # Each pattern is a tuple representing the 6 pixels (bit 0 = top pixel).
  # Using integers 0-63 instead of lists for compactness.
  @patterns %{
    ?> => 0b000000, # Actually maps to empty pattern later, but keep structure
    ?~ => 0b000000, # Not defined in original, add as empty
    # Sixel characters `?` (63) through `~` (126)
    # Values derived from the original list-based patterns.
    # Example: ?" = [0,1,1,1,1,0] => 0b011110 = 30
    ?? => 30, # 0b011110
    ?@ => 61, # 0b111101
    ?A => 33, # 0b100001
    ?B => 34, # 0b100010
    ?C => 35, # 0b100011
    ?D => 36, # 0b100100
    ?E => 37, # 0b100101
    ?F => 38, # 0b100110
    ?G => 39, # 0b100111
    ?H => 40, # 0b101000
    ?I => 41, # 0b101001
    ?J => 42, # 0b101010
    ?K => 43, # 0b101011
    ?L => 44, # 0b101100
    ?M => 45, # 0b101101
    ?N => 46, # 0b101110
    ?O => 47, # 0b101111
    ?P => 48, # 0b110000
    ?Q => 49, # 0b110001
    ?R => 50, # 0b110010
    ?S => 51, # 0b110011
    ?T => 52, # 0b110100
    ?U => 53, # 0b110101
    ?V => 54, # 0b110110
    ?W => 55, # 0b110111
    ?X => 56, # 0b111000
    ?Y => 57, # 0b111001
    ?Z => 58, # 0b111010
    ?\[ => 59, # 0b111011
    ?\\ => 60, # 0b111100
    ?\] => 61, # 0b111101
    ?^ => 62, # 0b111110
    ?_ => 63, # 0b111111
    ?` => 0,  # 0b000000
    ?a => 1,  # 0b000001
    ?b => 2,  # 0b000010
    ?c => 3,  # 0b000011
    ?d => 4,  # 0b000100
    ?e => 5,  # 0b000101
    ?f => 6,  # 0b000110
    ?g => 7,  # 0b000111
    ?h => 8,  # 0b001000
    ?i => 9,  # 0b001001
    ?j => 10, # 0b001010
    ?k => 11, # 0b001011
    ?l => 12, # 0b001100
    ?m => 13, # 0b001101
    ?n => 14, # 0b001110
    ?o => 15, # 0b001111
    ?p => 16, # 0b010000
    ?q => 17, # 0b010001
    ?r => 18, # 0b010010
    ?s => 19, # 0b010011
    ?t => 20, # 0b010100
    ?u => 21, # 0b010101
    ?v => 22, # 0b010110
    ?w => 23, # 0b010111
    ?x => 24, # 0b011000
    ?y => 25, # 0b011001
    ?z => 26, # 0b011010
    ?{ => 27, # 0b011011
    ?| => 28, # 0b011100
    ?} => 29, # 0b011101
    # Note: `~` (126) is not typically a Sixel data char, mapped to 0
    # Original code mapped non-data chars like !, #, $, etc. - these are Sixel *commands*
    # or part of other sequences, not pixel data. The parser should handle them.
    # This map should *only* contain `?` through `~` (63-126)
    # Removing the non-data chars from the original list:
    ?! => nil, # Command
    ?# => nil, # Command
    ?$ => nil, # Command
    ?% => nil, # Not standard?
    ?& => nil, # Not standard?
    ?' => nil, # Not standard?
    ?( => nil, # Not standard?
    ?) => nil, # Not standard?
    ?* => nil, # Not standard?
    ?+ => nil, # Not standard?
    ?, => nil, # Not standard?
    ?- => nil, # Sixel command (CR)
    ?. => nil, # Not standard?
    ?/ => nil, # Not standard?
    ?0..?9 => nil, # Part of commands
    ?: => nil, # Not standard?
    ?; => nil, # Part of commands
    ?< => nil, # Not standard?
    ?= => nil, # Not standard?
    # Note: The original `char_to_sixel_pattern` used strings ("?", "@"). Ensure input char is integer.
  }
  |> Enum.reject(fn {_k, v} -> is_nil(v) end) # Remove the nil entries
  |> Map.new()

  @doc """
  Gets the 6-bit integer pattern for a given Sixel character code.

  Returns 0 (empty pattern) if the character code is invalid.
  Sixel characters range from ? (63) to ~ (126).
  """
  @spec get_pattern(integer()) :: non_neg_integer()
  def get_pattern(char_code) when char_code >= ?\? and char_code <= ?~ do
    Map.get(@patterns, char_code, 0)
  end

  def get_pattern(_) do
    0 # Return empty pattern for invalid characters
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
