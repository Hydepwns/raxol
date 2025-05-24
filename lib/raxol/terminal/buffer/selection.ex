defmodule Raxol.Terminal.Buffer.Selection do
  @moduledoc """
  Handles text selection within the Raxol.Terminal.ScreenBuffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  @doc """
  Starts a selection at the specified coordinates in the buffer.
  """
  @spec start(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def start(%ScreenBuffer{} = buffer, x, y) when x >= 0 and y >= 0 do
    %{buffer | selection: {x, y, x, y}}
  end

  @doc """
  Updates the endpoint of the current selection in the buffer.
  """
  @spec update(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def update(%ScreenBuffer{} = buffer, x, y) when x >= 0 and y >= 0 do
    case buffer.selection do
      {start_x, start_y, _end_x, _end_y} ->
        %{buffer | selection: {start_x, start_y, x, y}}

      nil ->
        buffer
    end
  end

  @doc """
  Gets the text within the current selection in the buffer.
  """
  @spec get_text(ScreenBuffer.t()) :: String.t()
  def get_text(%ScreenBuffer{} = buffer) do
    case buffer.selection do
      {start_x, start_y, end_x, end_y} ->
        get_text_in_region(buffer, start_x, start_y, end_x, end_y)

      nil ->
        ""
    end
  end

  @doc """
  Checks if a position (x, y) is within the current selection in the buffer.
  """
  @spec contains?(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          boolean()
  def contains?(%ScreenBuffer{} = buffer, x, y) do
    case buffer.selection do
      {start_x, start_y, end_x, end_y} ->
        min_x = min(start_x, end_x)
        max_x = max(start_x, end_x)
        min_y = min(start_y, end_y)
        max_y = max(start_y, end_y)
        x >= min_x and x <= max_x and y >= min_y and y <= max_y

      nil ->
        false
    end
  end

  @doc """
  Gets the boundaries {start_x, start_y, end_x, end_y} of the current selection.
  Returns nil if there is no selection.
  """
  @spec get_boundaries(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
          | nil
  def get_boundaries(%ScreenBuffer{} = buffer) do
    buffer.selection
  end

  @doc """
  Gets the text within a specified rectangular region of the buffer.
  Coordinates are inclusive.
  """
  @spec get_text_in_region(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: String.t()
  def get_text_in_region(
        %ScreenBuffer{} = buffer,
        start_x,
        start_y,
        end_x,
        end_y
      ) do
    # Ensure coordinates are within valid range if needed, though buffer access handles it
    min_x = min(start_x, end_x)
    max_x = max(start_x, end_x)
    min_y = min(start_y, end_y)
    max_y = max(start_y, end_y)

    # Clamp coordinates to buffer dimensions to prevent out-of-bounds access attempts
    clamped_min_x = max(0, min_x)
    clamped_max_x = min(buffer.width - 1, max_x)
    clamped_min_y = max(0, min_y)
    clamped_max_y = min(buffer.height - 1, max_y)

    # Check if the clamped region is valid
    if clamped_min_y > clamped_max_y or clamped_min_x > clamped_max_x do
      ""
    else
      buffer.cells
      # Slice rows safely
      |> Enum.slice(clamped_min_y..clamped_max_y)
      |> Enum.map_join("\n", fn row ->
        row
        # Slice cols safely
        |> Enum.slice(clamped_min_x..(clamped_max_x - clamped_min_x + 1))
        |> Enum.map_join("", &Cell.get_char/1)
        # Trim trailing whitespace from each line
        |> String.trim_trailing()
      end)
    end
  end

  @doc """
  Creates a new selection struct or map with the given start and end coordinates.
  If no coordinates are provided, initializes with nil (no selection).
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: %{
          selection:
            {non_neg_integer(), non_neg_integer(), non_neg_integer(),
             non_neg_integer()}
        }
  def new(x, y) when x >= 0 and y >= 0 do
    # By convention, a selection is a map with a :selection field
    %{selection: {x, y, x, y}}
  end
end
