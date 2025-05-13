defmodule Raxol.Terminal.CharacterHandling do
  @moduledoc """
  Handles wide character and bidirectional text support for the terminal emulator.

  This module provides functions for:
  - Determining character width (single, double, or variable width)
  - Handling bidirectional text rendering
  - Managing character combining
  - Supporting Unicode character properties
  """

  require Logger

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
      # CJK Unified Ideographs Extension F
      c when c >= 0x2CEB0 and c <= 0x2EBEF -> true
      # CJK Unified Ideographs Extension G
      c when c >= 0x30000 and c <= 0x3134F -> true
      # CJK Compatibility Ideographs
      c when c >= 0xF900 and c <= 0xFAFF -> true
      # Hangul Syllables
      c when c >= 0xAC00 and c <= 0xD7AF -> true
      # Fullwidth Forms
      c when c >= 0xFF01 and c <= 0xFF60 -> true
      # Fullwidth Forms (continued)
      c when c >= 0xFFE0 and c <= 0xFFE6 -> true
      # Emoji and other wide characters
      c when c >= 0x1F300 and c <= 0x1F9FF -> true
      # Emoji Components
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-A
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-B
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-C
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-D
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-E
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-F
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-G
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-H
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-I
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-J
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-K
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-L
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-M
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-N
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-O
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-P
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-Q
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-R
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-S
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-T
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-U
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-V
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-W
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-X
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-Y
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
      # Symbols and Pictographs Extended-Z
      c when c >= 0x1FA70 and c <= 0x1FAFF -> true
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
      # Empty string or grapheme returns width 1
      [] -> 1
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
      # Combining Half Marks
      c when c >= 0xFE20 and c <= 0xFE2F -> true
      # Combining Diacritical Marks Extended
      c when c >= 0x1AB0 and c <= 0x1AFF -> true
      # Combining Diacritical Marks Supplement
      c when c >= 0x1DC0 and c <= 0x1DFF -> true
      # Combining Diacritical Marks for Symbols
      c when c >= 0x20D0 and c <= 0x20FF -> true
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
      is_combining_char?(char) ->
        :COMBINING

      # Right-to-left scripts
      # Hebrew
      # Arabic
      # Arabic Supplement
      # Arabic Extended-A
      # Arabic Presentation Forms-A
      # Arabic Presentation Forms-B
      (char >= 0x0590 and char <= 0x05FF) or
        (char >= 0x0600 and char <= 0x06FF) or
        (char >= 0x0750 and char <= 0x077F) or
        (char >= 0x08A0 and char <= 0x08FF) or
        (char >= 0xFB50 and char <= 0xFDFF) or
          (char >= 0xFE70 and char <= 0xFEFF) ->
        :RTL

      # Left-to-right scripts (explicitly list common ranges)
      # Basic Latin Uppercase (A-Z)
      # Basic Latin Lowercase (a-z)
      # Latin-1 Supplement (common accented chars)
      # Latin Extended-A & B
      (char >= 0x0041 and char <= 0x005A) or
        (char >= 0x0061 and char <= 0x007A) or
        (char >= 0x00C0 and char <= 0x00FF) or
          (char >= 0x0100 and char <= 0x024F) ->
        :LTR

      # Treat digits and basic punctuation/space as LTR for simplicity here
      # (though some are technically neutral or European Number)
      # Digits 0-9
      # Space
      (char >= 0x0030 and char <= 0x0039) or
          char == 0x0020 ->
        :LTR

      # Default to Neutral for anything else (punctuation, symbols, etc.)
      true ->
        :NEUTRAL
    end
  end

  @doc """
  Processes a string for bidirectional text rendering.
  Returns a list of segments with their rendering order.
  """
  @spec process_bidi_text(String.t()) ::
          list({:LTR | :RTL | :NEUTRAL, String.t()})
  @dialyzer {:nowarn_function, process_bidi_text: 1}
  def process_bidi_text(string) do
    # Convert string to list of characters
    chars = String.to_charlist(string)

    # Group characters by their bidi type
    segments =
      Enum.reduce(chars, [], fn char, acc ->
        bidi_type = get_bidi_type(char)
        char_str = <<char::utf8>>

        case acc do
          [] ->
            [{bidi_type, char_str}]

          [{prev_type, prev_str} | rest] ->
            if prev_type == bidi_type do
              [{prev_type, prev_str <> char_str} | rest]
            else
              [{bidi_type, char_str}, {prev_type, prev_str} | rest]
            end
        end
      end)

    # Reverse to get correct order
    Enum.reverse(segments)
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
        # Append the character back as binary
        acc <> <<char::utf8>>
      )
    else
      {acc, <<char::utf8, rest::binary>>}
    end
  end
end
