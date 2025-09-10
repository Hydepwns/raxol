defmodule Raxol.Terminal.Buffer.OperationProcessor do
  @moduledoc """
  Handles processing and batching of buffer operations.

  This module is responsible for:
  - Processing individual operations (set_cell, write_string, fill_region, etc.)
  - Batching operations for performance
  - Managing operation queues
  - Error handling during operation processing
  """

  require Logger
  alias Raxol.Terminal.Buffer.Content
  alias Raxol.Terminal.Buffer.Operations, as: Buffer
  alias Raxol.Terminal.Buffer.BufferState, as: State

  @type operation ::
          {:set_cell, non_neg_integer(), non_neg_integer(), term()}
          | {:write_string, non_neg_integer(), non_neg_integer(), String.t()}
          | {:fill_region, non_neg_integer(), non_neg_integer(),
             non_neg_integer(), non_neg_integer(), term()}
          | {:scroll, integer()}
          | {:resize, non_neg_integer(), non_neg_integer()}

  @doc """
  Processes a single operation on the buffer.
  """
  @spec process_operation(operation(), term()) :: term()
  def process_operation({:set_cell, x, y, cell}, buffer) do
    case valid_coordinates?(buffer, x, y) do
      true ->
        Content.write_char(buffer, x, y, cell.char, cell)

      false ->
        buffer
    end
  end

  def process_operation(
        {:set_cell, _x, _y, _cell, :invalid_coordinates},
        buffer
      ) do
    buffer
  end

  def process_operation({:write_string, x, y, string}, buffer) do
    case valid_coordinates?(buffer, x, y) do
      true ->
        Content.write_string(buffer, x, y, string)

      false ->
        buffer
    end
  end

  def process_operation(
        {:write_string, _x, _y, _string, :invalid_coordinates},
        buffer
      ) do
    buffer
  end

  def process_operation({:fill_region, x, y, width, height, cell}, buffer) do
    case valid_coordinates?(buffer, x, y) and x + width <= buffer.width and
           y + height <= buffer.height do
      true ->
        fill_region_helper(buffer, x, y, width, height, cell)

      false ->
        buffer
    end
  end

  def process_operation(
        {:fill_region, _x, _y, _width, _height, _cell, :invalid_coordinates},
        buffer
      ) do
    buffer
  end

  def process_operation({:scroll, lines}, buffer) do
    Buffer.scroll(buffer, lines)
  end

  def process_operation({:resize, width, height}, buffer) do
    State.resize(buffer, width, height)
  end

  @doc """
  Processes a batch of operations on the buffer.
  """
  @spec process_batch([operation()], term()) :: term()
  def process_batch(operations, buffer) do
    Enum.reduce(operations, buffer, &process_operation/2)
  end

  @doc """
  Processes all operations in a queue until empty.
  """
  @spec process_all_operations([operation()], term()) :: term()
  def process_all_operations(operations, buffer) do
    process_batch(operations, buffer)
  end

  @doc """
  Validates if coordinates are within buffer bounds.
  """
  @spec valid_coordinates?(term(), non_neg_integer(), non_neg_integer()) ::
          boolean()
  def valid_coordinates?(buffer, x, y) do
    x >= 0 and y >= 0 and x < buffer.width and y < buffer.height
  end

  @doc """
  Validates if fill region coordinates are valid.
  """
  @spec valid_fill_region_coordinates?(
          term(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: boolean()
  def valid_fill_region_coordinates?(buffer, x, y, width, height) do
    valid_coordinates?(buffer, x, y) and x + width <= buffer.width and
      y + height <= buffer.height
  end

  # Private helper functions

  defp fill_region_helper(buffer, x, y, width, height, cell) do
    Enum.reduce(y..(y + height - 1), buffer, fn row_y, acc ->
      Enum.reduce(x..(x + width - 1), acc, fn col_x, acc ->
        Content.write_char(acc, col_x, row_y, cell.char, cell)
      end)
    end)
  end
end
