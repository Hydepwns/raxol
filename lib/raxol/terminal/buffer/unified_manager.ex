defmodule Raxol.Terminal.Buffer.UnifiedManager do
  @moduledoc """
  Unified buffer management system for the Raxol terminal emulator.
  This module combines and enhances the functionality of the previous buffer managers,
  providing improved memory management, caching, and performance metrics.
  """

  use GenServer
  @behaviour GenServer
  require Logger
  require Raxol.Core.Runtime.Log
  import Raxol.Guards

  alias Raxol.Terminal.{
    ScreenBuffer,
    Buffer.MemoryManager,
    Buffer.Scroll,
    Cache.System,
    Buffer.Manager.State,
    Buffer.DamageTracker
  }

  @type t :: %__MODULE__{
          active_buffer: ScreenBuffer.t(),
          back_buffer: ScreenBuffer.t(),
          scrollback_buffer: Scroll.t(),
          damage_tracker: DamageTracker.t(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          scrollback_limit: non_neg_integer(),
          memory_limit: non_neg_integer(),
          memory_usage: non_neg_integer(),
          metrics: map()
        }

  defstruct [
    :active_buffer,
    :back_buffer,
    :scrollback_buffer,
    :damage_tracker,
    width: 80,
    height: 24,
    scrollback_limit: 1000,
    memory_limit: 10_000_000,
    memory_usage: 0,
    metrics: %{
      operations: %{},
      memory: %{},
      performance: %{}
    }
  ]

  @doc """
  Creates a new unified buffer manager.

  ## Parameters
    * `width` - The width of the buffer
    * `height` - The height of the buffer
    * `scrollback_limit` - The maximum number of scrollback lines
    * `memory_limit` - The maximum memory usage in bytes

  ## Returns
    * `{:ok, state}` - The new buffer manager state
  """
  def new(width, height, scrollback_limit \\ 1000, memory_limit \\ 10_000_000) do
    state = %__MODULE__{
      active_buffer: ScreenBuffer.new(width, height),
      back_buffer: ScreenBuffer.new(width, height),
      scrollback_buffer: Scroll.new(scrollback_limit),
      damage_tracker: DamageTracker.new(),
      width: width,
      height: height,
      scrollback_limit: scrollback_limit,
      memory_limit: memory_limit,
      metrics: %{
        operations: %{},
        memory: %{},
        performance: %{}
      }
    }

    {:ok, state}
  end

  @doc """
  Starts a new buffer manager process.

  ## Options
    * `:width` - The width of the buffer (default: 80)
    * `:height` - The height of the buffer (default: 24)
    * `:scrollback_limit` - Maximum number of scrollback lines (default: 1000)
    * `:memory_limit` - Maximum memory usage in bytes (default: 10_000_000)

  ## Returns
    * `{:ok, pid}` - The process ID of the started buffer manager
  """
  def start_link(opts \\ []) do
    opts = if map?(opts), do: Enum.into(opts, []), else: opts
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Gets a cell from the active buffer at the specified position.

  ## Parameters
    * `state` - The buffer manager state
    * `x` - The x coordinate
    * `y` - The y coordinate

  ## Returns
    * `{:ok, cell}` - The cell at the specified position
  """
  def get_cell(pid, x, y) when pid?(pid) do
    GenServer.call(pid, {:get_cell, x, y})
  end

  @doc """
  Sets a cell in the active buffer at the specified position.

  ## Parameters
    * `state` - The buffer manager state
    * `x` - The x coordinate
    * `y` - The y coordinate
    * `cell` - The cell to set

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def set_cell(pid, x, y, cell) when pid?(pid) do
    GenServer.call(pid, {:set_cell, x, y, cell})
  end

  @doc """
  Fills a region in the active buffer with a cell.

  ## Parameters
    * `state` - The buffer manager state
    * `x` - The starting x coordinate
    * `y` - The starting y coordinate
    * `width` - The width of the region
    * `height` - The height of the region
    * `cell` - The cell to fill the region with

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def fill_region(pid, x, y, width, height, cell) when pid?(pid) do
    GenServer.call(pid, {:fill_region, x, y, width, height, cell})
  end

  @doc """
  Scrolls a region in the active buffer.

  ## Parameters
    * `state` - The buffer manager state
    * `x` - The starting x coordinate
    * `y` - The starting y coordinate
    * `width` - The width of the region
    * `height` - The height of the region
    * `amount` - The number of lines to scroll (positive for down, negative for up)

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def scroll_region(pid, x, y, width, height, amount) when pid?(pid) do
    GenServer.call(pid, {:scroll_region, x, y, width, height, amount})
  end

  @doc """
  Clears the active buffer.

  ## Parameters
    * `state` - The buffer manager state

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def clear(pid) when pid?(pid) do
    GenServer.call(pid, :clear)
  end

  @doc """
  Resizes the buffer to new dimensions.

  ## Parameters
    * `state` - The buffer manager state
    * `width` - The new width
    * `height` - The new height

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def resize(pid, width, height) when pid?(pid) do
    GenServer.call(pid, {:resize, width, height})
  end

  @doc """
  Scrolls up in the buffer.

  ## Parameters
    * `state` - The buffer manager state
    * `amount` - The number of lines to scroll up

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def scroll_up(pid, amount) when pid?(pid) do
    GenServer.call(pid, {:scroll_up, amount})
  end

  @doc """
  Gets the history of the buffer.

  ## Parameters
    * `state` - The buffer manager state
    * `start_line` - The starting line
    * `count` - The number of lines to get

  ## Returns
    * `{:ok, history}` - The history of the buffer
  """
  def get_history(pid, start_line, count) when pid?(pid) do
    GenServer.call(pid, {:get_history, start_line, count})
  end

  @doc """
  Gets the active buffer.
  """
  def get_active_buffer(%__MODULE__{} = state) do
    {:ok, state.active_buffer}
  end

  @doc """
  Updates the buffer with new commands.
  """
  def update(%__MODULE__{} = state, commands) when list?(commands) do
    Enum.reduce(commands, {:ok, state}, fn command, {:ok, current_state} ->
      case process_command(current_state, command) do
        {:ok, new_state} -> {:ok, new_state}
        error -> error
      end
    end)
  end

  @doc """
  Updates the buffer manager configuration.
  Delegates to update/2 for compatibility.
  """
  def update_config(buffer_manager, config) do
    update(buffer_manager, [config])
  end

  @doc """
  Gets the visible content of the buffer.
  """
  def get_visible_content(%__MODULE__{} = state) do
    {:ok, ScreenBuffer.get_content(state.active_buffer)}
  end

  @doc """
  Updates the visible region of the buffer.
  """
  def update_visible_region(%__MODULE__{} = state, region) do
    GenServer.call(state, {:update_visible_region, region})
  end

  @doc """
  Gets the total number of lines in the buffer.
  """
  def get_total_lines(%__MODULE__{} = state) do
    {:ok, state.height + Scroll.get_size(state.scrollback_buffer)}
  end

  @doc """
  Gets the number of visible lines in the buffer.
  """
  def get_visible_lines(%__MODULE__{} = state) do
    {:ok, state.height}
  end

  @doc """
  Writes data to the buffer.
  """
  def write(%__MODULE__{} = state, data) do
    GenServer.call(state, {:write, data})
  end

  @doc """
  Gets the memory usage of the buffer.
  """
  def get_memory_usage(%__MODULE__{} = state) do
    memory =
      ScreenBuffer.get_memory_usage(state.active_buffer) +
        ScreenBuffer.get_memory_usage(state.back_buffer) +
        Scroll.get_memory_usage(state.scrollback_buffer)

    {:ok, memory}
  end

  @doc """
  Gets the buffer manager state.
  """
  def get_buffer_manager(%__MODULE__{} = state) do
    {:ok, state}
  end

  @doc """
  Cleans up the buffer manager.
  """
  def cleanup(%__MODULE__{} = state) do
    ScreenBuffer.cleanup(state.active_buffer)
    ScreenBuffer.cleanup(state.back_buffer)
    Scroll.cleanup(state.scrollback_buffer)
    Buffer.DamageTracker.cleanup(state.damage_tracker)
    :ok
  end

  @doc """
  Gets the visible content for a specific buffer.
  """
  @spec get_visible_content(t(), String.t()) ::
          {:ok, list(list(Cell.t()))} | {:error, term()}
  def get_visible_content(manager, buffer_id) do
    case Map.get(manager.buffers, buffer_id) do
      nil -> {:error, :buffer_not_found}
      buffer -> {:ok, ScreenBuffer.get_content(buffer)}
    end
  end

  # Server Callbacks

  def init(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    scrollback_limit = Keyword.get(opts, :scrollback_limit, 1000)
    memory_limit = Keyword.get(opts, :memory_limit, 10_000_000)

    {:ok, state} = new(width, height, scrollback_limit, memory_limit)
    {:ok, state}
  end

  # Safe cache wrapper functions - completely disable cache when not available
  defp safe_cache_get(_key, _namespace) do
    {:error, :cache_not_available}
  end

  defp safe_cache_put(_key, _value, _namespace) do
    {:error, :cache_not_available}
  end

  defp safe_cache_clear(_namespace) do
    {:error, :cache_not_available}
  end

  defp safe_cache_invalidate(_key, _namespace) do
    {:error, :cache_not_available}
  end

  def handle_call({:get_cell, x, y}, _from, state) do
    start_time = System.monotonic_time()

    # Validate coordinates - return default cell for invalid coordinates
    if x < 0 or y < 0 or x >= state.active_buffer.width or
         y >= state.active_buffer.height do
      default_cell = %Raxol.Terminal.Cell{
        char: " ",
        style: nil,
        dirty: nil,
        wide_placeholder: false
      }

      duration = System.monotonic_time() - start_time
      state = update_metrics(state, :get_cell_invalid, duration)
      {:reply, {:ok, default_cell}, state}
    else
      {cell, updated_state} = get_cell_with_cache(state, x, y, start_time)
      {:reply, {:ok, cell}, updated_state}
    end
  end

  defp get_cell_with_cache(state, x, y, start_time) do
    cache_key = {x, y, 1, 1}

    case safe_cache_get(cache_key, :buffer) do
      {:ok, _cached_cell} ->
        duration = System.monotonic_time() - start_time
        state = update_metrics(state, :get_cell_cache_hit, duration)
        {:reply, {:ok, state}, state}

      {:error, _} ->
        cell = ScreenBuffer.get_cell(state.active_buffer, x, y)

        clean_cell =
          if nil?(cell) or cell == %{} do
            %Raxol.Terminal.Cell{
              char: " ",
              style: nil,
              dirty: nil,
              wide_placeholder: false
            }
          else
            %{cell | dirty: nil}
          end

        duration = System.monotonic_time() - start_time

        safe_cache_put(cache_key, clean_cell, :buffer)

        updated_state = update_metrics(state, :get_cell_cache_miss, duration)
        {clean_cell, updated_state}
    end
  end

  def handle_call({:set_cell, x, y, cell}, _from, state) do
    start_time = System.monotonic_time()

    cache_key = {x, y, 1, 1}

    case safe_cache_get(cache_key, :buffer) do
      {:ok, _cached_cell} ->
        duration = System.monotonic_time() - start_time
        state = update_metrics(state, :get_cell_cache_hit, duration)
        {:reply, {:ok, state}, state}

      {:error, _} ->
        new_active_buffer =
          ScreenBuffer.write_char(
            state.active_buffer,
            x,
            y,
            cell.char,
            cell.style
          )

        duration = System.monotonic_time() - start_time

        safe_cache_put(cache_key, cell, :buffer)

        state = update_metrics(state, :get_cell_cache_miss, duration)
        state = %{state | active_buffer: new_active_buffer}
        state = update_memory_usage(state)
        {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:fill_region, x, y, width, height, cell}, _from, state) do
    start_time = System.monotonic_time()

    new_active_buffer =
      fill_region_with_cell(state.active_buffer, x, y, width, height, cell)

    # Clear cache for the filled region
    safe_cache_clear(:buffer)

    duration = System.monotonic_time() - start_time
    state = %{state | active_buffer: new_active_buffer}
    state = update_metrics(state, :fill_region, duration)
    state = update_memory_usage(state)
    {:reply, {:ok, state}, state}
  end

  def handle_call({:scroll_region, x, y, width, height, amount}, _from, state) do
    start_time = System.monotonic_time()

    {new_active_buffer, new_scrollback_buffer} =
      process_scroll_region(state, x, y, width, height, amount)

    # Clear cache for the scrolled region
    safe_cache_clear(:buffer)

    duration = System.monotonic_time() - start_time

    state = %{
      state
      | active_buffer: new_active_buffer,
        scrollback_buffer: new_scrollback_buffer
    }

    state = update_metrics(state, :scroll_region, duration)
    state = update_memory_usage(state)
    {:reply, {:ok, state}, state}
  end

  defp process_scroll_region(state, x, y, width, _height, amount) do
    # Only handle scroll up for scrollback (amount > 0)
    lines_to_scrollback =
      if amount > 0 do
        Enum.map(0..(amount - 1), fn offset ->
          extract_line_cells(state.active_buffer, x, y + offset, width)
        end)
      else
        []
      end

    # Add lines to scrollback if scrolling up
    new_scrollback_buffer =
      if amount > 0 and lines_to_scrollback != [] do
        Scroll.add_content(state.scrollback_buffer, lines_to_scrollback)
      else
        state.scrollback_buffer
      end

    # Use ScreenBuffer's scroll operations
    new_active_buffer =
      if amount > 0 do
        ScreenBuffer.scroll_up(state.active_buffer, amount)
      else
        ScreenBuffer.scroll_down(state.active_buffer, abs(amount))
      end

    {new_active_buffer, new_scrollback_buffer}
  end

  defp extract_line_cells(buffer, x, y, width) do
    Enum.map(x..(x + width - 1), fn col ->
      ScreenBuffer.get_cell(buffer, col, y) ||
        %Raxol.Terminal.Cell{
          char: " ",
          style: nil,
          dirty: nil,
          wide_placeholder: false
        }
    end)
  end

  def handle_call(:clear, _from, state) do
    start_time = System.monotonic_time()

    new_active_buffer = ScreenBuffer.clear(state.active_buffer, nil)
    new_back_buffer = ScreenBuffer.clear(state.back_buffer, nil)

    # Clear all cache
    safe_cache_clear(:buffer)

    duration = System.monotonic_time() - start_time

    state = %{
      state
      | active_buffer: new_active_buffer,
        back_buffer: new_back_buffer
    }

    state = update_metrics(state, :clear, duration)
    state = update_memory_usage(state)
    {:reply, {:ok, state}, state}
  end

  def handle_call({:resize, width, height}, _from, state) do
    start_time = System.monotonic_time()

    # Validate dimensions
    if width <= 0 or height <= 0 do
      {:reply, {:error, :invalid_dimensions}, state}
    else
      # Resize buffers
      new_active_buffer =
        ScreenBuffer.resize(state.active_buffer, height, width)

      new_back_buffer = ScreenBuffer.resize(state.back_buffer, height, width)

      # Clear the resized buffers to ensure they start with empty content
      new_active_buffer = ScreenBuffer.clear(new_active_buffer, nil)
      new_back_buffer = ScreenBuffer.clear(new_back_buffer, nil)

      # Clear cache
      safe_cache_clear(:buffer)

      duration = System.monotonic_time() - start_time

      state = %{
        state
        | active_buffer: new_active_buffer,
          back_buffer: new_back_buffer,
          width: width,
          height: height
      }

      state = update_metrics(state, :resize, duration)
      state = update_memory_usage(state)
      {:reply, {:ok, state}, state}
    end
  end

  def handle_call({:scroll_up, amount}, _from, state) do
    start_time = System.monotonic_time()

    # Scroll the scrollback buffer
    new_scrollback_buffer = Scroll.scroll(state.scrollback_buffer, :up, amount)

    # Clear cache for the visible area
    safe_cache_clear(:buffer)

    duration = System.monotonic_time() - start_time
    state = %{state | scrollback_buffer: new_scrollback_buffer}
    state = update_metrics(state, :scroll_up, duration)
    state = update_memory_usage(state)
    {:reply, {:ok, state}, state}
  end

  def handle_call({:get_history, _start_line, count}, _from, state) do
    start_time = System.monotonic_time()

    # Get history from scrollback buffer
    history = Scroll.get_view(state.scrollback_buffer, count)

    duration = System.monotonic_time() - start_time
    state = update_metrics(state, :get_history, duration)
    {:reply, {:ok, history}, state}
  end

  def handle_call(:get_metrics, _from, state) do
    {:reply, {:ok, state.metrics}, state}
  end

  def handle_call({:add_scrollback, content}, _from, state) do
    start_time = System.monotonic_time()

    new_scrollback_buffer = Scroll.add_content(state.scrollback_buffer, content)

    # Clear scrollback cache
    safe_cache_clear(:scrollback)

    duration = System.monotonic_time() - start_time
    state = %{state | scrollback_buffer: new_scrollback_buffer}
    state = update_metrics(state, :add_scrollback, duration)
    state = update_memory_usage(state)
    {:reply, {:ok, state}, state}
  end

  def handle_call(:get_memory_usage, _from, state) do
    updated_state = update_memory_usage(state)
    {:reply, {:ok, updated_state.memory_usage}, updated_state}
  end

  defp update_cell(buffer, x, y, cell) do
    start_time = System.monotonic_time()
    new_buffer = ScreenBuffer.write_char(buffer, x, y, cell.char, cell.style)
    duration = System.monotonic_time() - start_time
    {new_buffer, duration}
  end

  defp update_state_after_cell_change(state, new_buffer, duration) do
    state
    |> Map.put(:active_buffer, new_buffer)
    |> update_metrics(:set_cell, duration)
    |> update_memory_usage()
  end

  defp initialize_buffers(width, height, _scrollback_limit) do
    main_buffer = State.new(width, height)
    alt_buffer = State.new(width, height)
    {main_buffer, alt_buffer}
  end

  defp update_metrics(state, _operation, _duration) do
    # Record performance metric
    # Raxol.Core.Metrics.UnifiedCollector.record_performance(
    #   String.to_atom("buffer_#{operation}"),
    #   duration,
    #   tags: [:buffer, operation]
    # )

    # Record operation metric
    # Raxol.Core.Metrics.UnifiedCollector.record_operation(
    #   String.to_atom("buffer_#{operation}"),
    #   1,
    #   tags: [:buffer, operation]
    # )

    state
  end

  defp update_memory_usage(state) do
    # Calculate memory usage based on buffer dimensions and content
    active_memory = calculate_buffer_memory(state.active_buffer)
    back_memory = calculate_buffer_memory(state.back_buffer)
    scrollback_memory = calculate_scrollback_memory(state.scrollback_buffer)

    memory = active_memory + back_memory + scrollback_memory

    # Record memory usage metric
    # Raxol.Core.Metrics.UnifiedCollector.record_resource(
    #   :buffer_memory_usage,
    #   memory,
    #   tags: [:buffer, :memory]
    # )

    # Update state with memory usage
    %{state | memory_usage: memory}
  end

  # Helper function to calculate memory usage for a ScreenBuffer
  defp calculate_buffer_memory(buffer) do
    # Estimate memory usage based on dimensions and content
    # Each cell is roughly 64 bytes (including overhead)
    # Plus some overhead for the struct itself
    cell_count = buffer.width * buffer.height
    cell_memory = cell_count * 64

    # Add overhead for the struct and other fields
    struct_overhead = 1024

    cell_memory + struct_overhead
  end

  # Helper function to calculate memory usage for a Scroll buffer
  defp calculate_scrollback_memory(scrollback) do
    # Estimate memory usage based on scrollback content
    # Each line is roughly 80 * 64 bytes (assuming 80 columns)
    # Plus some overhead for the struct itself
    line_count = length(scrollback.buffer)
    line_memory = line_count * 80 * 64

    # Add overhead for the struct and other fields
    struct_overhead = 512

    line_memory + struct_overhead
  end

  defp invalidate_region_cache(x, y, width, height) do
    # Invalidate all cells in the region
    for i <- x..(x + width - 1),
        j <- y..(y + height - 1) do
      System.invalidate({i, j, 1, 1}, namespace: :buffer)
    end
  end

  defp process_command(state, command) do
    Raxol.Terminal.Buffer.CommandHandler.handle_command(state, command)
  end

  # Add helper function for filling regions
  defp fill_region_with_cell(buffer, x, y, width, height, cell) do
    Enum.reduce(y..(y + height - 1), buffer, fn row, acc ->
      Enum.reduce(x..(x + width - 1), acc, fn col, cell_acc ->
        ScreenBuffer.write_char(cell_acc, col, row, cell.char, cell.style)
      end)
    end)
  end
end
