defmodule Raxol.Terminal.CharacterSets.Translator do
  @moduledoc """
  Provides translation logic for different character sets.

  Uses map lookups for efficient character translation based on the active set.
  Maps only store differences from the base character set (implicitly US-ASCII).
  """

  # --- Translation Maps ---
  # Define maps for character sets that have different mappings.
  # Keys are input codepoints, values are output codepoints.

  # Example: UK National Replacement Character Set (NRC)
  # Typically only changes one character: # (0x23) becomes £ (0xA3)
  @uk_map %{
    0x23 => 0xA3
  }
  # TODO: Define maps for other NRCs (French, German, Spanish, Italian, Swedish, etc.)
  # These often replace characters like #, @, [, ], {, }, etc.

  # Example: DEC Special Graphics
  # Maps lowercase letters and others to line drawing characters
  # See: https://vt100.net/docs/vt100-ug/table3-13.html
  # Note: Output uses Unicode Box Drawing characters where possible.
  # Using Unicode codepoints directly for clarity.
  @dec_special_graphics_map %{
    0x60 => 0x25C6, # ` -> diamond
    0x61 => 0x2592, # a -> checkerboard (stipple)
    0x62 => 0x2409, # b -> HT symbol
    0x63 => 0x240C, # c -> FF symbol
    0x64 => 0x240D, # d -> CR symbol
    0x65 => 0x240A, # e -> LF symbol
    0x66 => 0x00B0, # f -> degree symbol
    0x67 => 0x00B1, # g -> plus/minus
    0x68 => 0x2424, # h -> NL symbol
    0x69 => 0x240B, # i -> VT symbol
    0x6A => 0x2518, # j -> bottom right corner
    0x6B => 0x2510, # k -> top right corner
    0x6C => 0x250C, # l -> top left corner
    0x6D => 0x2514, # m -> bottom left corner
    0x6E => 0x253C, # n -> crossing lines
    0x6F => 0x23BA, # o -> scan line 1
    0x70 => 0x23BB, # p -> scan line 3
    0x71 => 0x2500, # q -> horizontal line (scan line 5)
    0x72 => 0x23BC, # r -> scan line 7
    0x73 => 0x23BD, # s -> scan line 9
    0x74 => 0x252C, # t -> tee pointing down
    0x75 => 0x2524, # u -> tee pointing left
    0x76 => 0x2534, # v -> tee pointing up
    0x77 => 0x251C, # w -> tee pointing right
    0x78 => 0x2502, # x -> vertical line
    0x79 => 0x2264, # y -> less than or equal to
    0x7A => 0x2265, # z -> greater than or equal to
    0x7B => 0x03C0, # { -> pi
    0x7C => 0x2260, # | -> not equal
    0x7D => 0x00A3, # } -> pound sterling
    0x7E => 0x00B7  # ~ -> middle dot (bullet)
    # Others map 1:1
  }

  # Add other charset maps here...
  # @latin1_map %{ ... }
  # @latin2_map %{ ... }
  # etc.

  # --- Translation Function ---

  @doc """
  Translates a single codepoint based on the specified character set atom.

  If the charset is unknown or the codepoint has no specific mapping in that
  charset, the original codepoint is returned.
  """
  @spec translate_codepoint(non_neg_integer(), atom()) :: non_neg_integer()
  def translate_codepoint(codepoint, charset_atom) do
    case charset_atom do
      :us_ascii -> codepoint # US ASCII has no translation
      :uk -> Map.get(@uk_map, codepoint, codepoint)
      :dec_special_graphics -> Map.get(@dec_special_graphics_map, codepoint, codepoint)
      # Add cases for other charsets
      # :latin1 -> Map.get(@latin1_map, codepoint, codepoint)
      _ ->
        # Default: return original codepoint for unknown/unmapped charsets
        # Consider logging a warning for unknown charsets?
        # require Logger
        # Logger.warning("Attempted translation with unknown charset: #{charset_atom}")
        codepoint
    end
  end
end
