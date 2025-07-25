defmodule Raxol.Terminal.Buffer.ConcurrentBuffer do
  @moduledoc """
  Unified buffer interface that supports both struct-based and GenServer-based access.

  This module provides a compatibility layer that allows existing code to work with
  either the traditional struct-based Buffer or the new concurrent BufferServer,
  enabling gradual migration to the concurrent approach.

  ## Usage

  ### Struct-based (traditional)

      buffer = ConcurrentBuffer.new({80, 24})
      buffer = ConcurrentBuffer.set_cell(buffer, 0, 0, cell)
      cell = ConcurrentBuffer.get_cell(buffer, 0, 0)

  ### GenServer-based (concurrent)

      {:ok, pid} = ConcurrentBuffer.start_server(width: 80, height: 24)
      :ok = ConcurrentBuffer.set_cell(pid, 0, 0, cell)
      {:ok, cell} = ConcurrentBuffer.get_cell(pid, 0, 0)

  ### Mixed mode (for migration)

      # Start with struct, convert to server when needed
      buffer = ConcurrentBuffer.new({80, 24})
      buffer = ConcurrentBuffer.set_cell(buffer, 0, 0, cell)

      # Convert to server for concurrent access
      {:ok, pid} = ConcurrentBuffer.to_server(buffer)
      :ok = ConcurrentBuffer.set_cell(pid, 0, 0, cell)
  """

  alias Raxol.Terminal.Buffer
  alias Raxol.Terminal.Buffer.BufferServerRefactored
  alias Raxol.Terminal.Buffer.Cell

  @type buffer_or_pid :: Buffer.t() | pid()

  @doc """
  Creates a new buffer with the specified dimensions.

  ## Parameters

  * `dimensions` - `{width, height}` tuple

  ## Returns

  * `Buffer.t()` - A new buffer struct
  """
  @spec new({non_neg_integer(), non_neg_integer()}) :: Buffer.t()
  def new(dimensions) do
    Buffer.new(dimensions)
  end

  @doc """
  Starts a new buffer server process.

  ## Parameters

  * `opts` - Options for the buffer server

  ## Returns

  * `{:ok, pid}` - The process ID of the started buffer server
  * `{:error, reason}` - If the server fails to start
  """
  @spec start_server(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_server(opts \\ []) do
    BufferServerRefactored.start_link(opts)
  end

  @doc """
  Converts a buffer struct to a buffer server.

  ## Parameters

  * `buffer` - The buffer struct to convert

  ## Returns

  * `{:ok, pid}` - The process ID of the new buffer server
  * `{:error, reason}` - If the conversion fails
  """
  @spec to_server(Buffer.t()) :: {:ok, pid()} | {:error, term()}
  def to_server(buffer) do
    opts = [
      width: buffer.width,
      height: buffer.height
    ]

    case BufferServerRefactored.start_link(opts) do
      {:ok, pid} ->
        # Copy the buffer content to the server
        copy_buffer_to_server(buffer, pid)
        {:ok, pid}

      error ->
        error
    end
  end

  @doc """
  Sets a cell in the buffer.

  Works with both buffer structs and buffer server PIDs.

  ## Parameters

  * `buffer_or_pid` - Either a buffer struct or a buffer server PID
  * `x` - X coordinate
  * `y` - Y coordinate
  * `cell` - The cell to set

  ## Returns

  * For structs: `Buffer.t()` - The updated buffer
  * For PIDs: `:ok` or `{:error, reason}`
  """
  @spec set_cell(
          buffer_or_pid(),
          non_neg_integer(),
          non_neg_integer(),
          Cell.t()
        ) :: Buffer.t() | :ok | {:error, term()}
  def set_cell(buffer_or_pid, x, y, cell) do
    case buffer_or_pid do
      %Buffer{} = buffer ->
        Buffer.set_cell(buffer, x, y, cell)

      pid when is_pid(pid) ->
        BufferServerRefactored.set_cell(pid, x, y, cell)
    end
  end

  @spec set_cell_sync(pid(), non_neg_integer(), non_neg_integer(), Cell.t()) ::
          :ok | {:error, :invalid_coordinates}
  def set_cell_sync(pid, x, y, cell) when is_pid(pid) do
    BufferServerRefactored.set_cell_sync(pid, x, y, cell)
  end

  @doc """
  Gets a cell from the buffer.

  Works with both buffer structs and buffer server PIDs.

  ## Parameters

  * `buffer_or_pid` - Either a buffer struct or a buffer server PID
  * `x` - X coordinate
  * `y` - Y coordinate

  ## Returns

  * For structs: `Cell.t()` - The cell at the specified position
  * For PIDs: `{:ok, Cell.t()}` or `{:error, reason}`
  """
  @spec get_cell(buffer_or_pid(), non_neg_integer(), non_neg_integer()) ::
          Cell.t() | {:ok, Cell.t()} | {:error, term()}
  def get_cell(buffer_or_pid, x, y) do
    case buffer_or_pid do
      %Buffer{} = buffer ->
        Buffer.get_cell(buffer, x, y)

      pid when is_pid(pid) ->
        BufferServerRefactored.get_cell(pid, x, y)
    end
  end

  @doc """
  Writes a string to the buffer.

  Works with both buffer structs and buffer server PIDs.

  ## Parameters

  * `buffer_or_pid` - Either a buffer struct or a buffer server PID
  * `string` - The string to write
  * `opts` - Options for writing

  ## Returns

  * For structs: `Buffer.t()` - The updated buffer
  * For PIDs: `:ok` or `{:error, reason}`
  """
  @spec write(buffer_or_pid(), String.t(), keyword()) ::
          Buffer.t() | :ok | {:error, term()}
  def write(buffer_or_pid, string, opts \\ []) do
    case buffer_or_pid do
      %Buffer{} = buffer ->
        Buffer.write(buffer, string, opts)

      pid when is_pid(pid) ->
        # For server, we need to write at cursor position
        # This is a simplified implementation
        BufferServerRefactored.write_string(pid, 0, 0, string)
    end
  end

  @doc """
  Fills a region of the buffer with a cell.

  Works with both buffer structs and buffer server PIDs.

  ## Parameters

  * `buffer_or_pid` - Either a buffer struct or a buffer server PID
  * `x` - Starting X coordinate
  * `y` - Starting Y coordinate
  * `width` - Width of the region
  * `height` - Height of the region
  * `cell` - The cell to fill with

  ## Returns

  * For structs: `Buffer.t()` - The updated buffer
  * For PIDs: `:ok` or `{:error, reason}`
  """
  @spec fill_region(
          buffer_or_pid(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Cell.t()
        ) :: Buffer.t() | :ok | {:error, term()}
  def fill_region(buffer_or_pid, x, y, width, height, cell) do
    case buffer_or_pid do
      %Buffer{} = buffer ->
        Buffer.fill_region(buffer, x, y, width, height, cell)

      pid when is_pid(pid) ->
        BufferServerRefactored.fill_region(pid, x, y, width, height, cell)
    end
  end

  @doc """
  Scrolls the buffer by the specified number of lines.

  Works with both buffer structs and buffer server PIDs.

  ## Parameters

  * `buffer_or_pid` - Either a buffer struct or a buffer server PID
  * `lines` - Number of lines to scroll

  ## Returns

  * For structs: `Buffer.t()` - The updated buffer
  * For PIDs: `:ok` or `{:error, reason}`
  """
  @spec scroll(buffer_or_pid(), integer()) ::
          Buffer.t() | :ok | {:error, term()}
  def scroll(buffer_or_pid, lines) do
    case buffer_or_pid do
      %Buffer{} = buffer ->
        Buffer.scroll(buffer, lines)

      pid when is_pid(pid) ->
        BufferServerRefactored.scroll(pid, lines)
    end
  end

  @doc """
  Resizes the buffer to the specified dimensions.

  Works with both buffer structs and buffer server PIDs.

  ## Parameters

  * `buffer_or_pid` - Either a buffer struct or a buffer server PID
  * `width` - New width
  * `height` - New height

  ## Returns

  * For structs: `Buffer.t()` - The updated buffer
  * For PIDs: `:ok` or `{:error, reason}`
  """
  @spec resize(buffer_or_pid(), non_neg_integer(), non_neg_integer()) ::
          Buffer.t() | :ok | {:error, term()}
  def resize(buffer_or_pid, width, height) do
    case buffer_or_pid do
      %Buffer{} = buffer ->
        Buffer.resize(buffer, width, height)

      pid when is_pid(pid) ->
        BufferServerRefactored.resize(pid, width, height)
    end
  end

  @doc """
  Gets the buffer dimensions.

  Works with both buffer structs and buffer server PIDs.

  ## Parameters

  * `buffer_or_pid` - Either a buffer struct or a buffer server PID

  ## Returns

  * For structs: `{width, height}` - The buffer dimensions
  * For PIDs: `{:ok, {width, height}}` or `{:error, reason}`
  """
  @spec get_dimensions(buffer_or_pid()) ::
          {non_neg_integer(), non_neg_integer()}
          | {:ok, {non_neg_integer(), non_neg_integer()}}
          | {:error, term()}
  def get_dimensions(buffer_or_pid) do
    case buffer_or_pid do
      %Buffer{} = buffer ->
        {buffer.width, buffer.height}

      pid when is_pid(pid) ->
        BufferServerRefactored.get_dimensions(pid)
    end
  end

  @doc """
  Performs an atomic operation on the buffer.

  Only works with buffer server PIDs.

  ## Parameters

  * `pid` - The buffer server PID
  * `operation` - A function that takes a buffer and returns a modified buffer

  ## Returns

  * `{:ok, result}` - The result of the operation
  * `{:error, reason}` - If the operation fails
  """
  @spec atomic_operation(pid(), (Buffer.t() -> Buffer.t())) ::
          {:ok, Buffer.t()} | {:error, term()}
  def atomic_operation(pid, operation)
      when is_pid(pid) and is_function(operation, 1) do
    BufferServerRefactored.atomic_operation(pid, operation)
  end

  @doc """
  Gets performance metrics for the buffer server.

  Only works with buffer server PIDs.

  ## Parameters

  * `pid` - The buffer server PID

  ## Returns

  * `{:ok, metrics}` - Performance metrics map
  * `{:error, reason}` - If the operation fails
  """
  @spec get_metrics(pid()) :: {:ok, map()} | {:error, term()}
  def get_metrics(pid) when is_pid(pid) do
    BufferServerRefactored.get_metrics(pid)
  end

  @doc """
  Stops a buffer server.

  Only works with buffer server PIDs.

  ## Parameters

  * `pid` - The buffer server PID

  ## Returns

  * `:ok` - If the server was stopped successfully
  """
  @spec batch_operations(pid(), list()) :: :ok
  def batch_operations(pid, operations)
      when is_pid(pid) and is_list(operations) do
    BufferServerRefactored.batch_operations(pid, operations)
  end

  @spec flush(pid()) :: :ok | {:error, term()}
  def flush(pid) when is_pid(pid) do
    BufferServerRefactored.flush(pid)
  end

  @spec stop(pid()) :: :ok
  def stop(pid) when is_pid(pid) do
    BufferServerRefactored.stop(pid)
  end

  # Private helper functions

  defp copy_buffer_to_server(buffer, pid) do
    # Copy all non-empty cells from the buffer struct to the server
    Enum.with_index(buffer.cells)
    |> Enum.each(fn {row, y} ->
      Enum.with_index(row)
      |> Enum.each(fn {cell, x} ->
        if cell.char != " " do
          BufferServerRefactored.set_cell(pid, x, y, cell)
        end
      end)
    end)
  end
end
