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
    0x23 => ?£
    # Other characters are the same as US ASCII
  }

  # French character set (G1)
  @french_map %{
    # French-specific characters
    # £ symbol
    0x23 => ?£,
    # à
    0x40 => ?à,
    # é
    0x5B => ?é,
    # ê
    0x5C => ?ê,
    # è
    0x5D => ?è,
    # ë
    0x5E => ?ë,
    # ï
    0x5F => ?ï,
    # î
    0x60 => ?î,
    # ù
    0x7B => ?ù,
    # ô
    0x7C => ?ô,
    # è
    0x7D => ?è,
    # û
    0x7E => ?û
  }

  # German character set (G1)
  @german_map %{
    # German-specific characters
    # Ä
    0x5B => ?Ä,
    # Ö
    0x5C => ?Ö,
    # Ü
    0x5D => ?Ü,
    # ^
    0x5E => ?^,
    # _
    0x5F => ?_,
    # `
    0x60 => ?`,
    # ä
    0x7B => ?ä,
    # ö
    0x7C => ?ö,
    # ü
    0x7D => ?ü,
    # ß
    0x7E => ?ß
  }

  # Latin-1 character set (ISO-8859-1)
  @latin1_map %{
    # Latin-1 specific characters (0xA0-0xFF)
    # NO-BREAK SPACE
    0xA0 => 32,
    # INVERTED EXCLAMATION MARK
    0xA1 => ?¡,
    # CENT SIGN
    0xA2 => ?¢,
    # POUND SIGN
    0xA3 => ?£,
    # CURRENCY SIGN
    0xA4 => ?¤,
    # YEN SIGN
    0xA5 => ?¥,
    # BROKEN BAR
    0xA6 => ?¦,
    # SECTION SIGN
    0xA7 => ?§,
    # DIAERESIS
    0xA8 => ?¨,
    # COPYRIGHT SIGN
    0xA9 => ?©,
    # FEMININE ORDINAL INDICATOR
    0xAA => ?ª,
    # LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    0xAB => ?«,
    # NOT SIGN
    0xAC => ?¬,
    # SOFT HYPHEN
    0xAD => 32,
    # REGISTERED SIGN
    0xAE => ?®,
    # MACRON
    0xAF => ?¯,
    # DEGREE SIGN
    0xB0 => ?°,
    # PLUS-MINUS SIGN
    0xB1 => ?±,
    # SUPERSCRIPT TWO
    0xB2 => ?²,
    # SUPERSCRIPT THREE
    0xB3 => ?³,
    # ACUTE ACCENT
    0xB4 => ?´,
    # MICRO SIGN
    0xB5 => ?µ,
    # PILCROW SIGN
    0xB6 => ?¶,
    # MIDDLE DOT
    0xB7 => ?·,
    # CEDILLA
    0xB8 => ?¸,
    # SUPERSCRIPT ONE
    0xB9 => ?¹,
    # MASCULINE ORDINAL INDICATOR
    0xBA => ?º,
    # RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    0xBB => ?»,
    # VULGAR FRACTION ONE QUARTER
    0xBC => ?¼,
    # VULGAR FRACTION ONE HALF
    0xBD => ?½,
    # VULGAR FRACTION THREE QUARTERS
    0xBE => ?¾,
    # INVERTED QUESTION MARK
    0xBF => ?¿,
    # LATIN CAPITAL LETTER A WITH GRAVE
    0xC0 => ?À,
    # LATIN CAPITAL LETTER A WITH ACUTE
    0xC1 => ?Á,
    # LATIN CAPITAL LETTER A WITH CIRCUMFLEX
    0xC2 => ?Â,
    # LATIN CAPITAL LETTER A WITH TILDE
    0xC3 => ?Ã,
    # LATIN CAPITAL LETTER A WITH DIAERESIS
    0xC4 => ?Ä,
    # LATIN CAPITAL LETTER A WITH RING ABOVE
    0xC5 => ?Å,
    # LATIN CAPITAL LETTER AE
    0xC6 => ?Æ,
    # LATIN CAPITAL LETTER C WITH CEDILLA
    0xC7 => ?Ç,
    # LATIN CAPITAL LETTER E WITH GRAVE
    0xC8 => ?È,
    # LATIN CAPITAL LETTER E WITH ACUTE
    0xC9 => ?É,
    # LATIN CAPITAL LETTER E WITH CIRCUMFLEX
    0xCA => ?Ê,
    # LATIN CAPITAL LETTER E WITH DIAERESIS
    0xCB => ?Ë,
    # LATIN CAPITAL LETTER I WITH GRAVE
    0xCC => ?Ì,
    # LATIN CAPITAL LETTER I WITH ACUTE
    0xCD => ?Í,
    # LATIN CAPITAL LETTER I WITH CIRCUMFLEX
    0xCE => ?Î,
    # LATIN CAPITAL LETTER I WITH DIAERESIS
    0xCF => ?Ï,
    # LATIN CAPITAL LETTER ETH
    0xD0 => ?Ð,
    # LATIN CAPITAL LETTER N WITH TILDE
    0xD1 => ?Ñ,
    # LATIN CAPITAL LETTER O WITH GRAVE
    0xD2 => ?Ò,
    # LATIN CAPITAL LETTER O WITH ACUTE
    0xD3 => ?Ó,
    # LATIN CAPITAL LETTER O WITH CIRCUMFLEX
    0xD4 => ?Ô,
    # LATIN CAPITAL LETTER O WITH TILDE
    0xD5 => ?Õ,
    # LATIN CAPITAL LETTER O WITH DIAERESIS
    0xD6 => ?Ö,
    # MULTIPLICATION SIGN
    0xD7 => ?×,
    # LATIN CAPITAL LETTER O WITH STROKE
    0xD8 => ?Ø,
    # LATIN CAPITAL LETTER U WITH GRAVE
    0xD9 => ?Ù,
    # LATIN CAPITAL LETTER U WITH ACUTE
    0xDA => ?Ú,
    # LATIN CAPITAL LETTER U WITH CIRCUMFLEX
    0xDB => ?Û,
    # LATIN CAPITAL LETTER U WITH DIAERESIS
    0xDC => ?Ü,
    # LATIN CAPITAL LETTER Y WITH ACUTE
    0xDD => ?Ý,
    # LATIN CAPITAL LETTER THORN
    0xDE => ?Þ,
    # LATIN SMALL LETTER SHARP S
    0xDF => ?ß,
    # LATIN SMALL LETTER A WITH GRAVE
    0xE0 => ?à,
    # LATIN SMALL LETTER A WITH ACUTE
    0xE1 => ?á,
    # LATIN SMALL LETTER A WITH CIRCUMFLEX
    0xE2 => ?â,
    # LATIN SMALL LETTER A WITH TILDE
    0xE3 => ?ã,
    # LATIN SMALL LETTER A WITH DIAERESIS
    0xE4 => ?ä,
    # LATIN SMALL LETTER A WITH RING ABOVE
    0xE5 => ?å,
    # LATIN SMALL LETTER AE
    0xE6 => ?æ,
    # LATIN SMALL LETTER C WITH CEDILLA
    0xE7 => ?ç,
    # LATIN SMALL LETTER E WITH GRAVE
    0xE8 => ?è,
    # LATIN SMALL LETTER E WITH ACUTE
    0xE9 => ?é,
    # LATIN SMALL LETTER E WITH CIRCUMFLEX
    0xEA => ?ê,
    # LATIN SMALL LETTER E WITH DIAERESIS
    0xEB => ?ë,
    # LATIN SMALL LETTER I WITH GRAVE
    0xEC => ?ì,
    # LATIN SMALL LETTER I WITH ACUTE
    0xED => ?í,
    # LATIN SMALL LETTER I WITH CIRCUMFLEX
    0xEE => ?î,
    # LATIN SMALL LETTER I WITH DIAERESIS
    0xEF => ?ï,
    # LATIN SMALL LETTER ETH
    0xF0 => ?ð,
    # LATIN SMALL LETTER N WITH TILDE
    0xF1 => ?ñ,
    # LATIN SMALL LETTER O WITH GRAVE
    0xF2 => ?ò,
    # LATIN SMALL LETTER O WITH ACUTE
    0xF3 => ?ó,
    # LATIN SMALL LETTER O WITH CIRCUMFLEX
    0xF4 => ?ô,
    # LATIN SMALL LETTER O WITH TILDE
    0xF5 => ?õ,
    # LATIN SMALL LETTER O WITH DIAERESIS
    0xF6 => ?ö,
    # DIVISION SIGN
    0xF7 => ?÷,
    # LATIN SMALL LETTER O WITH STROKE
    0xF8 => ?ø,
    # LATIN SMALL LETTER U WITH GRAVE
    0xF9 => ?ù,
    # LATIN SMALL LETTER U WITH ACUTE
    0xFA => ?ú,
    # LATIN SMALL LETTER U WITH CIRCUMFLEX
    0xFB => ?û,
    # LATIN SMALL LETTER U WITH DIAERESIS
    0xFC => ?ü,
    # LATIN SMALL LETTER Y WITH ACUTE
    0xFD => ?ý,
    # LATIN SMALL LETTER THORN
    0xFE => ?þ,
    # LATIN SMALL LETTER Y WITH DIAERESIS
    0xFF => ?ÿ
  }

  # Map of character set names to their translation tables
  @charset_tables %{
    us_ascii: @us_ascii_map,
    uk: @uk_map,
    french: @french_map,
    german: @german_map,
    latin1: @latin1_map
    # Other character sets will be added as needed
  }

  @doc """
  Translates a character from the source character set to the target character set.
  Returns the translated character or the original if no translation exists.
  """
  @spec translate_char(char(), :us_ascii | :uk | :french | :german | :latin1) ::
          char()
  def translate_char(char, charset) do
    case Map.get(@charset_tables, charset) do
      nil -> char
      table -> Map.get(table, char, char)
    end
  end

  @doc """
  Translates a string from the source character set to the target character set.
  """
  @spec translate_string(
          String.t(),
          :us_ascii | :uk | :french | :german | :latin1
        ) :: String.t()
  def translate_string(string, charset) do
    string
    |> String.to_charlist()
    |> Enum.map(&translate_char(&1, charset))
    |> List.to_string()
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
