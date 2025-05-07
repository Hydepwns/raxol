defmodule Raxol.Terminal.ANSI.CharacterTranslations do
  @moduledoc """
  Provides character translation tables for different character sets.
  Maps characters between different character sets according to ANSI standards.
  """

  # US ASCII character set (G0)
  @us_ascii_map %{
                  # Control characters (0x00-0x1F) are not translated
                  # Printable ASCII (0x20-0x7E) are not translated
                  # DEL (0x7F) is not translated
                }

  # UK character set (G1)
  @uk_map %{
    # £ symbol (0x23) in UK character set
    0x23 => 163 # ?£ -> 163
    # Other characters are the same as US ASCII
  }

  # French character set (G1)
  @french_map %{
    # French-specific characters
    # £ symbol
    0x23 => 163, # ?£ -> 163
    # à
    0x40 => 224, # ?à -> 224
    # é
    0x5B => 233, # ?é -> 233
    # ê
    0x5C => 234, # ?ê -> 234
    # è
    0x5D => 232, # ?è -> 232
    # ë
    0x5E => 235, # ?ë -> 235
    # ï
    0x5F => 239, # ?ï -> 239
    # î
    0x60 => 238, # ?î -> 238
    # ù
    0x7B => 249, # ?ù -> 249
    # ô
    0x7C => 244, # ?ô -> 244
    # è (Duplicate mapping, assuming 0x7D should be something else? Let's keep it as è for now)
    0x7D => 232, # ?è -> 232 (Note: same as 0x5D)
    # û
    0x7E => 251  # ?û -> 251
  }

  # German character set (G1)
  @german_map %{
    # German-specific characters
    # Ä
    0x5B => 196, # ?Ä -> 196
    # Ö
    0x5C => 214, # ?Ö -> 214
    # Ü
    0x5D => 220, # ?Ü -> 220
    # ^ (Keep as integer)
    0x5E => 94,  # ?^ -> 94
    # _ (Keep as integer)
    0x5F => 95,  # ?_ -> 95
    # ` (Keep as integer)
    0x60 => 96,  # ?` -> 96
    # ä
    0x7B => 228, # ?ä -> 228
    # ö
    0x7C => 246, # ?ö -> 246
    # ü
    0x7D => 252, # ?ü -> 252
    # ß
    0x7E => 223 # ?ß -> 223
  }

  # Latin-1 character set (ISO-8859-1)
  @latin1_map %{
    # Latin-1 specific characters (0xA0-0xFF)
    # NO-BREAK SPACE
    0xA0 => 32,
    # INVERTED EXCLAMATION MARK
    0xA1 => 161, # ?¡ -> 161
    # CENT SIGN
    0xA2 => 162, # ?¢ -> 162
    # POUND SIGN
    0xA3 => 163, # ?£ -> 163
    # CURRENCY SIGN
    0xA4 => 164, # ?¤ -> 164
    # YEN SIGN
    0xA5 => 165, # ?¥ -> 165
    # BROKEN BAR
    0xA6 => 166, # ?¦ -> 166
    # SECTION SIGN
    0xA7 => 167, # ?§ -> 167
    # DIAERESIS
    0xA8 => 168, # ?¨ -> 168
    # COPYRIGHT SIGN
    0xA9 => 169, # ?© -> 169
    # FEMININE ORDINAL INDICATOR
    0xAA => 170, # ?ª -> 170
    # LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    0xAB => 171, # ?« -> 171
    # NOT SIGN
    0xAC => 172, # ?¬ -> 172
    # SOFT HYPHEN
    0xAD => 32,
    # REGISTERED SIGN
    0xAE => 174, # ?® -> 174
    # MACRON
    0xAF => 175, # ?¯ -> 175
    # DEGREE SIGN
    0xB0 => 176, # ?° -> 176
    # PLUS-MINUS SIGN
    0xB1 => 177, # ?± -> 177
    # SUPERSCRIPT TWO
    0xB2 => 178, # ?² -> 178
    # SUPERSCRIPT THREE
    0xB3 => 179, # ?³ -> 179
    # ACUTE ACCENT
    0xB4 => 180, # ?´ -> 180
    # MICRO SIGN
    0xB5 => 181, # ?µ -> 181
    # PILCROW SIGN
    0xB6 => 182, # ?¶ -> 182
    # MIDDLE DOT
    0xB7 => 183, # ?· -> 183
    # CEDILLA
    0xB8 => 184, # ?¸ -> 184
    # SUPERSCRIPT ONE
    0xB9 => 185, # ?¹ -> 185
    # MASCULINE ORDINAL INDICATOR
    0xBA => 186, # ?º -> 186
    # RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    0xBB => 187, # ?» -> 187
    # VULGAR FRACTION ONE QUARTER
    0xBC => 188, # ?¼ -> 188
    # VULGAR FRACTION ONE HALF
    0xBD => 189, # ?½ -> 189
    # VULGAR FRACTION THREE QUARTERS
    0xBE => 190, # ?¾ -> 190
    # INVERTED QUESTION MARK
    0xBF => 191, # ?¿ -> 191
    # LATIN CAPITAL LETTER A WITH GRAVE
    0xC0 => 192, # ?À -> 192
    # LATIN CAPITAL LETTER A WITH ACUTE
    0xC1 => 193, # ?Á -> 193
    # LATIN CAPITAL LETTER A WITH CIRCUMFLEX
    0xC2 => 194, # ?Â -> 194
    # LATIN CAPITAL LETTER A WITH TILDE
    0xC3 => 195, # ?Ã -> 195
    # LATIN CAPITAL LETTER A WITH DIAERESIS
    0xC4 => 196, # ?Ä -> 196
    # LATIN CAPITAL LETTER A WITH RING ABOVE
    0xC5 => 197, # ?Å -> 197
    # LATIN CAPITAL LETTER AE
    0xC6 => 198, # ?Æ -> 198
    # LATIN CAPITAL LETTER C WITH CEDILLA
    0xC7 => 199, # ?Ç -> 199
    # LATIN CAPITAL LETTER E WITH GRAVE
    0xC8 => 200, # ?È -> 200
    # LATIN CAPITAL LETTER E WITH ACUTE
    0xC9 => 201, # ?É -> 201
    # LATIN CAPITAL LETTER E WITH CIRCUMFLEX
    0xCA => 202, # ?Ê -> 202
    # LATIN CAPITAL LETTER E WITH DIAERESIS
    0xCB => 203, # ?Ë -> 203
    # LATIN CAPITAL LETTER I WITH GRAVE
    0xCC => 204, # ?Ì -> 204
    # LATIN CAPITAL LETTER I WITH ACUTE
    0xCD => 205, # ?Í -> 205
    # LATIN CAPITAL LETTER I WITH CIRCUMFLEX
    0xCE => 206, # ?Î -> 206
    # LATIN CAPITAL LETTER I WITH DIAERESIS
    0xCF => 207, # ?Ï -> 207
    # LATIN CAPITAL LETTER ETH
    0xD0 => 208, # ?Ð -> 208
    # LATIN CAPITAL LETTER N WITH TILDE
    0xD1 => 209, # ?Ñ -> 209
    # LATIN CAPITAL LETTER O WITH GRAVE
    0xD2 => 210, # ?Ò -> 210
    # LATIN CAPITAL LETTER O WITH ACUTE
    0xD3 => 211, # ?Ó -> 211
    # LATIN CAPITAL LETTER O WITH CIRCUMFLEX
    0xD4 => 212, # ?Ô -> 212
    # LATIN CAPITAL LETTER O WITH TILDE
    0xD5 => 213, # ?Õ -> 213
    # LATIN CAPITAL LETTER O WITH DIAERESIS
    0xD6 => 214, # ?Ö -> 214
    # MULTIPLICATION SIGN
    0xD7 => 215, # ?× -> 215
    # LATIN CAPITAL LETTER O WITH STROKE
    0xD8 => 216, # ?Ø -> 216
    # LATIN CAPITAL LETTER U WITH GRAVE
    0xD9 => 217, # ?Ù -> 217
    # LATIN CAPITAL LETTER U WITH ACUTE
    0xDA => 218, # ?Ú -> 218
    # LATIN CAPITAL LETTER U WITH CIRCUMFLEX
    0xDB => 219, # ?Û -> 219
    # LATIN CAPITAL LETTER U WITH DIAERESIS
    0xDC => 220, # ?Ü -> 220
    # LATIN CAPITAL LETTER Y WITH ACUTE
    0xDD => 221, # ?Ý -> 221
    # LATIN CAPITAL LETTER THORN
    0xDE => 222, # ?Þ -> 222
    # LATIN SMALL LETTER SHARP S
    0xDF => 223, # ?ß -> 223
    # LATIN SMALL LETTER A WITH GRAVE
    0xE0 => 224, # ?à -> 224
    # LATIN SMALL LETTER A WITH ACUTE
    0xE1 => 225, # ?á -> 225
    # LATIN SMALL LETTER A WITH CIRCUMFLEX
    0xE2 => 226, # ?â -> 226
    # LATIN SMALL LETTER A WITH TILDE
    0xE3 => 227, # ?ã -> 227
    # LATIN SMALL LETTER A WITH DIAERESIS
    0xE4 => 228, # ?ä -> 228
    # LATIN SMALL LETTER A WITH RING ABOVE
    0xE5 => 229, # ?å -> 229
    # LATIN SMALL LETTER AE
    0xE6 => 230, # ?æ -> 230
    # LATIN SMALL LETTER C WITH CEDILLA
    0xE7 => 231, # ?ç -> 231
    # LATIN SMALL LETTER E WITH GRAVE
    0xE8 => 232, # ?è -> 232
    # LATIN SMALL LETTER E WITH ACUTE
    0xE9 => 233, # ?é -> 233
    # LATIN SMALL LETTER E WITH CIRCUMFLEX
    0xEA => 234, # ?ê -> 234
    # LATIN SMALL LETTER E WITH DIAERESIS
    0xEB => 235, # ?ë -> 235
    # LATIN SMALL LETTER I WITH GRAVE
    0xEC => 236, # ?ì -> 236
    # LATIN SMALL LETTER I WITH ACUTE
    0xED => 237, # ?í -> 237
    # LATIN SMALL LETTER I WITH CIRCUMFLEX
    0xEE => 238, # ?î -> 238
    # LATIN SMALL LETTER I WITH DIAERESIS
    0xEF => 239, # ?ï -> 239
    # LATIN SMALL LETTER ETH
    0xF0 => 240, # ?ð -> 240
    # LATIN SMALL LETTER N WITH TILDE
    0xF1 => 241, # ?ñ -> 241
    # LATIN SMALL LETTER O WITH GRAVE
    0xF2 => 242, # ?ò -> 242
    # LATIN SMALL LETTER O WITH ACUTE
    0xF3 => 243, # ?ó -> 243
    # LATIN SMALL LETTER O WITH CIRCUMFLEX
    0xF4 => 244, # ?ô -> 244
    # LATIN SMALL LETTER O WITH TILDE
    0xF5 => 245, # ?õ -> 245
    # LATIN SMALL LETTER O WITH DIAERESIS
    0xF6 => 246, # ?ö -> 246
    # DIVISION SIGN
    0xF7 => 247, # ?÷ -> 247
    # LATIN SMALL LETTER O WITH STROKE
    0xF8 => 248, # ?ø -> 248
    # LATIN SMALL LETTER U WITH GRAVE
    0xF9 => 249, # ?ù -> 249
    # LATIN SMALL LETTER U WITH ACUTE
    0xFA => 250, # ?ú -> 250
    # LATIN SMALL LETTER U WITH CIRCUMFLEX
    0xFB => 251, # ?û -> 251
    # LATIN SMALL LETTER U WITH DIAERESIS
    0xFC => 252, # ?ü -> 252
    # LATIN SMALL LETTER Y WITH ACUTE
    0xFD => 253, # ?ý -> 253
    # LATIN SMALL LETTER THORN
    0xFE => 254, # ?þ -> 254
    # LATIN SMALL LETTER Y WITH DIAERESIS
    0xFF => 255 # ?ÿ -> 255
  }

  # DEC Special Graphics Character Set
  # Mapping based on https://vt100.net/docs/vt100-ug/table3-5.html
  # and https://en.wikipedia.org/wiki/DEC_Special_Graphics
  @dec_special_graphics_map %{
    0x5F => 0xA0, # _ -> Non-breaking space (often blank)
    0x60 => 0x25C6, # ` -> Diamond (◆)
    0x61 => 0x2592, # a -> Checkerboard (▒)
    0x62 => 0x2409, # b -> HT symbol (HT)
    0x63 => 0x240C, # c -> FF symbol (FF)
    0x64 => 0x240D, # d -> CR symbol (CR)
    0x65 => 0x240A, # e -> LF symbol (LF)
    0x66 => 0x00B0, # f -> Degree sign (°)
    0x67 => 0x00B1, # g -> Plus/minus sign (±)
    0x68 => 0x2424, # h -> NL symbol (NL)
    0x69 => 0x240B, # i -> VT symbol (VT)
    0x6A => 0x2518, # j -> Lower right corner (┘)
    0x6B => 0x2510, # k -> Upper right corner (┐)
    0x6C => 0x250C, # l -> Upper left corner (┌)
    0x6D => 0x2514, # m -> Lower left corner (└)
    0x6E => 0x253C, # n -> Crossing lines (+) (┼)
    0x6F => 0x23BA, # o -> Scan line 1 (⎺) - Horizontal bar top
    0x70 => 0x23BB, # p -> Scan line 3 (⎻) - Horizontal bar middle
    0x71 => 0x2500, # q -> Scan line 5 / Horizontal line (─)
    0x72 => 0x23BC, # r -> Scan line 7 (⎼) - Horizontal bar bottom
    0x73 => 0x23BD, # s -> Scan line 9 (⎽) - Horizontal bar underscore
    0x74 => 0x251C, # t -> Tee pointing right (├)
    0x75 => 0x2524, # u -> Tee pointing left (┤)
    0x76 => 0x2534, # v -> Tee pointing up (┴)
    0x77 => 0x252C, # w -> Tee pointing down (┬)
    0x78 => 0x2502, # x -> Vertical line (│)
    0x79 => 0x2264, # y -> Less than or equal to (≤)
    0x7A => 0x2265, # z -> Greater than or equal to (≥)
    0x7B => 0x03C0, # { -> Pi (π)
    0x7C => 0x2260, # | -> Not equal to (≠)
    0x7D => 0x00A3, # } -> Pound sign (£)
    0x7E => 0x00B7 # ~ -> Centered dot (·)
  }

  # Map of character set names to their translation tables
  @charset_tables %{
    us_ascii: @us_ascii_map,
    uk: @uk_map,
    french: @french_map,
    german: @german_map,
    latin1: @latin1_map,
    # DEC Special Character and Line Drawing Set
    dec_special_graphics: @dec_special_graphics_map
    # Other character sets will be added as needed
  }

  @doc """
  Translates a character from the source character set to the target character set.
  Returns the translated character or the original if no translation exists.
  """
  @spec translate_char(char_codepoint :: integer(), charset :: atom()) :: integer()
  def translate_char(char, charset) when is_integer(char) do
    # Select the correct map based on charset atom
    map = case charset do
            :us_ascii -> @us_ascii_map
            :uk -> @uk_map
            :french -> @french_map
            :german -> @german_map
            :latin1 -> @latin1_map
            :dec_special_graphics -> @dec_special_graphics_map
            # Add other charsets as needed
            _ -> %{} # Unknown charset, return original char below
          end

    # Lookup the character code in the selected map
    # Return the translated integer codepoint or the original if not found or map is empty
    Map.get(map, char, char)
  end

  @doc """
  Translates a string from the source character set to the target character set.
  """
  @spec translate_string(
          string :: String.t(),
          :us_ascii | :uk | :french | :german | :latin1
        ) :: String.t()
  def translate_string(string, charset) when is_binary(string) do
    # Iterate over CODPOINTS, translate each, collect resulting codepoints
    translated_codepoints =
      for char_string <- String.codepoints(string) do
        # Get the integer codepoint using hd/1 on the charlist
        codepoint = hd(String.to_charlist(char_string))
        translate_char(codepoint, charset)
      end

    # Convert list of integer codepoints back to a UTF-8 string
    List.to_string(translated_codepoints)
  end

  @doc """
  Map of Unicode codepoints to their ANSI terminal equivalents.
  """
  def unicode_to_ansi do
    %{
      # NO-BREAK SPACE
      0x00A0 => 32,
      # EN DASH
      0x2013 => 45,
      # EM DASH
      0x2014 => 45,
      # LEFT SINGLE QUOTATION MARK
      0x2018 => 39,
      # RIGHT SINGLE QUOTATION MARK
      0x2019 => 39,
      # LEFT DOUBLE QUOTATION MARK
      0x201C => 34,
      # RIGHT DOUBLE QUOTATION MARK
      0x201D => 34,
      # HORIZONTAL ELLIPSIS
      0x2026 => 46,
      # LINE SEPARATOR
      0x2028 => 10,
      # PARAGRAPH SEPARATOR
      0x2029 => 10,
      # NARROW NO-BREAK SPACE
      0x202F => 32,
      # MEDIUM MATHEMATICAL SPACE
      0x205F => 32,
      # IDEOGRAPHIC SPACE
      0x3000 => 32
    }
  end
end
