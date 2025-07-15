defmodule Raxol.Terminal.Buffer.BufferServerRefactored do
  @moduledoc """
  Refactored GenServer-based buffer server for true concurrent shared buffer access.

  This module demonstrates the improved modular architecture by delegating
  responsibilities to specialized modules:
  - OperationProcessor: Handles operation processing and batching
  - OperationQueue: Manages the queue of pending operations
  - MetricsTracker: Tracks performance metrics and memory usage
  - DamageTracker: Tracks damaged regions for efficient rendering

  ## Features

  - Thread-safe concurrent access
  - Asynchronous write operations for better performance
  - Batch operations for multiple writes
  - Atomic operations
  - Performance monitoring
  - Memory management
  - Damage tracking for efficient rendering

  ## Usage

      # Start a buffer server
      {:ok, pid} = BufferServerRefactored.start_link(width: 80, height: 24)

      # Write to buffer (asynchronous)
      BufferServerRefactored.set_cell(pid, 0, 0, cell)

      # Read from buffer (synchronous)
      cell = BufferServerRefactored.get_cell(pid, 0, 0)

      # Batch multiple operations
      BufferServerRefactored.batch_operations(pid, [
        {:set_cell, 0, 0, cell1},
        {:set_cell, 1, 0, cell2},
        {:write_string, 0, 1, "Hello"}
      ])

      # Flush to ensure all writes are completed
      BufferServerRefactored.flush(pid)

      # Perform atomic operations
      BufferServerRefactored.atomic_operation(pid, fn buffer ->
        # Multiple operations in a single atomic transaction
        buffer
        |> Buffer.set_cell(0, 0, cell1)
        |> Buffer.set_cell(1, 0, cell2)
      end)
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.Buffer.Operations, as: Buffer
  alias Raxol.Terminal.Buffer.Cell
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Content

  # New modular components
  alias Raxol.Terminal.Buffer.OperationProcessor
  alias Raxol.Terminal.Buffer.OperationQueue
  alias Raxol.Terminal.Buffer.MetricsTracker
  alias Raxol.Terminal.Buffer.DamageTracker

  @type t :: pid()

  defmodule State do
    @moduledoc "State for the BufferServerRefactored GenServer"

    defstruct [
      :buffer,
      :operation_queue,
      :metrics,
      :damage_tracker,
      :memory_limit,
      :memory_usage
    ]
  end

  # Client API

  @doc """
  Starts a new buffer server process.

  ## Options

  * `:width` - Buffer width (default: 80)
  * `:height` - Buffer height (default: 24)
  * `:name` - Process name for registration
  * `:memory_limit` - Memory usage limit in bytes (default: 10_000_000)

  ## Returns

  * `{:ok, pid}` - The process ID of the started buffer server
  * `{:error, reason}` - If the server fails to start
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    gen_server_opts = Keyword.delete(opts, :name)

    # Ensure we have a valid name for GenServer
    valid_name =
      case name do
        nil -> __MODULE__
        # Don't use references as names
        ref when is_reference(ref) -> nil
        atom when is_atom(atom) -> atom
        {:global, term} -> {:global, term}
        {:via, module, term} -> {:via, module, term}
        # Fallback to module name
        _ -> __MODULE__
      end

    if valid_name do
      GenServer.start_link(__MODULE__, gen_server_opts, name: valid_name)
    else
      GenServer.start_link(__MODULE__, gen_server_opts)
    end
  end

  @doc """
  Stops the buffer server.
  """
  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Gets a cell from the buffer at the specified coordinates.

  ## Parameters

  * `pid` - The buffer server process ID
  * `x` - X coordinate
  * `y` - Y coordinate

  ## Returns

  * `{:ok, cell}` - The cell at the specified position
  * `{:error, reason}` - If the operation fails
  """
  @spec get_cell(pid(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Cell.t()} | {:error, term()}
  def get_cell(pid, x, y)
      when is_pid(pid) and is_integer(x) and is_integer(y) do
    GenServer.call(pid, {:get_cell, x, y})
  end

  @doc """
  Sets a cell in the buffer at the specified coordinates (asynchronous).

  ## Parameters

  * `pid` - The buffer server process ID
  * `x` - X coordinate
  * `y` - Y coordinate
  * `cell` - The cell to set

  ## Returns

  * `:ok` - If the operation was queued successfully
  """
  @spec set_cell(pid(), non_neg_integer(), non_neg_integer(), Cell.t()) :: :ok
  def set_cell(pid, x, y, cell)
      when is_pid(pid) and is_integer(x) and is_integer(y) do
    GenServer.cast(pid, {:set_cell, x, y, cell})
  end

  @doc """
  Sets a cell in the buffer at the specified coordinates (synchronous with validation).

  ## Parameters

  * `pid` - The buffer server process ID
  * `x` - X coordinate
  * `y` - Y coordinate
  * `cell` - The cell to set

  ## Returns

  * `:ok` - If the operation was successful
  * `{:error, :invalid_coordinates}` - If coordinates are out of bounds
  """
  @spec set_cell_sync(pid(), non_neg_integer(), non_neg_integer(), Cell.t()) ::
          :ok | {:error, :invalid_coordinates}
  def set_cell_sync(pid, x, y, cell)
      when is_pid(pid) and is_integer(x) and is_integer(y) do
    GenServer.call(pid, {:set_cell_sync, x, y, cell})
  end

  @doc """
  Writes a string to the buffer at the specified coordinates (asynchronous).

  ## Parameters

  * `pid` - The buffer server process ID
  * `x` - Starting X coordinate
  * `y` - Starting Y coordinate
  * `string` - The string to write

  ## Returns

  * `:ok` - If the operation was queued successfully
  * `{:error, :invalid_coordinates}` - If coordinates are out of bounds
  """
  @spec write_string(pid(), non_neg_integer(), non_neg_integer(), String.t()) ::
          :ok | {:error, :invalid_coordinates}
  def write_string(pid, x, y, string) when is_pid(pid) and is_binary(string) do
    GenServer.cast(pid, {:write_string, x, y, string})
  end

  @doc """
  Fills a region of the buffer with a cell (asynchronous).

  ## Parameters

  * `pid` - The buffer server process ID
  * `x` - Starting X coordinate
  * `y` - Starting Y coordinate
  * `width` - Width of the region
  * `height` - Height of the region
  * `cell` - The cell to fill with

  ## Returns

  * `:ok` - If the operation was queued successfully
  * `{:error, :invalid_coordinates}` - If coordinates are out of bounds
  """
  @spec fill_region(
          pid(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Cell.t()
        ) :: :ok | {:error, :invalid_coordinates}
  def fill_region(pid, x, y, width, height, cell) when is_pid(pid) do
    GenServer.cast(pid, {:fill_region, x, y, width, height, cell})
  end

  @doc """
  Scrolls the buffer by the specified number of lines (asynchronous).

  ## Parameters

  * `pid` - The buffer server process ID
  * `lines` - Number of lines to scroll (positive for up, negative for down)

  ## Returns

  * `:ok` - If the operation was queued successfully
  """
  @spec scroll(pid(), integer()) :: :ok
  def scroll(pid, lines) when is_pid(pid) and is_integer(lines) do
    GenServer.cast(pid, {:scroll, lines})
  end

  @doc """
  Resizes the buffer to the specified dimensions (asynchronous).

  ## Parameters

  * `pid` - The buffer server process ID
  * `width` - New width
  * `height` - New height

  ## Returns

  * `:ok` - If the operation was queued successfully
  """
  @spec resize(pid(), non_neg_integer(), non_neg_integer()) :: :ok
  def resize(pid, width, height)
      when is_pid(pid) and is_integer(width) and is_integer(height) do
    GenServer.cast(pid, {:resize, width, height})
  end

  @doc """
  Performs multiple operations in a batch (asynchronous).

  ## Parameters

  * `pid` - The buffer server process ID
  * `operations` - List of operations to perform

  ## Returns

  * `:ok` - If the operations were queued successfully
  """
  @spec batch_operations(pid(), list()) :: :ok
  def batch_operations(pid, operations)
      when is_pid(pid) and is_list(operations) do
    GenServer.cast(pid, {:batch_operations, operations})
  end

  @doc """
  Flushes all pending operations and waits for completion.

  ## Parameters

  * `pid` - The buffer server process ID

  ## Returns

  * `:ok` - If all operations completed successfully
  * `{:error, reason}` - If any operation failed
  """
  @spec flush(pid()) :: :ok | {:error, term()}
  def flush(pid) when is_pid(pid) do
    GenServer.call(pid, :flush)
  end

  @doc """
  Gets the current buffer dimensions.

  ## Parameters

  * `pid` - The buffer server process ID

  ## Returns

  * `{:ok, {width, height}}` - The buffer dimensions
  * `{:error, reason}` - If the operation fails
  """
  @spec get_dimensions(pid()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, term()}
  def get_dimensions(pid) when is_pid(pid) do
    GenServer.call(pid, :get_dimensions)
  end

  @doc """
  Gets the entire buffer content.

  ## Parameters

  * `pid` - The buffer server process ID

  ## Returns

  * `{:ok, buffer}` - The complete buffer struct
  * `{:error, reason}` - If the operation fails
  """
  @spec get_buffer(pid()) :: {:ok, Buffer.t()} | {:error, term()}
  def get_buffer(pid) when is_pid(pid) do
    GenServer.call(pid, :get_buffer)
  end

  @doc """
  Performs an atomic operation on the buffer.

  This ensures that the entire operation is performed atomically,
  preventing race conditions in concurrent scenarios.

  ## Parameters

  * `pid` - The buffer server process ID
  * `operation` - A function that takes a buffer and returns a modified buffer

  ## Returns

  * `{:ok, result}` - The result of the operation
  * `{:error, reason}` - If the operation fails
  """
  @spec atomic_operation(pid(), (Buffer.t() -> Buffer.t())) ::
          :ok | {:error, term()}
  def atomic_operation(pid, operation)
      when is_pid(pid) and is_function(operation, 1) do
    case GenServer.call(pid, {:atomic_operation, operation}) do
      {:ok, _buffer} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets performance metrics for the buffer server.

  ## Parameters

  * `pid` - The buffer server process ID

  ## Returns

  * `{:ok, metrics}` - Performance metrics map
  * `{:error, reason}` - If the operation fails
  """
  @spec get_metrics(pid()) :: {:ok, map()} | {:error, term()}
  def get_metrics(pid) when is_pid(pid) do
    GenServer.call(pid, :get_metrics)
  end

  @spec get_metrics(pid()) :: map()
  def get_metrics(pid) when is_pid(pid) do
    case GenServer.call(pid, :get_metrics) do
      {:ok, metrics} -> metrics
      {:error, _} -> %{}
    end
  end

  @doc """
  Gets memory usage for the buffer server.

  ## Parameters

  * `pid` - The buffer server process ID

  ## Returns

  * `memory_usage` - Memory usage in bytes
  """
  @spec get_memory_usage(pid()) :: non_neg_integer()
  def get_memory_usage(pid) when is_pid(pid) do
    GenServer.call(pid, :get_memory_usage)
  end

  @doc """
  Gets damage regions for the buffer server.

  ## Parameters

  * `pid` - The buffer server process ID

  ## Returns

  * `damage_regions` - List of damage regions
  """
  @spec get_damage_regions(pid()) :: list()
  def get_damage_regions(pid) when is_pid(pid) do
    GenServer.call(pid, :get_damage_regions)
  end

  @doc """
  Clears damage regions for the buffer server.

  ## Parameters

  * `pid` - The buffer server process ID

  ## Returns

  * `:ok` - If the operation was successful
  """
  @spec clear_damage_regions(pid()) :: :ok
  def clear_damage_regions(pid) when is_pid(pid) do
    GenServer.call(pid, :clear_damage_regions)
  end

  @doc """
  Gets the buffer content as a string.

  ## Parameters

  * `pid` - The buffer server process ID

  ## Returns

  * `content` - Buffer content as string
  """
  @spec get_content(pid()) :: String.t()
  def get_content(pid) when is_pid(pid) do
    case GenServer.call(pid, :get_content) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end

  # Server Callbacks

  @impl GenServer
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
      state = %State{
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

  @impl GenServer
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
        _kind, reason ->
          Logger.error("Failed to get cell at (#{x}, #{y}): #{inspect(reason)}")
          {:reply, {:error, {_kind, reason}}, state}
      end
    else
      {:reply, {:error, :invalid_coordinates}, state}
    end
  end

  @impl GenServer
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
            update_metrics_for_operations(operations, state.metrics, start_time)

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

  @impl GenServer
  def handle_call(:get_dimensions, _from, state) do
    {:reply, {state.buffer.width, state.buffer.height}, state}
  end

  @impl GenServer
  def handle_call(:get_buffer, _from, state) do
    {:reply, {:ok, state.buffer}, state}
  end

  @impl GenServer
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
      _kind, reason ->
        Logger.error("Failed to perform atomic operation: #{inspect(reason)}")
        {:reply, {:error, {_kind, reason}}, state}
    end
  end

  @impl GenServer
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
        _kind, reason ->
          Logger.error("Failed to set cell at (#{x}, #{y}): #{inspect(reason)}")
          {:reply, {:error, {_kind, reason}}, state}
      end
    else
      {:reply, {:error, :invalid_coordinates}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    {:reply, {:ok, MetricsTracker.get_summary(state.metrics)}, state}
  end

  @impl GenServer
  def handle_call(:get_memory_usage, _from, state) do
    {:reply, state.memory_usage, state}
  end

  @impl GenServer
  def handle_call(:get_damage_regions, _from, state) do
    {:reply, DamageTracker.get_damage_regions(state.damage_tracker), state}
  end

  @impl GenServer
  def handle_call(:clear_damage_regions, _from, state) do
    new_damage_tracker = DamageTracker.clear_damage(state.damage_tracker)
    {:reply, :ok, %{state | damage_tracker: new_damage_tracker}}
  end

  @impl GenServer
  def handle_call(:get_content, _from, state) do
    content = buffer_to_string(state.buffer)
    {:reply, {:ok, content}, state}
  end

  @impl GenServer
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
      new_state = process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @impl GenServer
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
      new_state = process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @impl GenServer
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
      new_state = process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:scroll, lines}, state) do
    operation = {:scroll, lines}
    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    if OperationQueue.should_process?(new_queue) do
      new_state = process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:resize, width, height}, state) do
    operation = {:resize, width, height}
    new_queue = OperationQueue.add_operation(state.operation_queue, operation)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    if OperationQueue.should_process?(new_queue) do
      new_state = process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:batch_operations, operations}, state) do
    new_queue = OperationQueue.add_operations(state.operation_queue, operations)
    new_state = %{state | operation_queue: new_queue}

    # Process batch if conditions are met
    if OperationQueue.should_process?(new_queue) do
      new_state = process_batch(new_state)
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  # Private helper functions

  defp update_metrics_for_operations(operations, metrics, start_time) do
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

  defp buffer_to_string(buffer) do
    buffer.cells
    |> Enum.map_join("\n", fn row ->
      row
      |> Enum.map_join("", fn cell -> cell.char end)
    end)
  end

  defp process_batch(state) do
    if OperationQueue.empty?(state.operation_queue) do
      state
    else
      # Mark as processing
      new_queue = OperationQueue.mark_processing(state.operation_queue)

      try do
        # Get a batch of operations to process
        {operations_to_process, remaining_queue} =
          OperationQueue.get_batch(new_queue, new_queue.batch_size)

        # Track start time for metrics
        start_time = System.monotonic_time()

        # Process the operations
        new_buffer =
          OperationProcessor.process_batch(operations_to_process, state.buffer)

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
      catch
        _kind, reason ->
          Logger.error("Error processing batch operations: #{inspect(reason)}")
          # Always reset processing flag, even on error
          final_queue =
            OperationQueue.mark_not_processing(state.operation_queue)

          %{state | operation_queue: final_queue}
      end
    end
  end
end
