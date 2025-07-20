defmodule Raxol.Terminal.Buffer.Handlers do
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
      if OperationProcessor.valid_coordinates?(state.buffer, x, y) do
        {:set_cell, x, y, cell}
      else
        {:set_cell, x, y, cell, :invalid_coordinates}
      end

    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    if OperationQueue.should_process?(new_queue) do
      new_state = Raxol.Terminal.Buffer.Helpers.process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @doc """
  Handles asynchronous write_string operations.
  """
  def handle_cast({:write_string, x, y, string}, state) do
    # Validate coordinates and add operation to queue
    operation =
      if OperationProcessor.valid_coordinates?(state.buffer, x, y) do
        {:write_string, x, y, string}
      else
        {:write_string, x, y, string, :invalid_coordinates}
      end

    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    if OperationQueue.should_process?(new_queue) do
      new_state = Raxol.Terminal.Buffer.Helpers.process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @doc """
  Handles asynchronous fill_region operations.
  """
  def handle_cast({:fill_region, x, y, width, height, cell}, state) do
    # Validate coordinates and add operation to queue
    operation =
      if OperationProcessor.valid_fill_region_coordinates?(
           state.buffer,
           x,
           y,
           width,
           height
         ) do
        {:fill_region, x, y, width, height, cell}
      else
        {:fill_region, x, y, width, height, cell, :invalid_coordinates}
      end

    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    if OperationQueue.should_process?(new_queue) do
      new_state = Raxol.Terminal.Buffer.Helpers.process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @doc """
  Handles asynchronous scroll operations.
  """
  def handle_cast({:scroll, lines}, state) do
    operation = {:scroll, lines}
    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    if OperationQueue.should_process?(new_queue) do
      new_state = Raxol.Terminal.Buffer.Helpers.process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @doc """
  Handles asynchronous resize operations.
  """
  def handle_cast({:resize, width, height}, state) do
    operation = {:resize, width, height}
    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    if OperationQueue.should_process?(new_queue) do
      new_state = Raxol.Terminal.Buffer.Helpers.process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @doc """
  Handles asynchronous batch_operations.
  """
  def handle_cast({:batch_operations, operations}, state) do
    new_queue = OperationQueue.add_operations(state.operation_queue, operations)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    if OperationQueue.should_process?(new_queue) do
      new_state = Raxol.Terminal.Buffer.Helpers.process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end
end
