defmodule Raxol.Terminal.Buffer.Selection do
  @moduledoc """
  Manages text selection operations for the terminal.
  This module handles all selection-related operations including:
  - Starting and updating selections
  - Getting selected text
  - Checking if positions are within selections
  - Managing selection boundaries
  - Extracting text from regions
  """

  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Creates a new selection with start and end positions.
  """
  @spec new(
          {non_neg_integer(), non_neg_integer()},
          {non_neg_integer(), non_neg_integer()}
        ) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
  def new({start_x, start_y}, {end_x, end_y}) do
    {start_x, start_y, end_x, end_y}
  end

  @doc """
  Starts a text selection at the specified position.
  """
  @spec start(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def start(buffer, x, y) do
    # Clear any existing selection first
    buffer = clear(buffer)
    %{buffer | selection: {x, y, x, y}}
  end

  @doc """
  Updates the current text selection to the specified position.
  """
  @spec update(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def update(buffer, x, y) do
    case buffer.selection do
      {start_x, start_y, _, _} ->
        %{buffer | selection: {start_x, start_y, x, y}}

      nil ->
        start(buffer, x, y)
    end
  end

  @doc """
  Gets the currently selected text.
  """
  @spec get_text(ScreenBuffer.t()) :: String.t()
  def get_text(buffer) do
    case buffer.selection do
      nil ->
        ""

      {start_x, start_y, end_x, end_y} ->
        get_text_in_region(buffer, start_x, start_y, end_x, end_y)
    end
  end

  @doc """
  Checks if a position is within the current selection.
  """
  @spec contains?(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          boolean()
  def contains?(buffer, x, y) do
    case buffer.selection do
      nil ->
        false

      {start_x, start_y, end_x, end_y} ->
        # Normalize coordinates to ensure start <= end
        {min_x, max_x} = {min(start_x, end_x), max(start_x, end_x)}
        {min_y, max_y} = {min(start_y, end_y), max(start_y, end_y)}

        x >= min_x and x <= max_x and y >= min_y and y <= max_y
    end
  end

  @doc """
  Gets the current selection boundaries.
  """
  @spec get_boundaries(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
          | nil
  def get_boundaries(buffer) do
    case buffer.selection do
      nil ->
        nil

      {start_x, start_y, end_x, end_y} ->
        # Normalize coordinates to ensure start <= end
        {min_x, max_x} = {min(start_x, end_x), max(start_x, end_x)}
        {min_y, max_y} = {min(start_y, end_y), max(start_y, end_y)}

        {min_x, min_y, max_x, max_y}
    end
  end

  @doc """
  Gets text from a specified region in the buffer.
  """
  @spec get_text_in_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: String.t()
  def get_text_in_region(buffer, start_x, start_y, end_x, end_y) do
    # Check if coordinates are out of bounds
    case out_of_bounds?(buffer, start_x, start_y, end_x, end_y) do
      true ->
        ""
      false ->
        # Ensure start coordinates are less than or equal to end coordinates
        {start_x, end_x} = {min(start_x, end_x), max(start_x, end_x)}
        {start_y, end_y} = {min(start_y, end_y), max(start_y, end_y)}

        # Handle empty region (same start and end coordinates)
        handle_region_extraction(buffer, start_x, start_y, end_x, end_y)
    end
  end

  defp handle_region_extraction(buffer, start_x, start_y, end_x, end_y) when start_x == end_x and start_y == end_y do
    ""
  end

  defp handle_region_extraction(buffer, start_x, start_y, end_x, end_y) do
    extract_region_text(buffer, start_x, start_y, end_x, end_y)
  end

  defp out_of_bounds?(buffer, start_x, start_y, end_x, end_y) do
    start_x >= buffer.width or end_x >= buffer.width or
      start_y >= buffer.height or end_y >= buffer.height or
      start_x < 0 or start_y < 0 or end_x < 0 or end_y < 0
  end

  defp extract_region_text(buffer, start_x, start_y, end_x, end_y) do
    case buffer.cells do
      nil ->
        # Return empty string if cells is nil
        ""

      cells ->
        text =
          for y <- start_y..end_y do
            line = Enum.at(cells, y) || []

            chars =
              for x <- start_x..end_x do
                cell = Enum.at(line, x)
                get_cell_char(cell)
              end

            Enum.join(chars)
          end

        Enum.join(text, "\n")
    end
  end

  @doc """
  Clears the current selection.
  """
  @spec clear(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear(buffer) do
    %{buffer | selection: nil}
  end

  @doc """
  Checks if there is an active selection.
  """
  @spec active?(ScreenBuffer.t()) :: boolean()
  def active?(buffer) do
    buffer.selection != nil
  end

  @doc """
  Gets the selection start position.
  """
  @spec get_start_position(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()} | nil
  def get_start_position(buffer) do
    case buffer.selection do
      {start_x, start_y, _, _} -> {start_x, start_y}
      nil -> nil
    end
  end

  @doc """
  Gets the selection end position.
  """
  @spec get_end_position(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()} | nil
  def get_end_position(buffer) do
    case buffer.selection do
      {start_x, start_y, end_x, end_y} ->
        get_position_if_different(start_x, start_y, end_x, end_y)

      nil ->
        nil
    end
  end

  defp get_position_if_different(start_x, start_y, end_x, end_y) when start_x == end_x and start_y == end_y do
    nil
  end

  defp get_position_if_different(_start_x, _start_y, end_x, end_y) do
    {end_x, end_y}
  end

  @doc """
  Gets a line from a list of strings at the specified index.
  """
  @spec get_line(list(String.t()), non_neg_integer()) :: String.t()
  def get_line(lines_list, row) when is_list(lines_list) and is_integer(row) do
    Enum.at(lines_list, row, "")
  end

  @doc """
  Gets the buffer text for the current selection.
  This is an alias for get_text/1 for compatibility.
  """
  @spec get_buffer_text(ScreenBuffer.t()) ::
          {:ok, String.t()} | {:error, term()}
  def get_buffer_text(buffer) do
    case Raxol.Core.ErrorHandling.safe_call(fn -> get_text(buffer) end) do
      {:ok, text} -> {:ok, text}
      {:error, e} -> {:error, e}
    end
  end

  defp get_cell_char(nil), do: " "
  defp get_cell_char(cell), do: cell.char
end
