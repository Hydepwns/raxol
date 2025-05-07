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
  Determine the display width of a given character code point or string.
  """
  @spec get_char_width(codepoint :: integer() | String.t()) :: 1 | 2
  def get_char_width(codepoint) when is_integer(codepoint) do
    if is_wide_char?(codepoint), do: 2, else: 1
  end

  def get_char_width(str) when is_binary(str) do
    case String.to_charlist(str) do
      [cp | _] -> get_char_width(cp)
      [] -> 1  # Empty string or grapheme returns width 1
    end
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
  @dialyzer {:nowarn_function, get_bidi_type: 1}
  def get_bidi_type(char) do
    cond do
      is_combining_char?(char) -> :COMBINING
      # Right-to-left scripts
      (char >= 0x0590 and char <= 0x05FF) or # Hebrew
      (char >= 0x0600 and char <= 0x06FF) or # Arabic
      (char >= 0x0750 and char <= 0x077F) or # Arabic Supplement
      (char >= 0x08A0 and char <= 0x08FF) or # Arabic Extended-A
      (char >= 0xFB50 and char <= 0xFDFF) or # Arabic Presentation Forms-A
      (char >= 0xFE70 and char <= 0xFEFF) -> :RTL # Arabic Presentation Forms-B

      # Left-to-right scripts (explicitly list common ranges)
      (char >= 0x0041 and char <= 0x005A) or # Basic Latin Uppercase (A-Z)
      (char >= 0x0061 and char <= 0x007A) or # Basic Latin Lowercase (a-z)
      (char >= 0x00C0 and char <= 0x00FF) or # Latin-1 Supplement (common accented chars)
      (char >= 0x0100 and char <= 0x024F) -> :LTR # Latin Extended-A & B

      # Treat digits and basic punctuation/space as LTR for simplicity here
      # (though some are technically neutral or European Number)
      (char >= 0x0030 and char <= 0x0039) or # Digits 0-9
       char == 0x0020 -> :LTR # Space

      # Default to Neutral for anything else (punctuation, symbols, etc.)
      true -> :NEUTRAL
    end
  end

  @doc """
  Processes a string for bidirectional text rendering.
  Returns a list of segments with their rendering order.
  WARNING: Simplified implementation.
  """
  @spec process_bidi_text(String.t()) ::
          list({:LTR | :RTL | :NEUTRAL, String.t()})
  @dialyzer {:nowarn_function, process_bidi_text: 1}
  def process_bidi_text(text) do
    # Simplified BIDI processing - handles basic LTR/RTL grouping and RLO (U+202E)
    initial_acc = {[], false} # {list_of_segments, in_rtl_override_flag}

    {final_segments, _} =
      text
      |> String.graphemes()
      |> Enum.filter(&(&1 != ""))
      |> Enum.reduce(initial_acc, fn grapheme, {current_segments, in_rtl} ->
          codepoint = String.first(grapheme)

          case codepoint do
            # Start RTL override
            0x202E -> {current_segments, true}

            # Add LRO/PDF handling here if needed
            # 0x202D -> {current_segments, false} # LRO
            # 0x202C -> {current_segments, false} # PDF

            _ -> # Process normal grapheme
              inherent_type = if is_nil(codepoint), do: :NEUTRAL, else: get_bidi_type(codepoint)
              current_type = if in_rtl, do: :RTL, else: inherent_type

              case current_segments do
                 # Append to last segment if type matches
                [{type, segment} | rest] when type == current_type ->
                   {[{type, segment <> grapheme} | rest], in_rtl}
                 # Start new segment
                _ ->
                   {[{current_type, grapheme} | current_segments], in_rtl}
              end
          end
      end)

    Enum.reverse(final_segments)
  end

  @doc """
  Gets the effective width of a string, taking into account wide characters
  and ignoring combining characters.
  """
  @spec get_string_width(String.t()) :: non_neg_integer()
  def get_string_width(string) do
    string
    |> String.graphemes()
    # Use the corrected get_char_width for each grapheme
    |> Enum.map(&get_char_width/1)
    |> Enum.sum()
  end

  @doc """
  Splits a string at a given width, respecting wide characters.
  """
  @spec split_at_width(String.t(), non_neg_integer()) ::
          {String.t(), String.t()}
  def split_at_width(string, width) do
    {before_text, remaining} = do_split_at_width(string, width, 0, "")
    {before_text, remaining}
  end

  defp do_split_at_width("", _width, _current_width, acc) do
    {acc, ""}
  end

  defp do_split_at_width(
         <<char::utf8, rest::binary>>,
         width,
         current_width,
         acc
       ) do
    # Pass the integer character codepoint directly
    char_width = get_char_width(char)

    if current_width + char_width <= width do
      do_split_at_width(
        rest,
        width,
        current_width + char_width,
        acc <> <<char::utf8>> # Append the character back as binary
      )
    else
      {acc, <<char::utf8, rest::binary>>}
    end
  end
end
