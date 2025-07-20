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
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Content

  # New modular components
  alias Raxol.Terminal.Buffer.OperationProcessor
  alias Raxol.Terminal.Buffer.OperationQueue
  alias Raxol.Terminal.Buffer.MetricsTracker
  alias Raxol.Terminal.Buffer.DamageTracker

  # Refactored modules
  alias Raxol.Terminal.Buffer.{Callbacks, Handlers, Helpers}

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
  def init(opts), do: Callbacks.init(opts)

  @impl GenServer
  def handle_call({:get_cell, x, y}, from, state), do: Callbacks.handle_call({:get_cell, x, y}, from, state)
  def handle_call(:flush, from, state), do: Callbacks.handle_call(:flush, from, state)
  def handle_call(:get_dimensions, from, state), do: Callbacks.handle_call(:get_dimensions, from, state)
  def handle_call(:get_buffer, from, state), do: Callbacks.handle_call(:get_buffer, from, state)
  def handle_call({:atomic_operation, operation}, from, state), do: Callbacks.handle_call({:atomic_operation, operation}, from, state)
  def handle_call({:set_cell_sync, x, y, cell}, from, state), do: Callbacks.handle_call({:set_cell_sync, x, y, cell}, from, state)
  def handle_call(:get_metrics, from, state), do: Callbacks.handle_call(:get_metrics, from, state)
  def handle_call(:get_memory_usage, from, state), do: Callbacks.handle_call(:get_memory_usage, from, state)
  def handle_call(:get_damage_regions, from, state), do: Callbacks.handle_call(:get_damage_regions, from, state)
  def handle_call(:clear_damage_regions, from, state), do: Callbacks.handle_call(:clear_damage_regions, from, state)
  def handle_call(:get_content, from, state), do: Callbacks.handle_call(:get_content, from, state)

  @impl GenServer
  def handle_cast({:set_cell, x, y, cell}, state), do: Handlers.handle_cast({:set_cell, x, y, cell}, state)
  def handle_cast({:write_string, x, y, string}, state), do: Handlers.handle_cast({:write_string, x, y, string}, state)
  def handle_cast({:fill_region, x, y, width, height, cell}, state), do: Handlers.handle_cast({:fill_region, x, y, width, height, cell}, state)
  def handle_cast({:scroll, lines}, state), do: Handlers.handle_cast({:scroll, lines}, state)
  def handle_cast({:resize, width, height}, state), do: Handlers.handle_cast({:resize, width, height}, state)
  def handle_cast({:batch_operations, operations}, state), do: Handlers.handle_cast({:batch_operations, operations}, state)

end
