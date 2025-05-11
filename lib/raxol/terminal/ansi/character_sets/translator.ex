defmodule Raxol.Terminal.ANSI.CharacterSets.Translator do
  @moduledoc """
  Handles character set translations and mappings.
  """

  @doc """
  Translates a character using the active character set.
  """
  def translate_char(codepoint, active_set, single_shift) do
    set = single_shift || active_set
    case set do
      :us_ascii -> codepoint
      :dec_special_graphics -> translate_dec_special_graphics(codepoint)
      :uk -> translate_uk(codepoint)
      :us -> translate_us(codepoint)
      :finnish -> translate_finnish(codepoint)
      :french -> translate_french(codepoint)
      :french_canadian -> translate_french_canadian(codepoint)
      :german -> translate_german(codepoint)
      :italian -> translate_italian(codepoint)
      :norwegian_danish -> translate_norwegian_danish(codepoint)
      :portuguese -> translate_portuguese(codepoint)
      :spanish -> translate_spanish(codepoint)
      :swedish -> translate_swedish(codepoint)
      :swiss -> translate_swiss(codepoint)
      _ -> codepoint
    end
  end

  @doc """
  Translates a string using the active character set.
  """
  def translate_string(string, active_set, single_shift) do
    string
    |> String.to_charlist()
    |> Enum.map(&translate_char(&1, active_set, single_shift))
    |> List.to_string()
  end

  # DEC Special Graphics character set translations
  defp translate_dec_special_graphics(codepoint) do
    case codepoint do
      ?_ -> ?─  # Horizontal line
      ?` -> ?◆  # Diamond
      ?a -> ?▒  # Checkerboard
      ?b -> ?␉  # Tab
      ?c -> ?␌  # Form feed
      ?d -> ?␍  # Carriage return
      ?e -> ?␊  # Line feed
      ?f -> ?°  # Degree symbol
      ?g -> ?±  # Plus/minus
      ?h -> ?␤  # New line
      ?i -> ?␋  # Vertical tab
      ?j -> ?┘  # Lower right corner
      ?k -> ?┐  # Upper right corner
      ?l -> ?┌  # Upper left corner
      ?m -> ?└  # Lower left corner
      ?n -> ?┼  # Cross
      ?o -> ?⎺  # Scan line 1
      ?p -> ?⎻  # Scan line 3
      ?q -> ?─  # Horizontal line
      ?r -> ?⎼  # Scan line 7
      ?s -> ?⎽  # Scan line 9
      ?t -> ?├  # Left tee
      ?u -> ?┤  # Right tee
      ?v -> ?┴  # Bottom tee
      ?w -> ?┬  # Top tee
      ?x -> ?│  # Vertical line
      ?y -> ?≤  # Less than or equal
      ?z -> ?≥  # Greater than or equal
      ?{ -> ?π  # Pi
      ?| -> ?≠  # Not equal
      ?} -> ?£  # Pound sterling
      ?~ -> ?·  # Bullet
      _ -> codepoint
    end
  end

  # UK character set translations
  defp translate_uk(codepoint) do
    case codepoint do
      ?# -> ?£  # Pound sterling
      _ -> codepoint
    end
  end

  # US character set translations (default ASCII)
  defp translate_us(codepoint), do: codepoint

  # Finnish character set translations
  defp translate_finnish(codepoint) do
    case codepoint do
      ?[ -> ?Ä  # A with umlaut
      ?\\ -> ?Ö  # O with umlaut
      ?] -> ?Å  # A with ring
      ?{ -> ?ä  # a with umlaut
      ?| -> ?ö  # o with umlaut
      ?} -> ?å  # a with ring
      _ -> codepoint
    end
  end

  # French character set translations
  defp translate_french(codepoint) do
    case codepoint do
      ?# -> ?£  # Pound sterling
      ?@ -> ?à  # a with grave
      ?[ -> ?°  # Degree
      ?\\ -> ?ç  # c with cedilla
      ?] -> ?§  # Section
      ?{ -> ?é  # e with acute
      ?| -> ?ù  # u with grave
      ?} -> ?è  # e with grave
      _ -> codepoint
    end
  end

  # French Canadian character set translations
  defp translate_french_canadian(codepoint) do
    case codepoint do
      ?# -> ?é  # e with acute
      ?@ -> ?à  # a with grave
      ?[ -> ?â  # a with circumflex
      ?\\ -> ?ç  # c with cedilla
      ?] -> ?ê  # e with circumflex
      ?{ -> ?î  # i with circumflex
      ?| -> ?ô  # o with circumflex
      ?} -> ?û  # u with circumflex
      _ -> codepoint
    end
  end

  # German character set translations
  defp translate_german(codepoint) do
    case codepoint do
      ?# -> ?§  # Section
      ?@ -> ?§  # Section
      ?[ -> ?Ä  # A with umlaut
      ?\\ -> ?Ö  # O with umlaut
      ?] -> ?Ü  # U with umlaut
      ?{ -> ?ä  # a with umlaut
      ?| -> ?ö  # o with umlaut
      ?} -> ?ü  # u with umlaut
      ?~ -> ?ß  # Sharp s
      _ -> codepoint
    end
  end

  # Italian character set translations
  defp translate_italian(codepoint) do
    case codepoint do
      ?# -> ?£  # Pound sterling
      ?@ -> ?§  # Section
      ?[ -> ?°  # Degree
      ?\\ -> ?ç  # c with cedilla
      ?] -> ?é  # e with acute
      ?{ -> ?ù  # u with grave
      ?| -> ?ò  # o with grave
      ?} -> ?è  # e with grave
      _ -> codepoint
    end
  end

  # Norwegian/Danish character set translations
  defp translate_norwegian_danish(codepoint) do
    case codepoint do
      ?# -> ?#  # Number sign
      ?@ -> ?@  # Commercial at
      ?[ -> ?Æ  # AE
      ?\\ -> ?Ø  # O with stroke
      ?] -> ?Å  # A with ring
      ?{ -> ?æ  # ae
      ?| -> ?ø  # o with stroke
      ?} -> ?å  # a with ring
      ?~ -> ?~  # Tilde
      _ -> codepoint
    end
  end

  # Portuguese character set translations
  defp translate_portuguese(codepoint) do
    case codepoint do
      ?# -> ?£  # Pound sterling
      ?@ -> ?@  # Commercial at
      ?[ -> ?Ã  # A with tilde
      ?\\ -> ?Ç  # C with cedilla
      ?] -> ?É  # E with acute
      ?{ -> ?ã  # a with tilde
      ?| -> ?ç  # c with cedilla
      ?} -> ?é  # e with acute
      _ -> codepoint
    end
  end

  # Spanish character set translations
  defp translate_spanish(codepoint) do
    case codepoint do
      ?# -> ?ñ  # n with tilde
      ?@ -> ?¿  # Inverted question mark
      ?[ -> ?¡  # Inverted exclamation mark
      ?\\ -> ?Ñ  # N with tilde
      ?] -> ?§  # Section
      ?{ -> ?á  # a with acute
      ?| -> ?í  # i with acute
      ?} -> ?ó  # o with acute
      _ -> codepoint
    end
  end

  # Swedish character set translations
  defp translate_swedish(codepoint) do
    case codepoint do
      ?# -> ?#  # Number sign
      ?@ -> ?@  # Commercial at
      ?[ -> ?Ä  # A with umlaut
      ?\\ -> ?Ö  # O with umlaut
      ?] -> ?Å  # A with ring
      ?{ -> ?ä  # a with umlaut
      ?| -> ?ö  # o with umlaut
      ?} -> ?å  # a with ring
      ?~ -> ?~  # Tilde
      _ -> codepoint
    end
  end

  # Swiss character set translations
  defp translate_swiss(codepoint) do
    case codepoint do
      ?# -> ?ù  # u with grave
      ?@ -> ?à  # a with grave
      ?[ -> ?é  # e with acute
      ?\\ -> ?ç  # c with cedilla
      ?] -> ?ê  # e with circumflex
      ?{ -> ?î  # i with circumflex
      ?| -> ?è  # e with grave
      ?} -> ?ô  # o with circumflex
      _ -> codepoint
    end
  end
end
