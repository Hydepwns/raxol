defmodule Raxol.Terminal.Buffer.Callbacks do
  @moduledoc """
  GenServer callbacks for the buffer server - Functional Programming Version.

  This module replaces all try/catch blocks with functional error handling
  using with statements and proper error tuples.
  """

  require Logger

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Content

  # Modular components
  alias Raxol.Terminal.Buffer.OperationProcessor
  alias Raxol.Terminal.Buffer.OperationQueue
  alias Raxol.Terminal.Buffer.MetricsTracker
  alias Raxol.Terminal.Buffer.DamageTracker

  @doc """
  Initializes the buffer server.
  """
  def init(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    memory_limit = Keyword.get(opts, :memory_limit, 10_000_000)

    # Validate dimensions
    case width <= 0 or height <= 0 do
      true ->
        {:stop, {:invalid_dimensions, {width, height}}}

      false ->
        # Create initial buffer
        buffer = ScreenBuffer.new(width, height)

        # Initialize modular components
        operation_queue = OperationQueue.new(50)
        metrics = MetricsTracker.new()
        damage_tracker = DamageTracker.new(100)
        memory_usage = MetricsTracker.calculate_memory_usage(buffer)

        # Initialize state
        state = %Raxol.Terminal.Buffer.BufferServer.State{
          buffer: buffer,
          operation_queue: operation_queue,
          metrics: metrics,
          damage_tracker: damage_tracker,
          memory_limit: memory_limit,
          memory_usage: memory_usage
        }

        Logger.debug("BufferServer started with dimensions #{width}x#{height}")

        {:ok, state}
    end
  end

  @doc """
  Handles synchronous calls to the buffer server.
  """
  def handle_call({:get_cell, x, y}, _from, state) do
    start_time = System.monotonic_time()

    case OperationProcessor.valid_coordinates?(state.buffer, x, y) do
      true ->
        with {:ok, cell} <- safe_get_cell(state.buffer, x, y) do
          new_metrics =
            MetricsTracker.update_metrics(state.metrics, :reads, start_time)

          new_state = %{state | metrics: new_metrics}
          {:reply, {:ok, cell}, new_state}
        else
          {:error, reason} ->
            Logger.error(
              "Failed to get cell at (#{x}, #{y}): #{inspect(reason)}"
            )

            {:reply, {:error, reason}, state}
        end

      false ->
        {:reply, {:error, :invalid_coordinates}, state}
    end
  end

  def handle_call(:flush, _from, state) do
    # Process all pending operations synchronously
    new_state =
      case OperationQueue.empty?(state.operation_queue) do
        true ->
          state

        false ->
          with {:ok, processed_state} <- safe_flush_operations(state) do
            processed_state
          else
            {:error, reason} ->
              Logger.error(
                "Error processing flush operations: #{inspect(reason)}"
              )

              state
          end
      end

    {:reply, :ok, new_state}
  end

  def handle_call(:get_dimensions, _from, state) do
    {:reply, {state.buffer.width, state.buffer.height}, state}
  end

  def handle_call(:get_buffer, _from, state) do
    {:reply, {:ok, state.buffer}, state}
  end

  def handle_call({:atomic_operation, operation}, _from, state) do
    start_time = System.monotonic_time()

    with {:ok, new_buffer} <- safe_apply_operation(operation, state.buffer) do
      new_metrics =
        MetricsTracker.update_metrics(state.metrics, :writes, start_time)

      new_damage_tracker =
        DamageTracker.add_damage_region(
          state.damage_tracker,
          0,
          0,
          new_buffer.width,
          new_buffer.height
        )

      new_state = %{
        state
        | buffer: new_buffer,
          metrics: new_metrics,
          damage_tracker: new_damage_tracker
      }

      {:reply, {:ok, new_buffer}, new_state}
    else
      {:error, reason} ->
        Logger.error("Failed to perform atomic operation: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:set_cell_sync, x, y, cell}, _from, state) do
    start_time = System.monotonic_time()

    case OperationProcessor.valid_coordinates?(state.buffer, x, y) do
      true ->
        with {:ok, new_buffer} <- safe_write_char(state.buffer, x, y, cell) do
          new_metrics =
            MetricsTracker.update_metrics(state.metrics, :writes, start_time)

          new_damage_tracker =
            DamageTracker.add_damage_region(state.damage_tracker, x, y, 1, 1)

          new_state = %{
            state
            | buffer: new_buffer,
              metrics: new_metrics,
              damage_tracker: new_damage_tracker
          }

          {:reply, :ok, new_state}
        else
          {:error, reason} ->
            Logger.error(
              "Failed to set cell at (#{x}, #{y}): #{inspect(reason)}"
            )

            {:reply, {:error, reason}, state}
        end

      false ->
        {:reply, {:error, :invalid_coordinates}, state}
    end
  end

  def handle_call(:get_metrics, _from, state) do
    {:reply, {:ok, MetricsTracker.get_summary(state.metrics)}, state}
  end

  def handle_call(:get_memory_usage, _from, state) do
    {:reply, state.memory_usage, state}
  end

  def handle_call(:get_damage_regions, _from, state) do
    {:reply, DamageTracker.get_damage_regions(state.damage_tracker), state}
  end

  def handle_call(:clear_damage_regions, _from, state) do
    new_damage_tracker = DamageTracker.clear_damage(state.damage_tracker)
    {:reply, :ok, %{state | damage_tracker: new_damage_tracker}}
  end

  def handle_call(:get_content, _from, state) do
    content = Raxol.Terminal.Buffer.Helpers.buffer_to_string(state.buffer)
    {:reply, {:ok, content}, state}
  end

  ## Private Helper Functions

  defp safe_get_cell(buffer, x, y) do
    Task.async(fn -> Content.get_cell(buffer, x, y) end)
    |> Task.yield(1000)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:exit, reason} ->
        {:error, {:exit, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_flush_operations(state) do
    Task.async(fn ->
      # Get all operations and clear the queue
      {operations, new_queue} =
        OperationQueue.get_all(state.operation_queue)

      # Track start time for metrics
      start_time = System.monotonic_time()

      # Process all operations
      new_buffer =
        OperationProcessor.process_all_operations(operations, state.buffer)

      # Update metrics based on operation types
      new_metrics =
        Raxol.Terminal.Buffer.Helpers.update_metrics_for_operations(
          operations,
          state.metrics,
          start_time
        )

      # Update state
      %{
        state
        | buffer: new_buffer,
          operation_queue: new_queue,
          metrics: new_metrics
      }
    end)
    |> Task.yield(5000)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:exit, reason} ->
        {:error, {:exit, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_apply_operation(operation, buffer) do
    Task.async(fn -> operation.(buffer) end)
    |> Task.yield(2000)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:exit, reason} ->
        {:error, {:exit, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_write_char(buffer, x, y, cell) do
    Task.async(fn -> Content.write_char(buffer, x, y, cell.char, cell) end)
    |> Task.yield(1000)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:exit, reason} ->
        {:error, {:exit, reason}}

      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end
end
