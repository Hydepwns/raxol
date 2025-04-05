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
    0x23 => ?£,
    # Other characters are the same as US ASCII
  }

  # French character set (G1)
  @french_map %{
    # French-specific characters
    0x23 => ?£,  # £ symbol
    0x40 => ?à,  # à
    0x5B => ?é,  # é
    0x5C => ?ê,  # ê
    0x5D => ?è,  # è
    0x5E => ?ë,  # ë
    0x5F => ?ï,  # ï
    0x60 => ?î,  # î
    0x7B => ?ù,  # ù
    0x7C => ?ô,  # ô
    0x7D => ?è,  # è
    0x7E => ?û,  # û
  }

  # German character set (G1)
  @german_map %{
    # German-specific characters
    0x5B => ?Ä,  # Ä
    0x5C => ?Ö,  # Ö
    0x5D => ?Ü,  # Ü
    0x5E => ?^,  # ^
    0x5F => ?_,  # _
    0x60 => ?`,  # `
    0x7B => ?ä,  # ä
    0x7C => ?ö,  # ö
    0x7D => ?ü,  # ü
    0x7E => ?ß,  # ß
  }

  # Latin-1 character set (ISO-8859-1)
  @latin1_map %{
    # Latin-1 specific characters (0xA0-0xFF)
    0xA0 => 32,      # NO-BREAK SPACE
    0xA1 => ?¡,      # INVERTED EXCLAMATION MARK
    0xA2 => ?¢,      # CENT SIGN
    0xA3 => ?£,      # POUND SIGN
    0xA4 => ?¤,      # CURRENCY SIGN
    0xA5 => ?¥,      # YEN SIGN
    0xA6 => ?¦,      # BROKEN BAR
    0xA7 => ?§,      # SECTION SIGN
    0xA8 => ?¨,      # DIAERESIS
    0xA9 => ?©,      # COPYRIGHT SIGN
    0xAA => ?ª,      # FEMININE ORDINAL INDICATOR
    0xAB => ?«,      # LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    0xAC => ?¬,      # NOT SIGN
    0xAD => 32,      # SOFT HYPHEN
    0xAE => ?®,      # REGISTERED SIGN
    0xAF => ?¯,      # MACRON
    0xB0 => ?°,      # DEGREE SIGN
    0xB1 => ?±,      # PLUS-MINUS SIGN
    0xB2 => ?²,      # SUPERSCRIPT TWO
    0xB3 => ?³,      # SUPERSCRIPT THREE
    0xB4 => ?´,      # ACUTE ACCENT
    0xB5 => ?µ,      # MICRO SIGN
    0xB6 => ?¶,      # PILCROW SIGN
    0xB7 => ?·,      # MIDDLE DOT
    0xB8 => ?¸,      # CEDILLA
    0xB9 => ?¹,      # SUPERSCRIPT ONE
    0xBA => ?º,      # MASCULINE ORDINAL INDICATOR
    0xBB => ?»,      # RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    0xBC => ?¼,      # VULGAR FRACTION ONE QUARTER
    0xBD => ?½,      # VULGAR FRACTION ONE HALF
    0xBE => ?¾,      # VULGAR FRACTION THREE QUARTERS
    0xBF => ?¿,      # INVERTED QUESTION MARK
    0xC0 => ?À,      # LATIN CAPITAL LETTER A WITH GRAVE
    0xC1 => ?Á,      # LATIN CAPITAL LETTER A WITH ACUTE
    0xC2 => ?Â,      # LATIN CAPITAL LETTER A WITH CIRCUMFLEX
    0xC3 => ?Ã,      # LATIN CAPITAL LETTER A WITH TILDE
    0xC4 => ?Ä,      # LATIN CAPITAL LETTER A WITH DIAERESIS
    0xC5 => ?Å,      # LATIN CAPITAL LETTER A WITH RING ABOVE
    0xC6 => ?Æ,      # LATIN CAPITAL LETTER AE
    0xC7 => ?Ç,      # LATIN CAPITAL LETTER C WITH CEDILLA
    0xC8 => ?È,      # LATIN CAPITAL LETTER E WITH GRAVE
    0xC9 => ?É,      # LATIN CAPITAL LETTER E WITH ACUTE
    0xCA => ?Ê,      # LATIN CAPITAL LETTER E WITH CIRCUMFLEX
    0xCB => ?Ë,      # LATIN CAPITAL LETTER E WITH DIAERESIS
    0xCC => ?Ì,      # LATIN CAPITAL LETTER I WITH GRAVE
    0xCD => ?Í,      # LATIN CAPITAL LETTER I WITH ACUTE
    0xCE => ?Î,      # LATIN CAPITAL LETTER I WITH CIRCUMFLEX
    0xCF => ?Ï,      # LATIN CAPITAL LETTER I WITH DIAERESIS
    0xD0 => ?Ð,      # LATIN CAPITAL LETTER ETH
    0xD1 => ?Ñ,      # LATIN CAPITAL LETTER N WITH TILDE
    0xD2 => ?Ò,      # LATIN CAPITAL LETTER O WITH GRAVE
    0xD3 => ?Ó,      # LATIN CAPITAL LETTER O WITH ACUTE
    0xD4 => ?Ô,      # LATIN CAPITAL LETTER O WITH CIRCUMFLEX
    0xD5 => ?Õ,      # LATIN CAPITAL LETTER O WITH TILDE
    0xD6 => ?Ö,      # LATIN CAPITAL LETTER O WITH DIAERESIS
    0xD7 => ?×,      # MULTIPLICATION SIGN
    0xD8 => ?Ø,      # LATIN CAPITAL LETTER O WITH STROKE
    0xD9 => ?Ù,      # LATIN CAPITAL LETTER U WITH GRAVE
    0xDA => ?Ú,      # LATIN CAPITAL LETTER U WITH ACUTE
    0xDB => ?Û,      # LATIN CAPITAL LETTER U WITH CIRCUMFLEX
    0xDC => ?Ü,      # LATIN CAPITAL LETTER U WITH DIAERESIS
    0xDD => ?Ý,      # LATIN CAPITAL LETTER Y WITH ACUTE
    0xDE => ?Þ,      # LATIN CAPITAL LETTER THORN
    0xDF => ?ß,      # LATIN SMALL LETTER SHARP S
    0xE0 => ?à,      # LATIN SMALL LETTER A WITH GRAVE
    0xE1 => ?á,      # LATIN SMALL LETTER A WITH ACUTE
    0xE2 => ?â,      # LATIN SMALL LETTER A WITH CIRCUMFLEX
    0xE3 => ?ã,      # LATIN SMALL LETTER A WITH TILDE
    0xE4 => ?ä,      # LATIN SMALL LETTER A WITH DIAERESIS
    0xE5 => ?å,      # LATIN SMALL LETTER A WITH RING ABOVE
    0xE6 => ?æ,      # LATIN SMALL LETTER AE
    0xE7 => ?ç,      # LATIN SMALL LETTER C WITH CEDILLA
    0xE8 => ?è,      # LATIN SMALL LETTER E WITH GRAVE
    0xE9 => ?é,      # LATIN SMALL LETTER E WITH ACUTE
    0xEA => ?ê,      # LATIN SMALL LETTER E WITH CIRCUMFLEX
    0xEB => ?ë,      # LATIN SMALL LETTER E WITH DIAERESIS
    0xEC => ?ì,      # LATIN SMALL LETTER I WITH GRAVE
    0xED => ?í,      # LATIN SMALL LETTER I WITH ACUTE
    0xEE => ?î,      # LATIN SMALL LETTER I WITH CIRCUMFLEX
    0xEF => ?ï,      # LATIN SMALL LETTER I WITH DIAERESIS
    0xF0 => ?ð,      # LATIN SMALL LETTER ETH
    0xF1 => ?ñ,      # LATIN SMALL LETTER N WITH TILDE
    0xF2 => ?ò,      # LATIN SMALL LETTER O WITH GRAVE
    0xF3 => ?ó,      # LATIN SMALL LETTER O WITH ACUTE
    0xF4 => ?ô,      # LATIN SMALL LETTER O WITH CIRCUMFLEX
    0xF5 => ?õ,      # LATIN SMALL LETTER O WITH TILDE
    0xF6 => ?ö,      # LATIN SMALL LETTER O WITH DIAERESIS
    0xF7 => ?÷,      # DIVISION SIGN
    0xF8 => ?ø,      # LATIN SMALL LETTER O WITH STROKE
    0xF9 => ?ù,      # LATIN SMALL LETTER U WITH GRAVE
    0xFA => ?ú,      # LATIN SMALL LETTER U WITH ACUTE
    0xFB => ?û,      # LATIN SMALL LETTER U WITH CIRCUMFLEX
    0xFC => ?ü,      # LATIN SMALL LETTER U WITH DIAERESIS
    0xFD => ?ý,      # LATIN SMALL LETTER Y WITH ACUTE
    0xFE => ?þ,      # LATIN SMALL LETTER THORN
    0xFF => ?ÿ,      # LATIN SMALL LETTER Y WITH DIAERESIS
  }

  # Map of character set names to their translation tables
  @charset_tables %{
    us_ascii: @us_ascii_map,
    uk: @uk_map,
    french: @french_map,
    german: @german_map,
    latin1: @latin1_map,
    # Other character sets will be added as needed
  }

  @doc """
  Translates a character from the source character set to the target character set.
  Returns the translated character or the original if no translation exists.
  """
  @spec translate_char(char(), :us_ascii | :uk | :french | :german | :latin1) :: char()
  def translate_char(char, charset) do
    case Map.get(@charset_tables, charset) do
      nil -> char
      table -> Map.get(table, char, char)
    end
  end

  @doc """
  Translates a string from the source character set to the target character set.
  """
  @spec translate_string(String.t(), :us_ascii | :uk | :french | :german | :latin1) :: String.t()
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
      0x00A0 => 32,  # NO-BREAK SPACE
      0x2013 => 45,  # EN DASH
      0x2014 => 45,  # EM DASH
      0x2018 => 39,  # LEFT SINGLE QUOTATION MARK
      0x2019 => 39,  # RIGHT SINGLE QUOTATION MARK
      0x201C => 34,  # LEFT DOUBLE QUOTATION MARK
      0x201D => 34,  # RIGHT DOUBLE QUOTATION MARK
      0x2026 => 46,  # HORIZONTAL ELLIPSIS
      0x2028 => 10,  # LINE SEPARATOR
      0x2029 => 10,  # PARAGRAPH SEPARATOR
      0x202F => 32,  # NARROW NO-BREAK SPACE
      0x205F => 32,  # MEDIUM MATHEMATICAL SPACE
      0x3000 => 32   # IDEOGRAPHIC SPACE
    }
  end
end 