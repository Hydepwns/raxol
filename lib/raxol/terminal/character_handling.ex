defmodule Raxol.Terminal.CharacterHandling do
  @moduledoc """
  Handles wide character and bidirectional text support for the terminal emulator.

  This module provides functions for:
  - Determining character width (single, double, or variable width)
  - Handling bidirectional text rendering
  - Managing character combining
  - Supporting Unicode character properties
  """

  @doc """
  Determines if a character is a wide character (takes up two cells).
  """
  @spec is_wide_char?(char()) :: boolean()
  def is_wide_char?(char) do
    # Unicode ranges for wide characters
    case char do
      # CJK Unified Ideographs
      c when c >= 0x4E00 and c <= 0x9FFF -> true
      # CJK Unified Ideographs Extension A
      c when c >= 0x3400 and c <= 0x4DBF -> true
      # CJK Unified Ideographs Extension B
      c when c >= 0x20000 and c <= 0x2A6DF -> true
      # CJK Unified Ideographs Extension C
      c when c >= 0x2A700 and c <= 0x2B73F -> true
      # CJK Unified Ideographs Extension D
      c when c >= 0x2B740 and c <= 0x2B81F -> true
      # CJK Unified Ideographs Extension E
      c when c >= 0x2B820 and c <= 0x2CEAF -> true
      # CJK Compatibility Ideographs
      c when c >= 0xF900 and c <= 0xFAFF -> true
      # Hangul Syllables
      c when c >= 0xAC00 and c <= 0xD7AF -> true
      # Fullwidth Forms
      c when c >= 0xFF01 and c <= 0xFF60 -> true
      # Emoji and other wide characters
      c when c >= 0x1F300 and c <= 0x1F9FF -> true
      _ -> false
    end
  end

  @doc """
  Gets the width of a character in terminal cells.
  Returns 1 for narrow characters, 2 for wide characters.
  """
  @spec get_char_width(char()) :: 1 | 2
  def get_char_width(char) do
    if is_wide_char?(char), do: 2, else: 1
  end

  @doc """
  Determines if a character is a combining character.
  """
  @spec is_combining_char?(char()) :: boolean()
  def is_combining_char?(char) do
    # Unicode ranges for combining characters
    case char do
      # Combining Diacritical Marks
      c when c >= 0x0300 and c <= 0x036F -> true
      # Combining Diacritical Marks Extended
      c when c >= 0x1AB0 and c <= 0x1AFF -> true
      # Combining Diacritical Marks Supplement
      c when c >= 0x1DC0 and c <= 0x1DFF -> true
      # Combining Diacritical Marks for Symbols
      c when c >= 0x20D0 and c <= 0x20FF -> true
      _ -> false
    end
  end

  @doc """
  Determines the bidirectional character type.
  Returns :LTR, :RTL, :NEUTRAL, or :COMBINING.
  """
  @spec get_bidi_type(char()) :: :LTR | :RTL | :NEUTRAL | :COMBINING
  def get_bidi_type(char) do
    cond do
      is_combining_char?(char) -> :COMBINING
      # Right-to-left scripts
      char >= 0x0590 and char <= 0x05FF -> :RTL  # Hebrew
      char >= 0x0600 and char <= 0x06FF -> :RTL  # Arabic
      char >= 0x0750 and char <= 0x077F -> :RTL  # Arabic Supplement
      char >= 0x08A0 and char <= 0x08FF -> :RTL  # Arabic Extended-A
      char >= 0xFB50 and char <= 0xFDFF -> :RTL  # Arabic Presentation Forms-A
      char >= 0xFE70 and char <= 0xFEFF -> :RTL  # Arabic Presentation Forms-B
      # Left-to-right scripts (most Latin-based scripts)
      char >= 0x0000 and char <= 0x007F -> :LTR  # Basic Latin
      char >= 0x0080 and char <= 0x00FF -> :LTR  # Latin-1 Supplement
      char >= 0x0100 and char <= 0x017F -> :LTR  # Latin Extended-A
      char >= 0x0180 and char <= 0x024F -> :LTR  # Latin Extended-B
      # Neutral characters (spaces, punctuation, etc.)
      true -> :NEUTRAL
    end
  end

  @doc """
  Processes a string for bidirectional text rendering.
  Returns a list of segments with their rendering order.
  """
  @spec process_bidi_text(String.t()) :: list({:LTR | :RTL, String.t()})
  def process_bidi_text(text) do
    text
    |> String.graphemes()
    |> Enum.filter(&(&1 != ""))
    |> Enum.reduce([], fn char, acc ->
      bidi_type = get_bidi_type(String.first(char))
      case acc do
        [{type, segment} | rest] when type == bidi_type ->
          [{type, segment <> char} | rest]
        _ ->
          [{bidi_type, char} | acc]
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Gets the effective width of a string, taking into account wide characters.
  """
  @spec get_string_width(String.t()) :: non_neg_integer()
  def get_string_width(string) do
    string
    |> String.graphemes()
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&get_char_width(String.first(&1)))
    |> Enum.sum()
  end

  @doc """
  Splits a string at a given width, respecting wide characters.
  """
  @spec split_at_width(String.t(), non_neg_integer()) :: {String.t(), String.t()}
  def split_at_width(string, width) do
    {before_text, remaining} = do_split_at_width(string, width, 0, "")
    {before_text, remaining}
  end

  defp do_split_at_width("", _width, _current_width, acc) do
    {acc, ""}
  end

  defp do_split_at_width(<<char::utf8, rest::binary>>, width, current_width, acc) do
    char_width = get_char_width(char)
    if current_width + char_width <= width do
      do_split_at_width(rest, width, current_width + char_width, acc <> <<char::utf8>>)
    else
      {acc, <<char::utf8, rest::binary>>}
    end
  end
end
