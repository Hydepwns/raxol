defmodule Raxol.Terminal.CharacterSets.Translator do
  @moduledoc """
  Handles translation between different character sets in the terminal.
  """

  require Logger

  @doc """
  Translates a character from one character set to another.
  """
  def translate_char(char, from_charset, to_charset) do
    try do
      # Get the translation table for the source charset
      from_table = get_charset_table(from_charset)
      to_table = get_charset_table(to_charset)

      # First translate from source charset to Unicode
      unicode_char = from_table[char] || char

      # Then translate from Unicode to target charset
      to_table[unicode_char] || unicode_char
    rescue
      e ->
        Logger.warning("Character translation failed: #{inspect(e)}")
        char
    end
  end

  @doc """
  Translates a string between character sets.
  """
  def translate_string(string, from_charset, to_charset) do
    string
    |> String.to_charlist()
    |> Enum.map(&translate_char(&1, from_charset, to_charset))
    |> List.to_string()
  end

  @doc """
  Gets the translation table for a character set.
  """
  def get_charset_table(charset) do
    case charset do
      :us_ascii -> Raxol.Terminal.ANSI.CharacterTranslations.us_ascii()
      :uk -> Raxol.Terminal.ANSI.CharacterTranslations.uk()
      :french -> Raxol.Terminal.ANSI.CharacterTranslations.french()
      :german -> Raxol.Terminal.ANSI.CharacterTranslations.german()
      :latin1 -> Raxol.Terminal.ANSI.CharacterTranslations.latin1()
      :dec_special -> Raxol.Terminal.ANSI.CharacterTranslations.dec_special()
      :dec_supplementary -> Raxol.Terminal.ANSI.CharacterTranslations.dec_supplementary()
      :dec_technical -> Raxol.Terminal.ANSI.CharacterTranslations.dec_technical()
      :dec_supplementary_graphics -> Raxol.Terminal.ANSI.CharacterTranslations.dec_supplementary_graphics()
      _ -> %{}
    end
  end

  @doc """
  Checks if a character set is supported.
  """
  def supported_charset?(charset) do
    charset in [
      :us_ascii,
      :uk,
      :french,
      :german,
      :latin1,
      :dec_special,
      :dec_supplementary,
      :dec_technical,
      :dec_supplementary_graphics
    ]
  end

  @doc """
  Gets the default character set for a given region.
  """
  def get_default_charset(region) do
    case region do
      :us -> :us_ascii
      :uk -> :uk
      :france -> :french
      :germany -> :german
      :western_europe -> :latin1
      _ -> :us_ascii
    end
  end
end
