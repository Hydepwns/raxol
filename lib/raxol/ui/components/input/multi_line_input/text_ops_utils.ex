defmodule Raxol.UI.Components.Input.MultiLineInput.TextOperations.Utils do
  @moduledoc """
  Utility functions for text operations.
  """

  @doc """
  Clamps a value between min and max.
  """
  def clamp(value, min, _max) when value < min, do: min
  def clamp(value, _min, max) when value > max, do: max
  def clamp(value, _min, _max), do: value

  @doc """
  Formats the result text by joining lines with newlines.
  """
  def format_result(lines) when is_list(lines) do
    Enum.join(lines, "\n")
  end

  def format_result(text) when is_binary(text) do
    text
  end

  @doc """
  Safely slices a string with bounds checking.
  """
  def safe_slice(string, start, length) do
    string_length = String.length(string)
    start = clamp(start, 0, string_length)
    length = clamp(length, 0, string_length - start)
    String.slice(string, start, length)
  end

  @doc """
  Inserts text into a single line at the specified position.

  Returns a tuple with {updated_line, remainder_text}.
  """
  def insert_into_line(line, col, text) do
    line_length = String.length(line)
    col = clamp(col, 0, line_length)

    before = String.slice(line, 0, col)
    after_part = String.slice(line, col, line_length - col)
    new_line = before <> text <> after_part

    {new_line, ""}
  end
end
