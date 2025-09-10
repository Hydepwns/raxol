defmodule Raxol.Terminal.Buffer.BufferHandler do
  @moduledoc """
  GenServer cast handlers for the buffer server.
  """

  alias Raxol.Terminal.Buffer.OperationProcessor
  alias Raxol.Terminal.Buffer.OperationQueue

  @doc """
  Handles asynchronous set_cell operations.
  """
  def handle_cast({:set_cell, x, y, cell}, state) do
    # Validate coordinates and add operation to queue
    operation =
      build_set_cell_operation(
        OperationProcessor.valid_coordinates?(state.buffer, x, y),
        x,
        y,
        cell
      )

    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    process_queue_if_needed(
      OperationQueue.should_process?(new_queue),
      new_state
    )
  end

  def handle_cast({:write_string, x, y, string}, state) do
    # Validate coordinates and add operation to queue
    operation =
      build_write_string_operation(
        OperationProcessor.valid_coordinates?(state.buffer, x, y),
        x,
        y,
        string
      )

    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    process_queue_if_needed(
      OperationQueue.should_process?(new_queue),
      new_state
    )
  end

  def handle_cast({:fill_region, x, y, width, height, cell}, state) do
    # Validate coordinates and add operation to queue
    operation =
      build_fill_region_operation(
        OperationProcessor.valid_fill_region_coordinates?(
          state.buffer,
          x,
          y,
          width,
          height
        ),
        x,
        y,
        width,
        height,
        cell
      )

    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    process_queue_if_needed(
      OperationQueue.should_process?(new_queue),
      new_state
    )
  end

  def handle_cast({:scroll, lines}, state) do
    operation = {:scroll, lines}
    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    process_queue_if_needed(
      OperationQueue.should_process?(new_queue),
      new_state
    )
  end

  def handle_cast({:resize, width, height}, state) do
    operation = {:resize, width, height}
    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    process_queue_if_needed(
      OperationQueue.should_process?(new_queue),
      new_state
    )
  end

  def handle_cast({:batch_operations, operations}, state) do
    new_queue = OperationQueue.add_operations(state.operation_queue, operations)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    process_queue_if_needed(
      OperationQueue.should_process?(new_queue),
      new_state
    )
  end

  # Helper functions for refactored if statements
  defp build_set_cell_operation(true, x, y, cell) do
    {:set_cell, x, y, cell}
  end

  defp build_set_cell_operation(false, x, y, cell) do
    {:set_cell, x, y, cell, :invalid_coordinates}
  end

  defp build_write_string_operation(true, x, y, string) do
    {:write_string, x, y, string}
  end

  defp build_write_string_operation(false, x, y, string) do
    {:write_string, x, y, string, :invalid_coordinates}
  end

  defp build_fill_region_operation(true, x, y, width, height, cell) do
    {:fill_region, x, y, width, height, cell}
  end

  defp build_fill_region_operation(false, x, y, width, height, cell) do
    {:fill_region, x, y, width, height, cell, :invalid_coordinates}
  end

  defp process_queue_if_needed(true, state) do
    new_state = Raxol.Terminal.Buffer.Helper.process_batch(state)
    {:noreply, new_state}
  end

  defp process_queue_if_needed(false, state) do
    {:noreply, state}
  end
end
