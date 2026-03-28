defmodule Raxol.Terminal.Unicode do
  @moduledoc """
  Unicode handling utilities for terminal rendering.

  Provides functions for determining character display widths,
  handling combining characters, and normalizing Unicode text
  for terminal display.

  ## Display Widths

  Unicode characters have varying display widths in terminals:
  - Most ASCII and Latin characters are "narrow" (width 1)
  - CJK ideographs are "wide" (width 2)
  - Combining characters have width 0
  - Some emoji are wide (width 2)

  ## Example

      iex> Raxol.Terminal.Unicode.display_width("Hello")
      5

      iex> Raxol.Terminal.Unicode.display_width("Hello")
      10

      iex> Raxol.Terminal.Unicode.char_width(?a)
      1
  """

  @doc """
  Calculate the display width of a string in terminal columns.

  ## Example

      iex> Raxol.Terminal.Unicode.display_width("Hello")
      5
  """
  @spec display_width(String.t()) :: non_neg_integer()
  def display_width(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> Enum.reduce(0, fn char, acc -> acc + char_width(char) end)
  end

  @doc """
  Get the display width of a single character.

  Returns:
  - 0 for combining characters and zero-width characters
  - 1 for narrow characters (ASCII, Latin, etc.)
  - 2 for wide characters (CJK, some emoji)

  ## Example

      iex> Raxol.Terminal.Unicode.char_width(?A)
      1
  """
  @spec char_width(char()) :: 0 | 1 | 2
  def char_width(char) when is_integer(char) do
    cond do
      # Control characters
      char < 32 -> 0
      # DEL
      char == 127 -> 0
      # C1 control characters
      char >= 0x80 and char < 0xA0 -> 0
      # Combining diacritical marks
      combining_char?(char) -> 0
      # Zero-width characters
      zero_width_char?(char) -> 0
      # Wide characters (CJK, etc.)
      wide_char?(char) -> 2
      # Default: narrow
      true -> 1
    end
  end

  @doc """
  Check if a character is a combining character (zero display width).

  ## Example

      iex> Raxol.Terminal.Unicode.combining_char?(0x0301)  # Combining acute accent
      true
  """
  @spec combining_char?(char()) :: boolean()
  def combining_char?(char) when is_integer(char) do
    # Combining Diacritical Marks
    # Combining Diacritical Marks Extended
    # Combining Diacritical Marks Supplement
    # Combining Diacritical Marks for Symbols
    # Combining Half Marks
    (char >= 0x0300 and char <= 0x036F) or
      (char >= 0x1AB0 and char <= 0x1AFF) or
      (char >= 0x1DC0 and char <= 0x1DFF) or
      (char >= 0x20D0 and char <= 0x20FF) or
      (char >= 0xFE20 and char <= 0xFE2F)
  end

  @doc """
  Check if a character is a zero-width character.

  ## Example

      iex> Raxol.Terminal.Unicode.zero_width_char?(0x200B)  # Zero-width space
      true
  """
  @spec zero_width_char?(char()) :: boolean()
  def zero_width_char?(char) when is_integer(char) do
    char in [
      # Zero-width space
      0x200B,
      # Zero-width non-joiner
      0x200C,
      # Zero-width joiner
      0x200D,
      # Word joiner
      0x2060,
      # Zero-width no-break space (BOM)
      0xFEFF,
      # Soft hyphen
      0x00AD
    ]
  end

  @doc """
  Check if a character is a wide character (display width 2).

  ## Example

      iex> Raxol.Terminal.Unicode.wide_char?(0x4E00)  # CJK Unified Ideograph
      true
  """
  @spec wide_char?(char()) :: boolean()
  def wide_char?(char) when is_integer(char) do
    # CJK Unified Ideographs
    # CJK Unified Ideographs Extension A
    # CJK Unified Ideographs Extension B-F
    # CJK Compatibility Ideographs
    # Hangul Syllables
    # Hangul Jamo
    # Fullwidth Forms
    # Wide emoji (simplified range)
    (char >= 0x4E00 and char <= 0x9FFF) or
      (char >= 0x3400 and char <= 0x4DBF) or
      (char >= 0x20000 and char <= 0x2CEAF) or
      (char >= 0xF900 and char <= 0xFAFF) or
      (char >= 0xAC00 and char <= 0xD7AF) or
      (char >= 0x1100 and char <= 0x11FF) or
      (char >= 0xFF00 and char <= 0xFF60) or
      (char >= 0xFFE0 and char <= 0xFFE6) or
      (char >= 0x1F300 and char <= 0x1F9FF)
  end

  @doc """
  Truncate a string to fit within a given display width.

  Returns a tuple of {truncated_string, actual_width}.

  ## Options

    - `:ellipsis` - String to append if truncated (default: "...")
    - `:preserve_words` - Try to break on word boundaries (default: false)

  ## Example

      iex> Raxol.Terminal.Unicode.truncate("Hello World", 8)
      {"Hello...", 8}
  """
  @spec truncate(String.t(), pos_integer(), keyword()) ::
          {String.t(), non_neg_integer()}
  def truncate(string, max_width, opts \\ [])
      when is_binary(string) and max_width > 0 do
    ellipsis = Keyword.get(opts, :ellipsis, "...")
    ellipsis_width = display_width(ellipsis)

    current_width = display_width(string)

    cond do
      current_width <= max_width ->
        {string, current_width}

      max_width <= ellipsis_width ->
        truncated = String.slice(ellipsis, 0, max_width)
        {truncated, display_width(truncated)}

      true ->
        target_width = max_width - ellipsis_width
        {truncated, width} = truncate_to_width(string, target_width)
        {truncated <> ellipsis, width + ellipsis_width}
    end
  end

  @doc """
  Pad a string to a given display width.

  ## Options

    - `:direction` - :left, :right, or :center (default: :right)
    - `:pad_char` - Character to use for padding (default: " ")

  ## Example

      iex> Raxol.Terminal.Unicode.pad("Hi", 5)
      "Hi   "

      iex> Raxol.Terminal.Unicode.pad("Hi", 5, direction: :left)
      "   Hi"
  """
  @spec pad(String.t(), pos_integer(), keyword()) :: String.t()
  def pad(string, width, opts \\ []) when is_binary(string) and width > 0 do
    direction = Keyword.get(opts, :direction, :right)
    pad_char = Keyword.get(opts, :pad_char, " ")

    current_width = display_width(string)
    padding_needed = max(0, width - current_width)

    case direction do
      :right ->
        string <> String.duplicate(pad_char, padding_needed)

      :left ->
        String.duplicate(pad_char, padding_needed) <> string

      :center ->
        left_pad = div(padding_needed, 2)
        right_pad = padding_needed - left_pad

        String.duplicate(pad_char, left_pad) <>
          string <> String.duplicate(pad_char, right_pad)
    end
  end

  @doc """
  Normalize a string for terminal display.

  This applies NFC normalization and handles various Unicode edge cases.

  ## Example

      iex> Raxol.Terminal.Unicode.normalize("cafe\\u0301")
      "cafe"
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(string) when is_binary(string) do
    :unicode.characters_to_nfc_binary(string)
  end

  @doc """
  Split a string into grapheme clusters with their display widths.

  Returns a list of {grapheme, width} tuples.

  ## Example

      iex> Raxol.Terminal.Unicode.graphemes_with_widths("Hi!")
      [{"H", 1}, {"i", 1}, {"!", 1}]
  """
  @spec graphemes_with_widths(String.t()) :: [{String.t(), non_neg_integer()}]
  def graphemes_with_widths(string) when is_binary(string) do
    string
    |> String.graphemes()
    |> Enum.map(fn grapheme ->
      width =
        grapheme
        |> String.to_charlist()
        |> Enum.reduce(0, fn char, acc -> acc + char_width(char) end)

      {grapheme, width}
    end)
  end

  # Private helpers

  defp truncate_to_width(string, target_width) do
    string
    |> graphemes_with_widths()
    |> Enum.reduce_while({"", 0}, fn {grapheme, width}, {acc, current_width} ->
      new_width = current_width + width

      if new_width <= target_width do
        {:cont, {acc <> grapheme, new_width}}
      else
        {:halt, {acc, current_width}}
      end
    end)
  end
end
