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
    # ?£ -> 163
    0x23 => 163
    # Other characters are the same as US ASCII
  }

  # French character set (G1)
  @french_map %{
    # French-specific characters
    # £ symbol
    # ?£ -> 163
    0x23 => 163,
    # à
    # ?à -> 224
    0x40 => 224,
    # é
    # ?é -> 233
    0x5B => 233,
    # ê
    # ?ê -> 234
    0x5C => 234,
    # è
    # ?è -> 232
    0x5D => 232,
    # ë
    # ?ë -> 235
    0x5E => 235,
    # ï
    # ?ï -> 239
    0x5F => 239,
    # î
    # ?î -> 238
    0x60 => 238,
    # ù
    # ?ù -> 249
    0x7B => 249,
    # ô
    # ?ô -> 244
    0x7C => 244,
    # è (Duplicate mapping, assuming 0x7D should be something else? Let's keep it as è for now)
    # ?è -> 232 (Note: same as 0x5D)
    0x7D => 232,
    # û
    # ?û -> 251
    0x7E => 251
  }

  # German character set (G1)
  @german_map %{
    # German-specific characters
    # Ä
    # ?Ä -> 196
    0x5B => 196,
    # Ö
    # ?Ö -> 214
    0x5C => 214,
    # Ü
    # ?Ü -> 220
    0x5D => 220,
    # ^ (Keep as integer)
    # ?^ -> 94
    0x5E => 94,
    # _ (Keep as integer)
    # ?_ -> 95
    0x5F => 95,
    # ` (Keep as integer)
    # ?` -> 96
    0x60 => 96,
    # ä
    # ?ä -> 228
    0x7B => 228,
    # ö
    # ?ö -> 246
    0x7C => 246,
    # ü
    # ?ü -> 252
    0x7D => 252,
    # ß
    # ?ß -> 223
    0x7E => 223
  }

  # Latin-1 character set (ISO-8859-1)
  @latin1_map %{
    # Latin-1 specific characters (0xA0-0xFF)
    # NO-BREAK SPACE
    0xA0 => 32,
    # INVERTED EXCLAMATION MARK
    # ?¡ -> 161
    0xA1 => 161,
    # CENT SIGN
    # ?¢ -> 162
    0xA2 => 162,
    # POUND SIGN
    # ?£ -> 163
    0xA3 => 163,
    # CURRENCY SIGN
    # ?¤ -> 164
    0xA4 => 164,
    # YEN SIGN
    # ?¥ -> 165
    0xA5 => 165,
    # BROKEN BAR
    # ?¦ -> 166
    0xA6 => 166,
    # SECTION SIGN
    # ?§ -> 167
    0xA7 => 167,
    # DIAERESIS
    # ?¨ -> 168
    0xA8 => 168,
    # COPYRIGHT SIGN
    # ?© -> 169
    0xA9 => 169,
    # FEMININE ORDINAL INDICATOR
    # ?ª -> 170
    0xAA => 170,
    # LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    # ?« -> 171
    0xAB => 171,
    # NOT SIGN
    # ?¬ -> 172
    0xAC => 172,
    # SOFT HYPHEN
    0xAD => 32,
    # REGISTERED SIGN
    # ?® -> 174
    0xAE => 174,
    # MACRON
    # ?¯ -> 175
    0xAF => 175,
    # DEGREE SIGN
    # ?° -> 176
    0xB0 => 176,
    # PLUS-MINUS SIGN
    # ?± -> 177
    0xB1 => 177,
    # SUPERSCRIPT TWO
    # ?² -> 178
    0xB2 => 178,
    # SUPERSCRIPT THREE
    # ?³ -> 179
    0xB3 => 179,
    # ACUTE ACCENT
    # ?´ -> 180
    0xB4 => 180,
    # MICRO SIGN
    # ?µ -> 181
    0xB5 => 181,
    # PILCROW SIGN
    # ?¶ -> 182
    0xB6 => 182,
    # MIDDLE DOT
    # ?· -> 183
    0xB7 => 183,
    # CEDILLA
    # ?¸ -> 184
    0xB8 => 184,
    # SUPERSCRIPT ONE
    # ?¹ -> 185
    0xB9 => 185,
    # MASCULINE ORDINAL INDICATOR
    # ?º -> 186
    0xBA => 186,
    # RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    # ?» -> 187
    0xBB => 187,
    # VULGAR FRACTION ONE QUARTER
    # ?¼ -> 188
    0xBC => 188,
    # VULGAR FRACTION ONE HALF
    # ?½ -> 189
    0xBD => 189,
    # VULGAR FRACTION THREE QUARTERS
    # ?¾ -> 190
    0xBE => 190,
    # INVERTED QUESTION MARK
    # ?¿ -> 191
    0xBF => 191,
    # LATIN CAPITAL LETTER A WITH GRAVE
    # ?À -> 192
    0xC0 => 192,
    # LATIN CAPITAL LETTER A WITH ACUTE
    # ?Á -> 193
    0xC1 => 193,
    # LATIN CAPITAL LETTER A WITH CIRCUMFLEX
    # ?Â -> 194
    0xC2 => 194,
    # LATIN CAPITAL LETTER A WITH TILDE
    # ?Ã -> 195
    0xC3 => 195,
    # LATIN CAPITAL LETTER A WITH DIAERESIS
    # ?Ä -> 196
    0xC4 => 196,
    # LATIN CAPITAL LETTER A WITH RING ABOVE
    # ?Å -> 197
    0xC5 => 197,
    # LATIN CAPITAL LETTER AE
    # ?Æ -> 198
    0xC6 => 198,
    # LATIN CAPITAL LETTER C WITH CEDILLA
    # ?Ç -> 199
    0xC7 => 199,
    # LATIN CAPITAL LETTER E WITH GRAVE
    # ?È -> 200
    0xC8 => 200,
    # LATIN CAPITAL LETTER E WITH ACUTE
    # ?É -> 201
    0xC9 => 201,
    # LATIN CAPITAL LETTER E WITH CIRCUMFLEX
    # ?Ê -> 202
    0xCA => 202,
    # LATIN CAPITAL LETTER E WITH DIAERESIS
    # ?Ë -> 203
    0xCB => 203,
    # LATIN CAPITAL LETTER I WITH GRAVE
    # ?Ì -> 204
    0xCC => 204,
    # LATIN CAPITAL LETTER I WITH ACUTE
    # ?Í -> 205
    0xCD => 205,
    # LATIN CAPITAL LETTER I WITH CIRCUMFLEX
    # ?Î -> 206
    0xCE => 206,
    # LATIN CAPITAL LETTER I WITH DIAERESIS
    # ?Ï -> 207
    0xCF => 207,
    # LATIN CAPITAL LETTER ETH
    # ?Ð -> 208
    0xD0 => 208,
    # LATIN CAPITAL LETTER N WITH TILDE
    # ?Ñ -> 209
    0xD1 => 209,
    # LATIN CAPITAL LETTER O WITH GRAVE
    # ?Ò -> 210
    0xD2 => 210,
    # LATIN CAPITAL LETTER O WITH ACUTE
    # ?Ó -> 211
    0xD3 => 211,
    # LATIN CAPITAL LETTER O WITH CIRCUMFLEX
    # ?Ô -> 212
    0xD4 => 212,
    # LATIN CAPITAL LETTER O WITH TILDE
    # ?Õ -> 213
    0xD5 => 213,
    # LATIN CAPITAL LETTER O WITH DIAERESIS
    # ?Ö -> 214
    0xD6 => 214,
    # MULTIPLICATION SIGN
    # ?× -> 215
    0xD7 => 215,
    # LATIN CAPITAL LETTER O WITH STROKE
    # ?Ø -> 216
    0xD8 => 216,
    # LATIN CAPITAL LETTER U WITH GRAVE
    # ?Ù -> 217
    0xD9 => 217,
    # LATIN CAPITAL LETTER U WITH ACUTE
    # ?Ú -> 218
    0xDA => 218,
    # LATIN CAPITAL LETTER U WITH CIRCUMFLEX
    # ?Û -> 219
    0xDB => 219,
    # LATIN CAPITAL LETTER U WITH DIAERESIS
    # ?Ü -> 220
    0xDC => 220,
    # LATIN CAPITAL LETTER Y WITH ACUTE
    # ?Ý -> 221
    0xDD => 221,
    # LATIN CAPITAL LETTER THORN
    # ?Þ -> 222
    0xDE => 222,
    # LATIN SMALL LETTER SHARP S
    # ?ß -> 223
    0xDF => 223,
    # LATIN SMALL LETTER A WITH GRAVE
    # ?à -> 224
    0xE0 => 224,
    # LATIN SMALL LETTER A WITH ACUTE
    # ?á -> 225
    0xE1 => 225,
    # LATIN SMALL LETTER A WITH CIRCUMFLEX
    # ?â -> 226
    0xE2 => 226,
    # LATIN SMALL LETTER A WITH TILDE
    # ?ã -> 227
    0xE3 => 227,
    # LATIN SMALL LETTER A WITH DIAERESIS
    # ?ä -> 228
    0xE4 => 228,
    # LATIN SMALL LETTER A WITH RING ABOVE
    # ?å -> 229
    0xE5 => 229,
    # LATIN SMALL LETTER AE
    # ?æ -> 230
    0xE6 => 230,
    # LATIN SMALL LETTER C WITH CEDILLA
    # ?ç -> 231
    0xE7 => 231,
    # LATIN SMALL LETTER E WITH GRAVE
    # ?è -> 232
    0xE8 => 232,
    # LATIN SMALL LETTER E WITH ACUTE
    # ?é -> 233
    0xE9 => 233,
    # LATIN SMALL LETTER E WITH CIRCUMFLEX
    # ?ê -> 234
    0xEA => 234,
    # LATIN SMALL LETTER E WITH DIAERESIS
    # ?ë -> 235
    0xEB => 235,
    # LATIN SMALL LETTER I WITH GRAVE
    # ?ì -> 236
    0xEC => 236,
    # LATIN SMALL LETTER I WITH ACUTE
    # ?í -> 237
    0xED => 237,
    # LATIN SMALL LETTER I WITH CIRCUMFLEX
    # ?î -> 238
    0xEE => 238,
    # LATIN SMALL LETTER I WITH DIAERESIS
    # ?ï -> 239
    0xEF => 239,
    # LATIN SMALL LETTER ETH
    # ?ð -> 240
    0xF0 => 240,
    # LATIN SMALL LETTER N WITH TILDE
    # ?ñ -> 241
    0xF1 => 241,
    # LATIN SMALL LETTER O WITH GRAVE
    # ?ò -> 242
    0xF2 => 242,
    # LATIN SMALL LETTER O WITH ACUTE
    # ?ó -> 243
    0xF3 => 243,
    # LATIN SMALL LETTER O WITH CIRCUMFLEX
    # ?ô -> 244
    0xF4 => 244,
    # LATIN SMALL LETTER O WITH TILDE
    # ?õ -> 245
    0xF5 => 245,
    # LATIN SMALL LETTER O WITH DIAERESIS
    # ?ö -> 246
    0xF6 => 246,
    # DIVISION SIGN
    # ?÷ -> 247
    0xF7 => 247,
    # LATIN SMALL LETTER O WITH STROKE
    # ?ø -> 248
    0xF8 => 248,
    # LATIN SMALL LETTER U WITH GRAVE
    # ?ù -> 249
    0xF9 => 249,
    # LATIN SMALL LETTER U WITH ACUTE
    # ?ú -> 250
    0xFA => 250,
    # LATIN SMALL LETTER U WITH CIRCUMFLEX
    # ?û -> 251
    0xFB => 251,
    # LATIN SMALL LETTER U WITH DIAERESIS
    # ?ü -> 252
    0xFC => 252,
    # LATIN SMALL LETTER Y WITH ACUTE
    # ?ý -> 253
    0xFD => 253,
    # LATIN SMALL LETTER THORN
    # ?þ -> 254
    0xFE => 254,
    # LATIN SMALL LETTER Y WITH DIAERESIS
    # ?ÿ -> 255
    0xFF => 255
  }

  # DEC Special Graphics Character Set
  # Mapping based on https://vt100.net/docs/vt100-ug/table3-5.html
  # and https://en.wikipedia.org/wiki/DEC_Special_Graphics
  @dec_special_graphics_map %{
    # _ -> Non-breaking space (often blank)
    0x5F => 0xA0,
    # ` -> Diamond (◆)
    0x60 => 0x25C6,
    # a -> Checkerboard (▒)
    0x61 => 0x2592,
    # b -> HT symbol (HT)
    0x62 => 0x2409,
    # c -> FF symbol (FF)
    0x63 => 0x240C,
    # d -> CR symbol (CR)
    0x64 => 0x240D,
    # e -> LF symbol (LF)
    0x65 => 0x240A,
    # f -> Degree sign (°)
    0x66 => 0x00B0,
    # g -> Plus/minus sign (±)
    0x67 => 0x00B1,
    # h -> NL symbol (NL)
    0x68 => 0x2424,
    # i -> VT symbol (VT)
    0x69 => 0x240B,
    # j -> Lower right corner (┘)
    0x6A => 0x2518,
    # k -> Upper right corner (┐)
    0x6B => 0x2510,
    # l -> Upper left corner (┌)
    0x6C => 0x250C,
    # m -> Lower left corner (└)
    0x6D => 0x2514,
    # n -> Crossing lines (+) (┼)
    0x6E => 0x253C,
    # o -> Scan line 1 (⎺) - Horizontal bar top
    0x6F => 0x23BA,
    # p -> Scan line 3 (⎻) - Horizontal bar middle
    0x70 => 0x23BB,
    # q -> Scan line 5 / Horizontal line (─)
    0x71 => 0x2500,
    # r -> Scan line 7 (⎼) - Horizontal bar bottom
    0x72 => 0x23BC,
    # s -> Scan line 9 (⎽) - Horizontal bar underscore
    0x73 => 0x23BD,
    # t -> Tee pointing right (├)
    0x74 => 0x251C,
    # u -> Tee pointing left (┤)
    0x75 => 0x2524,
    # v -> Tee pointing up (┴)
    0x76 => 0x2534,
    # w -> Tee pointing down (┬)
    0x77 => 0x252C,
    # x -> Vertical line (│)
    0x78 => 0x2502,
    # y -> Less than or equal to (≤)
    0x79 => 0x2264,
    # z -> Greater than or equal to (≥)
    0x7A => 0x2265,
    # { -> Pi (π)
    0x7B => 0x03C0,
    # | -> Not equal to (≠)
    0x7C => 0x2260,
    # } -> Pound sign (£)
    0x7D => 0x00A3,
    # ~ -> Centered dot (·)
    0x7E => 0x00B7
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
  @spec translate_char(char_codepoint :: integer(), charset :: atom()) ::
          integer()
  def translate_char(char, charset) when is_integer(char) do
    # Select the correct map based on charset atom
    map =
      case charset do
        :us_ascii -> @us_ascii_map
        :uk -> @uk_map
        :french -> @french_map
        :german -> @german_map
        :latin1 -> @latin1_map
        :dec_special_graphics -> @dec_special_graphics_map
        # Add other charsets as needed
        # Unknown charset, return original char below
        _ -> %{}
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
