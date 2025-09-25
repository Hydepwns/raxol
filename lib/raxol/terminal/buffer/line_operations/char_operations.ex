defmodule Raxol.Terminal.Buffer.LineOperations.CharOperations do
  @moduledoc """
  Character-level operations for buffer lines.
  Handles character insertion, deletion, and manipulation within lines.
  """

  @doc """
  Delete characters from a line.
  """
  @spec delete_chars(list(), integer()) :: list()
  def delete_chars(line, count) when is_list(line) and is_integer(count) do
    Enum.drop(line, count)
  end

  @doc """
  Delete characters at a specific position in a buffer.
  """
  @spec delete_chars_at(map(), integer(), integer(), integer()) :: map()
  def delete_chars_at(buffer, x, y, count) do
    line = get_line(buffer, y, [])
    {before, rest} = Enum.split(line, x)
    new_rest = Enum.drop(rest, count)
    new_line = before ++ new_rest
    set_line(buffer, y, new_line)
  end

  @doc """
  Erase characters with a specific style.
  """
  @spec erase_chars(map(), integer(), integer(), integer()) :: map()
  def erase_chars(buffer, x, y, count) do
    line = get_line(buffer, y, [])
    {before, rest} = Enum.split(line, x)
    {to_erase, after_erase} = Enum.split(rest, count)

    # Replace with empty cells
    empty_cells =
      Enum.map(1..length(to_erase), fn _ ->
        %{char: " ", style: %{}}
      end)

    new_line = before ++ empty_cells ++ after_erase
    set_line(buffer, y, new_line)
  end

  @doc """
  Insert characters into a line.
  """
  @spec insert_chars(list(), list()) :: list()
  def insert_chars(line, chars) when is_list(line) and is_list(chars) do
    chars ++ line
  end

  @doc """
  Insert characters at a specific position in a buffer.
  """
  @spec insert_chars_at(map(), integer(), integer(), list()) :: map()
  def insert_chars_at(buffer, x, y, chars) do
    line = get_line(buffer, y, [])
    {before, after_cursor} = Enum.split(line, x)
    new_line = before ++ chars ++ after_cursor
    set_line(buffer, y, new_line)
  end

  # Helper functions
  defp get_line(buffer, y, default) do
    Map.get(buffer.lines, y, default)
  end

  defp set_line(buffer, y, line) do
    lines = Map.put(buffer.lines, y, line)
    %{buffer | lines: lines}
  end
end
