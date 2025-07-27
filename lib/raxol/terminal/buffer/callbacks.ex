defmodule Raxol.Terminal.Buffer.Callbacks do
  @moduledoc """
  GenServer callbacks for the buffer server.
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
    if width <= 0 or height <= 0 do
      {:stop, {:invalid_dimensions, {width, height}}}
    else
      # Create initial buffer
      buffer = ScreenBuffer.new(width, height)

      # Initialize modular components
      operation_queue = OperationQueue.new(50)
      metrics = MetricsTracker.new()
      damage_tracker = DamageTracker.new(100)
      memory_usage = MetricsTracker.calculate_memory_usage(buffer)

      # Initialize state
      state = %Raxol.Terminal.Buffer.BufferServerRefactored.State{
        buffer: buffer,
        operation_queue: operation_queue,
        metrics: metrics,
        damage_tracker: damage_tracker,
        memory_limit: memory_limit,
        memory_usage: memory_usage
      }

      Logger.debug(
        "BufferServerRefactored started with dimensions #{width}x#{height}"
      )

      {:ok, state}
    end
  end

  @doc """
  Handles synchronous calls to the buffer server.
  """
  def handle_call({:get_cell, x, y}, _from, state) do
    start_time = System.monotonic_time()

    if OperationProcessor.valid_coordinates?(state.buffer, x, y) do
      try do
        cell = Content.get_cell(state.buffer, x, y)

        new_metrics =
          MetricsTracker.update_metrics(state.metrics, :reads, start_time)

        new_state = %{state | metrics: new_metrics}
        {:reply, {:ok, cell}, new_state}
      catch
        kind, reason ->
          Logger.error("Failed to get cell at (#{x}, #{y}): #{inspect(reason)}")
          {:reply, {:error, {kind, reason}}, state}
      end
    else
      {:reply, {:error, :invalid_coordinates}, state}
    end
  end

  def handle_call(:flush, _from, state) do
    # Process all pending operations synchronously
    new_state =
      if OperationQueue.empty?(state.operation_queue) do
        state
      else
        try do
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
        catch
          _kind, reason ->
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

    try do
      new_buffer = operation.(state.buffer)

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
    catch
      kind, reason ->
        Logger.error("Failed to perform atomic operation: #{inspect(reason)}")
        {:reply, {:error, {kind, reason}}, state}
    end
  end

  def handle_call({:set_cell_sync, x, y, cell}, _from, state) do
    start_time = System.monotonic_time()

    if OperationProcessor.valid_coordinates?(state.buffer, x, y) do
      try do
        new_buffer = Content.write_char(state.buffer, x, y, cell.char, cell)

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
      catch
        kind, reason ->
          Logger.error("Failed to set cell at (#{x}, #{y}): #{inspect(reason)}")
          {:reply, {:error, {kind, reason}}, state}
      end
    else
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
end
