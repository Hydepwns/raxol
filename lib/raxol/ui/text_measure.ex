defmodule Raxol.UI.TextMeasure do
  @moduledoc """
  Single source of truth for text display width measurement.

  Delegates to CharacterHandling in raxol_terminal when available,
  falls back to String.length for environments without the terminal package.

  All layout, rendering, and text wrapping code should use this module
  instead of String.length for display-width-sensitive calculations.
  """

  @compile {:no_warn_undefined, Raxol.Terminal.CharacterHandling}

  @doc """
  Returns the display width of a string in terminal columns.

  CJK characters, fullwidth symbols, and emoji count as 2 columns.
  Combining characters count as 0 columns.
  All other characters count as 1 column.

  Delegates to CharacterHandling (raxol_terminal) for correct Unicode
  width calculation. Falls back to String.length if unavailable.
  """
  @spec display_width(String.t()) :: non_neg_integer()
  def display_width(text) when is_binary(text) do
    if Code.ensure_loaded?(Raxol.Terminal.CharacterHandling) do
      Raxol.Terminal.CharacterHandling.get_string_width(text)
    else
      String.length(text)
    end
  end

  @doc """
  Returns the display width of a single grapheme (1 or 2 columns).
  """
  @spec char_display_width(String.t()) :: 1 | 2
  def char_display_width(char) when is_binary(char) do
    if Code.ensure_loaded?(Raxol.Terminal.CharacterHandling) do
      Raxol.Terminal.CharacterHandling.get_char_width(char)
    else
      1
    end
  end

  @doc """
  Splits a string at a given display width boundary.

  Returns `{left, right}` where `left` fits within `width` display columns.
  Will not split a double-width character in half.
  """
  @spec split_at_display_width(String.t(), non_neg_integer()) ::
          {String.t(), String.t()}
  def split_at_display_width(text, width)
      when is_binary(text) and is_integer(width) do
    if Code.ensure_loaded?(Raxol.Terminal.CharacterHandling) do
      Raxol.Terminal.CharacterHandling.split_at_width(text, width)
    else
      {String.slice(text, 0, width), String.slice(text, width..-1//1)}
    end
  end
end
