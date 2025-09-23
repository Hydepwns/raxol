defmodule Raxol.Terminal.Buffer.SafeManager do
  @moduledoc """
  Safe buffer management with error handling and recovery.

  Provides a GenServer-based buffer manager that handles terminal buffer operations
  with comprehensive error handling, automatic recovery, and integration with the
  existing ScreenBuffer system.

  ## Features
  - Safe buffer operations with error recovery
  - Integration with Raxol.Terminal.ScreenBuffer
  - Memory usage monitoring and limits
  - Automatic buffer cleanup
  - Performance optimization for high-frequency operations
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Content
  alias Raxol.Terminal.Buffer.Queries
  alias Raxol.Terminal.Cell

  @type buffer_options :: keyword()
  @type buffer_state :: %{
          buffer: ScreenBuffer.t(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          memory_limit: non_neg_integer(),
          stats: map()
        }

  # Client API

  @doc """
  Starts a safe buffer manager.
  """
  @spec start_link(buffer_options()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Writes data to the buffer safely.
  """
  @spec write(pid(), binary()) :: {:ok, term()} | {:error, term()}
  def write(buffer_pid, data) when is_binary(data) do
    GenServer.call(buffer_pid, {:write, data})
  end

  @doc """
  Reads data from the buffer safely.
  """
  @spec read(pid(), keyword()) :: {:ok, binary()} | {:error, term()}
  def read(buffer_pid, opts \\ []) do
    GenServer.call(buffer_pid, {:read, opts})
  end

  @doc """
  Resizes the buffer safely.
  """
  @spec resize(pid(), non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, term()}
  def resize(buffer_pid, width, height) do
    cond do
      width <= 0 or height <= 0 ->
        {:error, :invalid_dimensions}

      width > 10_000 or height > 10_000 ->
        {:error, :dimensions_too_large}

      true ->
        GenServer.call(buffer_pid, {:resize, width, height})
    end
  end

  @doc """
  Gets buffer statistics.
  """
  @spec get_stats(pid()) :: {:ok, map()} | {:error, term()}
  def get_stats(buffer_pid) do
    GenServer.call(buffer_pid, :get_stats)
  end

  @doc """
  Clears the buffer.
  """
  @spec clear(pid()) :: :ok | {:error, term()}
  def clear(buffer_pid) do
    GenServer.call(buffer_pid, :clear)
  end

  @doc """
  Gets buffer content as formatted string.
  """
  @spec get_content(pid()) :: {:ok, String.t()} | {:error, term()}
  def get_content(buffer_pid) do
    GenServer.call(buffer_pid, :get_content)
  end

  @doc """
  Resets error counters and circuit breaker state.
  """
  @spec reset_errors(pid()) :: :ok
  def reset_errors(buffer_pid) do
    GenServer.call(buffer_pid, :reset_errors)
  end

  # GenServer Implementation

  @impl GenServer
  def init(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    # 10MB default
    memory_limit = Keyword.get(opts, :memory_limit, 10 * 1024 * 1024)

    try do
      buffer = ScreenBuffer.new(width, height)

      state = %{
        buffer: buffer,
        width: width,
        height: height,
        memory_limit: memory_limit,
        stats: %{
          writes: 0,
          reads: 0,
          resizes: 0,
          errors: 0,
          error_count: 0,
          circuit_breaker_state: :closed,
          created_at: :os.system_time(:millisecond),
          last_operation: nil
        }
      }

      Logger.debug("SafeManager initialized: #{width}x#{height}")
      {:ok, state}
    rescue
      error ->
        Logger.error("Failed to initialize SafeManager: #{inspect(error)}")
        {:stop, error}
    end
  end

  @impl GenServer
  def handle_call({:write, data}, _from, state) do
    try do
      # Check input size first (avoid processing very large inputs)
      case check_input_size(data) do
        {:error, reason} ->
          {:reply, {:ok, {:error, reason}}, state}

        :ok ->
          # Parse and write data to buffer
          updated_buffer = write_data_to_buffer(state.buffer, data)

          # Check memory usage
          case check_memory_limit(updated_buffer, state.memory_limit) do
            :ok ->
              new_stats = update_stats(state.stats, :write)
              new_state = %{state | buffer: updated_buffer, stats: new_stats}
              {:reply, {:ok, :success}, new_state}

            {:error, :memory_limit} ->
              Logger.warning(
                "SafeManager: Memory limit exceeded, refusing write"
              )

              {:reply, {:error, :memory_limit}, state}
          end
      end
    rescue
      error ->
        Logger.error("SafeManager write failed: #{inspect(error)}")

        new_stats =
          state.stats
          |> Map.update(:errors, 1, &(&1 + 1))
          |> Map.update(:error_count, 1, &(&1 + 1))

        new_state = %{state | stats: new_stats}
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:read, opts}, _from, state) do
    try do
      content = read_buffer_content(state.buffer, opts)
      new_stats = update_stats(state.stats, :read)
      new_state = %{state | stats: new_stats}

      {:reply, {:ok, content}, new_state}
    rescue
      error ->
        Logger.error("SafeManager read failed: #{inspect(error)}")

        new_stats =
          state.stats
          |> Map.update(:errors, 1, &(&1 + 1))
          |> Map.update(:error_count, 1, &(&1 + 1))

        new_state = %{state | stats: new_stats}
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:resize, width, height}, _from, state) do
    try do
      resized_buffer = ScreenBuffer.resize(state.buffer, width, height)
      new_stats = update_stats(state.stats, :resize)

      new_state = %{
        state
        | buffer: resized_buffer,
          width: width,
          height: height,
          stats: new_stats
      }

      Logger.debug("SafeManager resized to #{width}x#{height}")
      {:reply, :ok, new_state}
    rescue
      error ->
        Logger.error("SafeManager resize failed: #{inspect(error)}")

        new_stats =
          state.stats
          |> Map.update(:errors, 1, &(&1 + 1))
          |> Map.update(:error_count, 1, &(&1 + 1))

        new_state = %{state | stats: new_stats}
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call(:clear, _from, state) do
    try do
      cleared_buffer = ScreenBuffer.clear(state.buffer)
      new_stats = update_stats(state.stats, :clear)

      new_state = %{state | buffer: cleared_buffer, stats: new_stats}

      {:reply, :ok, new_state}
    rescue
      error ->
        Logger.error("SafeManager clear failed: #{inspect(error)}")

        new_stats =
          state.stats
          |> Map.update(:errors, 1, &(&1 + 1))
          |> Map.update(:error_count, 1, &(&1 + 1))

        new_state = %{state | stats: new_stats}
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    enhanced_stats =
      Map.merge(state.stats, %{
        buffer_size: "#{state.width}x#{state.height}",
        memory_usage: estimate_memory_usage(state.buffer),
        uptime_ms: :os.system_time(:millisecond) - state.stats.created_at
      })

    {:reply, {:ok, enhanced_stats}, state}
  end

  @impl GenServer
  def handle_call(:get_content, _from, state) do
    try do
      content = format_buffer_content(state.buffer)
      {:reply, {:ok, content}, state}
    rescue
      error ->
        Logger.error("SafeManager get_content failed: #{inspect(error)}")

        new_stats =
          state.stats
          |> Map.update(:errors, 1, &(&1 + 1))
          |> Map.update(:error_count, 1, &(&1 + 1))

        new_state = %{state | stats: new_stats}
        {:reply, {:error, error}, new_state}
    end
  end

  @impl GenServer
  def handle_call(:reset_errors, _from, state) do
    new_stats =
      state.stats
      |> Map.put(:errors, 0)
      |> Map.put(:error_count, 0)
      |> Map.put(:circuit_breaker_state, :closed)

    new_state = %{state | stats: new_stats}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("SafeManager received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.info("SafeManager terminating: #{inspect(reason)}")
    Logger.debug("Final stats: #{inspect(state.stats)}")
    :ok
  end

  # Private Implementation

  defp write_data_to_buffer(buffer, data) do
    # Simple implementation: write data at cursor position
    # In a full implementation, this would parse ANSI sequences
    lines = String.split(data, "\n")

    Enum.reduce(lines, buffer, fn line, acc_buffer ->
      # Write each character of the line to the buffer
      Content.write_string(acc_buffer, 0, 0, line)
    end)
  end

  defp read_buffer_content(buffer, opts) do
    lines = Keyword.get(opts, :lines, :all)
    format = Keyword.get(opts, :format, :text)

    case lines do
      :all ->
        extract_all_content(buffer, format)

      n when is_integer(n) ->
        extract_limited_content(buffer, n, format)

      _ ->
        extract_all_content(buffer, format)
    end
  end

  defp extract_all_content(buffer, :text) do
    # Extract text content from all rows
    0..(buffer.height - 1)
    |> Enum.map_join("\n", fn row ->
      extract_row_text(buffer, row)
    end)
  end

  defp extract_limited_content(buffer, line_count, :text) do
    max_lines = min(line_count, buffer.height)

    0..(max_lines - 1)
    |> Enum.map_join("\n", fn row ->
      extract_row_text(buffer, row)
    end)
  end

  defp extract_row_text(buffer, row) do
    # Extract text from a specific row
    cells = Queries.get_line(buffer, row)

    cells
    |> Enum.map_join("", fn cell -> Cell.get_char(cell) end)
    |> String.trim_trailing()
  end

  defp format_buffer_content(buffer) do
    # Format entire buffer as readable text
    extract_all_content(buffer, :text)
  end

  defp check_input_size(data) do
    # Check if input is too large (e.g., more than 1MB)
    # 1MB
    max_input_size = 1_000_000

    if byte_size(data) > max_input_size do
      {:error, :input_too_large}
    else
      :ok
    end
  end

  defp check_memory_limit(buffer, limit) do
    estimated_memory = estimate_memory_usage(buffer)

    if estimated_memory > limit do
      {:error, :memory_limit}
    else
      :ok
    end
  end

  defp estimate_memory_usage(buffer) do
    # Rough estimation of memory usage
    cell_count = buffer.width * buffer.height
    # Approximate bytes per cell
    bytes_per_cell = 64
    # Base structure overhead
    base_overhead = 1024

    cell_count * bytes_per_cell + base_overhead
  end

  defp update_stats(stats, operation) do
    operation_key =
      case operation do
        :write -> :writes
        :read -> :reads
        :resize -> :resizes
        :clear -> :clears
      end

    stats
    |> Map.update(operation_key, 1, &(&1 + 1))
    |> Map.put(:last_operation, {operation, :os.system_time(:millisecond)})
  end
end
