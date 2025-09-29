defmodule Raxol.Terminal.Buffer.ConcurrentBuffer do
  @moduledoc """
  A thread-safe buffer implementation using GenServer for concurrent access.
  Provides synchronous operations to ensure data integrity when multiple
  processes are reading/writing to the buffer simultaneously.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Terminal.Buffer
  alias Raxol.Terminal.Buffer.Cell

  # Client API

  @doc """
  Starts a concurrent buffer server.

  Options:
    - :width - Buffer width (default: 80)
    - :height - Buffer height (default: 24)
    - :name - GenServer name (optional)
  """
  @spec start_server(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_server(opts \\ []) do
    start_link(opts)
  end

  @doc """
  Stops the concurrent buffer server.
  """
  @spec stop(pid() | atom()) :: :ok
  def stop(server) do
    GenServer.stop(server, :normal)
  end

  @doc """
  Sets a cell in the buffer.
  """
  @spec set_cell(pid() | atom(), integer(), integer(), Cell.t()) ::
          :ok | {:error, term()}
  def set_cell(server, x, y, cell) do
    GenServer.call(server, {:set_cell, x, y, cell})
  end

  @doc """
  Gets a cell from the buffer.
  """
  @spec get_cell(pid() | atom(), integer(), integer()) ::
          {:ok, Cell.t()} | {:error, term()}
  def get_cell(server, x, y) do
    GenServer.call(server, {:get_cell, x, y})
  end

  @doc """
  Writes text starting at the given position.
  """
  @spec write(pid() | atom(), integer(), integer(), String.t(), map()) ::
          :ok | {:error, term()}
  def write(server, x, y, text, style \\ %{}) do
    GenServer.call(server, {:write, x, y, text, style})
  end

  @doc """
  Clears the entire buffer.
  """
  @spec clear(pid() | atom()) :: :ok
  def clear(server) do
    GenServer.call(server, :clear)
  end

  @doc """
  Fills a region with a character.
  """
  @spec fill_region(
          pid() | atom(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          map()
        ) :: :ok
  def fill_region(server, x, y, width, height, char, style \\ %{}) do
    GenServer.call(server, {:fill_region, x, y, width, height, char, style})
  end

  @doc """
  Scrolls the buffer content.
  """
  @spec scroll(pid() | atom(), integer()) :: :ok
  def scroll(server, lines) do
    GenServer.call(server, {:scroll, lines})
  end

  @doc """
  Flushes any pending operations (for compatibility).
  Returns :ok immediately as operations are synchronous.
  """
  @spec flush(pid() | atom()) :: :ok
  def flush(_server), do: :ok

  @doc """
  Gets the current buffer state for reading.
  """
  @spec get_buffer(pid() | atom()) :: {:ok, Buffer.t()} | {:error, term()}
  def get_buffer(server) do
    GenServer.call(server, :get_buffer)
  end

  @doc """
  Performs a batch of operations atomically.
  """
  @spec batch(pid() | atom(), (Buffer.t() -> Buffer.t())) ::
          :ok | {:error, term()}
  def batch(server, fun) when is_function(fun, 1) do
    GenServer.call(server, {:batch, fun})
  end

  @doc """
  Performs a batch of operations from a list.
  """
  @spec batch_operations(pid() | atom(), list()) :: :ok | {:error, term()}
  def batch_operations(server, operations) when is_list(operations) do
    GenServer.call(server, {:batch_operations, operations})
  end

  # Server callbacks

  @impl true
  def init_manager(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)

    state = %{
      buffer: Buffer.new({width, height}),
      width: width,
      height: height
    }

    {:ok, state}
  end

  @impl true
  def handle_manager_call({:set_cell, x, y, cell}, _from, state) do
    case validate_coords(x, y, state) do
      :ok ->
        # Update the buffer with the new cell
        updated_buffer = Buffer.set_cell(state.buffer, x, y, cell)
        {:reply, :ok, %{state | buffer: updated_buffer}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  rescue
    e -> {:reply, {:error, e}, state}
  end

  @impl true
  def handle_manager_call({:get_cell, x, y}, _from, state) do
    case validate_coords(x, y, state) do
      :ok ->
        cell = Buffer.get_cell(state.buffer, x, y)
        {:reply, {:ok, cell}, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  rescue
    e -> {:reply, {:error, e}, state}
  end

  @impl true
  def handle_manager_call({:write, x, y, text, style}, _from, state) do
    case validate_coords(x, y, state) do
      :ok ->
        updated_buffer = write_text(state.buffer, x, y, text, style)
        {:reply, :ok, %{state | buffer: updated_buffer}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  rescue
    e -> {:reply, {:error, e}, state}
  end

  @impl true
  def handle_manager_call(:clear, _from, state) do
    cleared_buffer = Buffer.new({state.width, state.height})
    {:reply, :ok, %{state | buffer: cleared_buffer}}
  end

  @impl true
  def handle_manager_call(
        {:fill_region, x, y, width, height, char, style},
        _from,
        state
      ) do
    case validate_region(x, y, width, height, state) do
      :ok ->
        updated_buffer =
          fill_buffer_region(state.buffer, x, y, width, height, char, style)

        {:reply, :ok, %{state | buffer: updated_buffer}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  rescue
    e -> {:reply, {:error, e}, state}
  end

  @impl true
  def handle_manager_call({:scroll, lines}, _from, state) do
    # Simplified scroll implementation
    # In a real implementation, this would shift buffer content
    updated_buffer = perform_scroll(state.buffer, lines, state.height)
    {:reply, :ok, %{state | buffer: updated_buffer}}
  rescue
    e -> {:reply, {:error, e}, state}
  end

  @impl true
  def handle_manager_call(:get_buffer, _from, state) do
    {:reply, {:ok, state.buffer}, state}
  end

  @impl true
  def handle_manager_call({:batch, fun}, _from, state) do
    try do
      updated_buffer = fun.(state.buffer)
      {:reply, :ok, %{state | buffer: updated_buffer}}
    rescue
      e -> {:reply, {:error, e}, state}
    end
  end

  @impl true
  def handle_manager_call({:batch_operations, operations}, _from, state) do
    try do
      updated_buffer = apply_batch_operations(operations, state.buffer, state)
      {:reply, :ok, %{state | buffer: updated_buffer}}
    rescue
      e -> {:reply, {:error, e}, state}
    end
  end

  # Private helpers

  defp apply_batch_operations(operations, buffer, state) do
    Enum.reduce(operations, buffer, fn operation, acc_buffer ->
      case operation do
        {:set_cell, x, y, cell} ->
          if validate_coords(x, y, state) == :ok do
            Buffer.set_cell(acc_buffer, x, y, cell)
          else
            acc_buffer
          end

        {:write_string, x, y, text} ->
          if validate_coords(x, y, state) == :ok do
            write_text(acc_buffer, x, y, text, %{})
          else
            acc_buffer
          end

        {:fill_region, x, y, width, height, cell} ->
          if validate_region(x, y, width, height, state) == :ok do
            fill_buffer_region_with_cell(acc_buffer, x, y, width, height, cell)
          else
            acc_buffer
          end

        _ ->
          acc_buffer
      end
    end)
  end

  defp fill_buffer_region_with_cell(buffer, x, y, width, height, cell) do
    Enum.reduce(y..(y + height - 1), buffer, fn row, acc_buffer ->
      Enum.reduce(x..(x + width - 1), acc_buffer, fn col, inner_acc ->
        Buffer.set_cell(inner_acc, col, row, cell)
      end)
    end)
  end

  defp validate_coords(x, y, %{width: width, height: height}) do
    cond do
      x < 0 or x >= width ->
        {:error, :out_of_bounds}

      y < 0 or y >= height ->
        {:error, :out_of_bounds}

      true ->
        :ok
    end
  end

  defp validate_region(x, y, width, height, state) do
    cond do
      x < 0 or y < 0 or width < 0 or height < 0 ->
        {:error, :invalid_region}

      x + width > state.width or y + height > state.height ->
        {:error, :out_of_bounds}

      true ->
        :ok
    end
  end

  defp write_text(buffer, x, y, text, style) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, offset}, acc ->
      cell =
        if map_size(style) > 0 do
          Cell.new(char, style)
        else
          Cell.new(char: char)
        end

      Buffer.set_cell(acc, x + offset, y, cell)
    end)
  end

  defp fill_buffer_region(buffer, x, y, width, height, char, style) do
    Enum.reduce(y..(y + height - 1), buffer, fn row, acc_buffer ->
      Enum.reduce(x..(x + width - 1), acc_buffer, fn col, inner_acc ->
        cell =
          if map_size(style) > 0 do
            Cell.new(char, style)
          else
            Cell.new(char: char)
          end

        Buffer.set_cell(inner_acc, col, row, cell)
      end)
    end)
  end

  defp perform_scroll(buffer, lines, _height) when lines > 0 do
    # Scroll up: move content up, add blank lines at bottom
    # Simplified implementation - in practice would preserve content
    buffer
  end

  defp perform_scroll(buffer, lines, _height) when lines < 0 do
    # Scroll down: move content down, add blank lines at top
    # Simplified implementation - in practice would preserve content
    buffer
  end

  defp perform_scroll(buffer, _lines, _height), do: buffer
end
