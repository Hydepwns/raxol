defmodule Raxol.Terminal.Buffer.Selection do
  @moduledoc """
  Manages text selection operations for the terminal.
  """

  defstruct [
    start_pos: {0, 0},
    end_pos: {0, 0},
    selected_text: ""
  ]

  @type t :: %__MODULE__{
          start_pos: {non_neg_integer(), non_neg_integer()},
          end_pos: {non_neg_integer(), non_neg_integer()},
          selected_text: String.t()
        }

  @doc """
  Creates a new Selection struct.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Starts a text selection at the specified position.
  """
  def start(%__MODULE__{} = selection, x, y) do
    %{selection | start_pos: {x, y}, end_pos: {x, y}}
  end

  @doc """
  Updates the selection end position.
  """
  def update(%__MODULE__{} = selection, x, y) do
    %{selection | end_pos: {x, y}}
  end

  @doc """
  Gets the text in the selected region.
  """
  def get_text(%__MODULE__{} = selection) do
    selection.selected_text
  end

  @doc """
  Checks if a position is within the current selection.
  """
  def contains?(%__MODULE__{} = selection, x, y) do
    {start_x, start_y} = selection.start_pos
    {end_x, end_y} = selection.end_pos

    # Normalize coordinates to ensure start <= end
    {min_x, max_x} = {min(start_x, end_x), max(start_x, end_x)}
    {min_y, max_y} = {min(start_y, end_y), max(start_y, end_y)}

    x >= min_x and x <= max_x and y >= min_y and y <= max_y
  end

  @doc """
  Gets the current selection boundaries.
  """
  def get_boundaries(%__MODULE__{} = selection) do
    {start_x, start_y} = selection.start_pos
    {end_x, end_y} = selection.end_pos

    # Normalize coordinates to ensure start <= end
    {min_x, max_x} = {min(start_x, end_x), max(start_x, end_x)}
    {min_y, max_y} = {min(start_y, end_y), max(start_y, end_y)}

    {min_x, min_y, max_x, max_y}
  end

  @doc """
  Gets text from a specified region in the buffer.
  """
  @spec get_text_in_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: String.t()
  def get_text_in_region(buffer, start_x, start_y, end_x, end_y) do
    # Ensure start coordinates are less than or equal to end coordinates
    {start_x, end_x} = {min(start_x, end_x), max(start_x, end_x)}
    {start_y, end_y} = {min(start_y, end_y), max(start_y, end_y)}

    # Get the text from each line in the region
    text =
      for y <- start_y..end_y do
        line = Enum.at(buffer.cells, y) || []
        chars =
          for x <- start_x..end_x do
            cell = Enum.at(line, x)
            if cell, do: cell.char, else: " "
          end
        Enum.join(chars)
      end

    # Join all lines with newlines
    Enum.join(text, "\n")
  end
end
