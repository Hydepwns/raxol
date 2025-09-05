defmodule Raxol.UI.Components.Input.MultiLineInput.TextUtils do
  @moduledoc """
  Utility functions for text manipulation including line splitting, wrapping, and position conversion.
  """

  alias Raxol.UI.Components.Input.TextWrapping
  require Raxol.Core.Runtime.Log

  @doc """
  Splits the given text into lines, applying the specified wrapping mode (:none, :char, or :word).
  """
  def split_into_lines("", _width, _wrap), do: [""]

  def split_into_lines(text, width, wrap_mode) do
    lines = String.split(text, "\n")

    case wrap_mode do
      :none -> lines
      :char -> Enum.flat_map(lines, &TextWrapping.wrap_line_by_char(&1, width))
      :word -> Enum.flat_map(lines, &TextWrapping.wrap_line_by_word(&1, width))
    end
  end

  @doc """
  Splits the given text into lines and applies the provided wrapping function to each line.
  """
  def split_and_wrap(text, width, wrap_fun) do
    text
    |> String.split("\n")
    |> Enum.flat_map(&wrap_fun.(&1, width))
  end

  @doc """
  Converts a {row, col} tuple to a flat string index based on the provided lines.
  """
  def pos_to_index(text_lines, {row, col}) do
    num_lines = length(text_lines)
    safe_row = clamp(row, 0, max(0, num_lines - 1))

    line_length =
      calculate_line_length(
        safe_row >= 0 and safe_row < num_lines,
        text_lines,
        safe_row
      )

    # If row is out of bounds, clamp to end of last line
    safe_col = calculate_safe_col(row >= num_lines, col, line_length)

    # Calculate index by summing lengths of previous lines plus newlines
    prefix_sum =
      text_lines
      |> Enum.slice(0, safe_row)
      |> Enum.map(&String.length(&1))
      |> Enum.sum()

    # Add newline characters (one per line except the last)
    newline_count = safe_row
    # Add the column position on the current line
    total_index = prefix_sum + newline_count + safe_col

    Raxol.Core.Runtime.Log.debug(
      "pos_to_index: lines=#{inspect(text_lines)}, pos={#{row}, #{col}} -> safe_row=#{safe_row}, safe_col=#{safe_col}, index=#{total_index}"
    )

    total_index
  end

  @doc """
  Clamps a value between min and max.
  """
  def clamp(value, min, max) do
    value |> max(min) |> min(max)
  end

  defp calculate_line_length(true, text_lines, safe_row) do
    String.length(Enum.at(text_lines, safe_row) || "")
  end

  defp calculate_line_length(false, _text_lines, _safe_row), do: 0

  defp calculate_safe_col(true, _col, line_length), do: line_length

  defp calculate_safe_col(false, col, line_length),
    do: clamp(col, 0, line_length)

  @doc """
  Normalizes full text by joining lines with newlines if it's a list.
  """
  def normalize_full_text(full_text) when is_list(full_text),
    do: Enum.join(full_text, "\n")

  def normalize_full_text(full_text), do: full_text

  @doc """
  Gets the part of a line after a given column position.
  """
  def get_after_part(_line, end_col, line_length) when end_col == line_length,
    do: ""

  def get_after_part(line, end_col, line_length),
    do: String.slice(line, end_col, line_length - end_col)
end
