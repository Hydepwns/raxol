defmodule Raxol.Terminal.ScreenBuffer.Selection do
  @moduledoc """
  Text selection operations for the screen buffer.
  Handles selection creation, updates, text extraction, and clipboard operations.
  """

  alias Raxol.Terminal.ScreenBuffer.Core
  alias Raxol.Terminal.ScreenBuffer.SharedOperations
  alias Raxol.Terminal.Cell

  @type selection ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
          | nil

  @doc """
  Starts a new selection at the specified position.
  """
  @spec start_selection(Core.t(), non_neg_integer(), non_neg_integer()) ::
          Core.t()
  def start_selection(buffer, x, y) do
    %{buffer | selection: {x, y, x, y}}
  end

  @doc """
  Extends the selection to the specified position.
  """
  @spec extend_selection(Core.t(), non_neg_integer(), non_neg_integer()) ::
          Core.t()
  def extend_selection(buffer, x, y) do
    case buffer.selection do
      {start_x, start_y, _, _} ->
        %{buffer | selection: {start_x, start_y, x, y}}

      nil ->
        start_selection(buffer, x, y)
    end
  end

  @doc """
  Clears the current selection.
  """
  @spec clear_selection(Core.t()) :: Core.t()
  def clear_selection(buffer) do
    %{buffer | selection: nil}
  end

  @doc """
  Gets the current selection boundaries, normalized so start <= end.
  """
  @spec get_selection(Core.t()) :: selection()
  def get_selection(buffer) do
    case buffer.selection do
      nil -> nil
      {x1, y1, x2, y2} -> SharedOperations.normalize_selection(x1, y1, x2, y2)
    end
  end

  @doc """
  Checks if there is an active selection.
  """
  @spec has_selection(Core.t()) :: boolean()
  def has_selection(buffer) do
    buffer.selection != nil
  end

  @doc """
  Checks if the specified position is within the current selection.
  """
  @spec selected?(Core.t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def selected?(buffer, x, y) do
    case get_selection(buffer) do
      nil ->
        false

      {start_x, start_y, end_x, end_y} ->
        SharedOperations.position_in_selection?(
          x,
          y,
          start_x,
          start_y,
          end_x,
          end_y
        )
    end
  end

  @doc """
  Checks if a position is within the current selection.
  """
  @spec position_in_selection?(Core.t(), non_neg_integer(), non_neg_integer()) ::
          boolean()
  def position_in_selection?(buffer, x, y) do
    case get_selection(buffer) do
      nil ->
        false

      {start_x, start_y, end_x, end_y} ->
        cond do
          # Single line selection
          start_y == end_y ->
            y == start_y and x >= start_x and x <= end_x

          # Multi-line selection
          true ->
            cond do
              y < start_y -> false
              y > end_y -> false
              y == start_y -> x >= start_x
              y == end_y -> x <= end_x
              # Middle lines are fully selected
              true -> true
            end
        end
    end
  end

  @doc """
  Gets the selected text as a string.
  """
  @spec get_selected_text(Core.t()) :: String.t()
  def get_selected_text(buffer) do
    case get_selection(buffer) do
      nil ->
        ""

      {start_x, start_y, end_x, end_y} ->
        extract_text_region(buffer, start_x, start_y, end_x, end_y)
    end
  end

  @doc """
  Gets the selected text as lines.
  """
  @spec get_selected_lines(Core.t()) :: list(String.t())
  def get_selected_lines(buffer) do
    case get_selection(buffer) do
      nil ->
        []

      {start_x, start_y, end_x, end_y} ->
        extract_lines_region(buffer, start_x, start_y, end_x, end_y)
    end
  end

  @doc """
  Selects an entire line.
  """
  @spec select_line(Core.t(), non_neg_integer()) :: Core.t()
  def select_line(buffer, y) when y >= 0 and y < buffer.height do
    %{buffer | selection: {0, y, buffer.width - 1, y}}
  end

  def select_line(buffer, _y), do: buffer

  @doc """
  Selects multiple lines.
  """
  @spec select_lines(Core.t(), non_neg_integer(), non_neg_integer()) :: Core.t()
  def select_lines(buffer, start_y, end_y) do
    start_y = max(0, min(start_y, buffer.height - 1))
    end_y = max(0, min(end_y, buffer.height - 1))
    %{buffer | selection: {0, start_y, buffer.width - 1, end_y}}
  end

  @doc """
  Selects all content in the buffer.
  """
  @spec select_all(Core.t()) :: Core.t()
  def select_all(buffer) do
    %{buffer | selection: {0, 0, buffer.width - 1, buffer.height - 1}}
  end

  @doc """
  Selects a word at the given position.
  """
  @spec select_word(Core.t(), non_neg_integer(), non_neg_integer()) :: Core.t()
  def select_word(buffer, x, y) when x >= 0 and y >= 0 and y < buffer.height do
    line = Core.get_line(buffer, y)

    # Find word boundaries
    {start_x, end_x} = find_word_boundaries(line, x)

    %{buffer | selection: {start_x, y, end_x, y}}
  end

  def select_word(buffer, _x, _y), do: buffer

  @doc """
  Expands selection to word boundaries.
  """
  @spec expand_selection_to_word(Core.t()) :: Core.t()
  def expand_selection_to_word(buffer) do
    case buffer.selection do
      {x1, y1, x2, y2} ->
        line1 = Core.get_line(buffer, y1)
        line2 = Core.get_line(buffer, y2)

        {start_x, _} = find_word_boundaries(line1, x1)
        {_, end_x} = find_word_boundaries(line2, x2)

        %{buffer | selection: {start_x, y1, end_x, y2}}

      nil ->
        buffer
    end
  end

  # Private helper functions

  defp extract_text_region(buffer, start_x, start_y, end_x, end_y) do
    lines = extract_lines_region(buffer, start_x, start_y, end_x, end_y)
    Enum.join(lines, "\n")
  end

  defp extract_lines_region(buffer, start_x, start_y, end_x, end_y) do
    cond do
      # Single line selection
      start_y == end_y ->
        line = Core.get_line(buffer, start_y)

        text =
          line
          |> Enum.slice(start_x..end_x)
          |> Enum.map(&cell_to_char/1)
          |> Enum.join()

        [text]

      # Multi-line selection
      true ->
        for y <- start_y..end_y do
          line = Core.get_line(buffer, y)

          {from, to} =
            cond do
              y == start_y -> {start_x, buffer.width - 1}
              y == end_y -> {0, end_x}
              true -> {0, buffer.width - 1}
            end

          line
          |> Enum.slice(from..to)
          |> Enum.map(&cell_to_char/1)
          |> Enum.join()
          |> String.trim_trailing()
        end
    end
  end

  defp cell_to_char(%Cell{char: char}) when is_binary(char), do: char
  defp cell_to_char(_), do: " "

  defp find_word_boundaries(line, x) do
    # Get character at position
    char_at_x =
      case Enum.at(line, x) do
        %Cell{char: c} when is_binary(c) -> c
        _ -> " "
      end

    # Determine if we're on a word character
    if word_char?(char_at_x) do
      # Find start of word
      start_x = find_word_start(line, x)
      # Find end of word
      end_x = find_word_end(line, x)
      {start_x, end_x}
    else
      # Not on a word, just select the position
      {x, x}
    end
  end

  defp find_word_start(line, x) do
    Enum.reduce_while((x - 1)..0, x, fn i, _acc ->
      case Enum.at(line, i) do
        %Cell{char: c} when is_binary(c) ->
          if word_char?(c), do: {:cont, i}, else: {:halt, i + 1}

        _ ->
          {:halt, i + 1}
      end
    end)
  end

  defp find_word_end(line, x) do
    max_x = length(line) - 1

    Enum.reduce_while((x + 1)..max_x, x, fn i, _acc ->
      case Enum.at(line, i) do
        %Cell{char: c} when is_binary(c) ->
          if word_char?(c), do: {:cont, i}, else: {:halt, i - 1}

        _ ->
          {:halt, i - 1}
      end
    end)
  end

  defp word_char?(char) do
    String.match?(char, ~r/[a-zA-Z0-9_]/)
  end
end
