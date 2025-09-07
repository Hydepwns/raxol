defmodule Raxol.Terminal.Buffer.Helpers do
  @moduledoc """
  Helper functions for the buffer server.
  """

  require Logger

  alias Raxol.Terminal.Buffer.OperationProcessor
  alias Raxol.Terminal.Buffer.OperationQueue
  alias Raxol.Terminal.Buffer.MetricsTracker

  @doc """
  Updates metrics for a list of operations.
  """
  def update_metrics_for_operations(operations, metrics, start_time) do
    Enum.reduce(operations, metrics, fn operation, acc ->
      case operation do
        {:set_cell, _x, _y, _cell} ->
          MetricsTracker.update_metrics(acc, :writes, start_time)

        {:write_string, _x, _y, _string} ->
          MetricsTracker.update_metrics(acc, :writes, start_time)

        {:fill_region, _x, _y, _width, _height, _cell} ->
          MetricsTracker.update_metrics(acc, :writes, start_time)

        {:scroll, _lines} ->
          MetricsTracker.update_metrics(acc, :scrolls, start_time)

        {:resize, _width, _height} ->
          MetricsTracker.update_metrics(acc, :resizes, start_time)

        _ ->
          acc
      end
    end)
  end

  @doc """
  Converts a buffer to a string representation.
  """
  def buffer_to_string(buffer) do
    buffer.cells
    |> Enum.map_join("\n", fn row ->
      row
      |> Enum.map_join("", fn cell -> cell.char end)
    end)
  end

  @doc """
  Processes a batch of operations.
  """
  def process_batch(state) do
    case OperationQueue.empty?(state.operation_queue) do
      true ->
        state

      false ->
        # Mark as processing
        new_queue = OperationQueue.mark_processing(state.operation_queue)

        case Raxol.Core.ErrorHandling.safe_call(fn ->
               # Get a batch of operations to process
               {operations_to_process, remaining_queue} =
                 OperationQueue.get_batch(new_queue, new_queue.batch_size)

               # Track start time for metrics
               start_time = System.monotonic_time()

               # Process the operations
               new_buffer =
                 OperationProcessor.process_batch(
                   operations_to_process,
                   state.buffer
                 )

               # Update metrics based on operation types
               new_metrics =
                 update_metrics_for_operations(
                   operations_to_process,
                   state.metrics,
                   start_time
                 )

               # Update state
               final_queue = OperationQueue.mark_not_processing(remaining_queue)

               %{
                 state
                 | buffer: new_buffer,
                   operation_queue: final_queue,
                   metrics: new_metrics
               }
             end) do
          {:ok, result} ->
            result

          {:error, reason} ->
            Logger.error(
              "Error processing batch operations: #{inspect(reason)}"
            )

            # Always reset processing flag, even on error
            final_queue =
              OperationQueue.mark_not_processing(state.operation_queue)

            %{state | operation_queue: final_queue}
        end
    end
  end
end
