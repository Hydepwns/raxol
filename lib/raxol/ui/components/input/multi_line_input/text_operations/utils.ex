defmodule Raxol.UI.Components.Input.MultiLineInput.TextOperations.Utils do
  @moduledoc """
  Utility functions for text operations.
  """

  @doc """
  Clamps a value between min and max.
  """
  def clamp(value, min, max) when value < min, do: min
  def clamp(value, min, max) when value > max, do: max
  def clamp(value, min, max), do: value

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
end
