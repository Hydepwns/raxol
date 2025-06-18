defmodule Raxol.Terminal.Buffer.Selection do
  @moduledoc '''
  Manages text selection operations for the terminal.
  This module handles all selection-related operations including:
  - Starting and updating selections
  - Getting selected text
  - Checking if positions are within selections
  - Managing selection boundaries
  - Extracting text from regions
  '''

  alias Raxol.Terminal.ScreenBuffer

  @doc '''
  Starts a text selection at the specified position.
  '''
  @spec start(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def start(buffer, x, y) do
    %{buffer | selection: {x, y, x, y}}
  end

  @doc '''
  Updates the current text selection to the specified position.
  '''
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

  @doc '''
  Gets the currently selected text.
  '''
  @spec get_text(ScreenBuffer.t()) :: String.t()
  def get_text(buffer) do
    case buffer.selection do
      nil ->
        ""

      {start_x, start_y, end_x, end_y} ->
        get_text_in_region(buffer, start_x, start_y, end_x, end_y)
    end
  end

  @doc '''
  Checks if a position is within the current selection.
  '''
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

  @doc '''
  Gets the current selection boundaries.
  '''
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

  @doc '''
  Gets text from a specified region in the buffer.
  '''
  @spec get_text_in_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: String.t()
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

  @doc '''
  Clears the current selection.
  '''
  @spec clear(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear(buffer) do
    %{buffer | selection: nil}
  end

  @doc '''
  Checks if there is an active selection.
  '''
  @spec active?(ScreenBuffer.t()) :: boolean()
  def active?(buffer) do
    buffer.selection != nil
  end

  @doc '''
  Gets the selection start position.
  '''
  @spec get_start_position(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()} | nil
  def get_start_position(buffer) do
    case buffer.selection do
      {start_x, start_y, _, _} -> {start_x, start_y}
      nil -> nil
    end
  end

  @doc '''
  Gets the selection end position.
  '''
  @spec get_end_position(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()} | nil
  def get_end_position(buffer) do
    case buffer.selection do
      {_, _, end_x, end_y} -> {end_x, end_y}
      nil -> nil
    end
  end
end
