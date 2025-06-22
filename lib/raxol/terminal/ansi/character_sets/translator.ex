defmodule Raxol.Terminal.ANSI.CharacterSets.Translator do
  @moduledoc """
  Handles character set translations and mappings.
  """

  import Raxol.Guards

  @doc """
  Translates a character using the active character set.
  """
  def translate_char(codepoint, active_set, single_shift)
      when integer?(codepoint) do
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

  def translate_char(other, _active_set, _single_shift) do
    # Optionally log a warning here
    other
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
  defp translate_dec_special_graphics(codepoint) when integer?(codepoint) do
    case codepoint do
      # Horizontal line
      ?_ -> ?─
      # Diamond
      ?` -> ?◆
      # Checkerboard
      ?a -> ?▒
      # Tab
      ?b -> ?␉
      # Form feed
      ?c -> ?␌
      # Carriage return
      ?d -> ?␍
      # Line feed
      ?e -> ?␊
      # Degree symbol
      ?f -> ?°
      # Plus/minus
      ?g -> ?±
      # New line
      ?h -> ?␤
      # Vertical tab
      ?i -> ?␋
      # Lower right corner
      ?j -> ?┘
      # Upper right corner
      ?k -> ?┐
      # Upper left corner
      ?l -> ?┌
      # Lower left corner
      ?m -> ?└
      # Cross
      ?n -> ?┼
      # Scan line 1
      ?o -> ?⎺
      # Scan line 3
      ?p -> ?⎻
      # Horizontal line
      ?q -> ?─
      # Scan line 7
      ?r -> ?⎼
      # Scan line 9
      ?s -> ?⎽
      # Left tee
      ?t -> ?├
      # Right tee
      ?u -> ?┤
      # Bottom tee
      ?v -> ?┴
      # Top tee
      ?w -> ?┬
      # Vertical line
      ?x -> ?│
      # Less than or equal
      ?y -> ?≤
      # Greater than or equal
      ?z -> ?≥
      # Pi
      ?{ -> ?π
      # Not equal
      ?| -> ?≠
      # Pound sterling
      ?} -> ?£
      # Bullet
      ?~ -> ?·
      _ -> codepoint
    end
  end

  defp translate_dec_special_graphics(other) do
    other
  end

  # UK character set translations
  defp translate_uk(codepoint) when integer?(codepoint) do
    case codepoint do
      # Pound sterling
      ?# -> ?£
      _ -> codepoint
    end
  end

  defp translate_uk(other) do
    other
  end

  # US character set translations (default ASCII)
  defp translate_us(codepoint) when integer?(codepoint), do: codepoint
  defp translate_us(other), do: other

  # Finnish character set translations
  defp translate_finnish(codepoint) when integer?(codepoint) do
    case codepoint do
      # A with umlaut
      ?[ -> ?Ä
      # O with umlaut
      ?\\ -> ?Ö
      # A with ring
      ?] -> ?Å
      # a with umlaut
      ?{ -> ?ä
      # o with umlaut
      ?| -> ?ö
      # a with ring
      ?} -> ?å
      _ -> codepoint
    end
  end

  defp translate_finnish(other) do
    other
  end

  # French character set translations
  defp translate_french(codepoint) when integer?(codepoint) do
    case codepoint do
      # Pound sterling
      ?# -> ?£
      # a with grave
      ?@ -> ?à
      # Degree
      ?[ -> ?°
      # c with cedilla
      ?\\ -> ?ç
      # Section
      ?] -> ?§
      # e with acute
      ?{ -> ?é
      # u with grave
      ?| -> ?ù
      # e with grave
      ?} -> ?è
      _ -> codepoint
    end
  end

  defp translate_french(other) do
    other
  end

  # French Canadian character set translations
  defp translate_french_canadian(codepoint) when integer?(codepoint) do
    case codepoint do
      # e with acute
      ?# -> ?é
      # a with grave
      ?@ -> ?à
      # a with circumflex
      ?[ -> ?â
      # c with cedilla
      ?\\ -> ?ç
      # e with circumflex
      ?] -> ?ê
      # i with circumflex
      ?{ -> ?î
      # o with circumflex
      ?| -> ?ô
      # u with circumflex
      ?} -> ?û
      _ -> codepoint
    end
  end

  defp translate_french_canadian(other) do
    other
  end

  # German character set translations
  defp translate_german(codepoint) when integer?(codepoint) do
    case codepoint do
      # Section
      ?# -> ?§
      # Section
      ?@ -> ?§
      # A with umlaut
      ?[ -> ?Ä
      # O with umlaut
      ?\\ -> ?Ö
      # U with umlaut
      ?] -> ?Ü
      # a with umlaut
      ?{ -> ?ä
      # o with umlaut
      ?| -> ?ö
      # u with umlaut
      ?} -> ?ü
      # Sharp s
      ?~ -> ?ß
      _ -> codepoint
    end
  end

  defp translate_german(other) do
    other
  end

  # Italian character set translations
  defp translate_italian(codepoint) when integer?(codepoint) do
    case codepoint do
      # Pound sterling
      ?# -> ?£
      # Section
      ?@ -> ?§
      # Degree
      ?[ -> ?°
      # c with cedilla
      ?\\ -> ?ç
      # e with acute
      ?] -> ?é
      # u with grave
      ?{ -> ?ù
      # o with grave
      ?| -> ?ò
      # e with grave
      ?} -> ?è
      _ -> codepoint
    end
  end

  defp translate_italian(other) do
    other
  end

  # Norwegian/Danish character set translations
  defp translate_norwegian_danish(codepoint) when integer?(codepoint) do
    case codepoint do
      # Number sign
      ?# -> ?#
      # Commercial at
      ?@ -> ?@
      # AE
      ?[ -> ?Æ
      # O with stroke
      ?\\ -> ?Ø
      # A with ring
      ?] -> ?Å
      # ae
      ?{ -> ?æ
      # o with stroke
      ?| -> ?ø
      # a with ring
      ?} -> ?å
      # Tilde
      ?~ -> ?~
      _ -> codepoint
    end
  end

  defp translate_norwegian_danish(other) do
    other
  end

  # Portuguese character set translations
  defp translate_portuguese(codepoint) when integer?(codepoint) do
    case codepoint do
      # Pound sterling
      ?# -> ?£
      # Commercial at
      ?@ -> ?@
      # A with tilde
      ?[ -> ?Ã
      # C with cedilla
      ?\\ -> ?Ç
      # E with acute
      ?] -> ?É
      # a with tilde
      ?{ -> ?ã
      # c with cedilla
      ?| -> ?ç
      # e with acute
      ?} -> ?é
      _ -> codepoint
    end
  end

  defp translate_portuguese(other) do
    other
  end

  # Spanish character set translations
  defp translate_spanish(codepoint) when integer?(codepoint) do
    case codepoint do
      # n with tilde
      ?# -> ?ñ
      # Inverted question mark
      ?@ -> ?¿
      # Inverted exclamation mark
      ?[ -> ?¡
      # N with tilde
      ?\\ -> ?Ñ
      # Section
      ?] -> ?§
      # a with acute
      ?{ -> ?á
      # i with acute
      ?| -> ?í
      # o with acute
      ?} -> ?ó
      _ -> codepoint
    end
  end

  defp translate_spanish(other) do
    other
  end

  # Swedish character set translations
  defp translate_swedish(codepoint) when integer?(codepoint) do
    case codepoint do
      # Number sign
      ?# -> ?#
      # Commercial at
      ?@ -> ?@
      # A with umlaut
      ?[ -> ?Ä
      # O with umlaut
      ?\\ -> ?Ö
      # A with ring
      ?] -> ?Å
      # a with umlaut
      ?{ -> ?ä
      # o with umlaut
      ?| -> ?ö
      # a with ring
      ?} -> ?å
      # Tilde
      ?~ -> ?~
      _ -> codepoint
    end
  end

  defp translate_swedish(other) do
    other
  end

  # Swiss character set translations
  defp translate_swiss(codepoint) when integer?(codepoint) do
    case codepoint do
      # u with grave
      ?# -> ?ù
      # a with grave
      ?@ -> ?à
      # e with acute
      ?[ -> ?é
      # c with cedilla
      ?\\ -> ?ç
      # e with circumflex
      ?] -> ?ê
      # i with circumflex
      ?{ -> ?î
      # e with grave
      ?| -> ?è
      # o with circumflex
      ?} -> ?ô
      _ -> codepoint
    end
  end

  defp translate_swiss(other) do
    other
  end
end
