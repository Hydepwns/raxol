defmodule Raxol.Terminal.Buffer.UnifiedManager do
  @moduledoc '''
  Unified buffer management system for the Raxol terminal emulator.
  This module combines and enhances the functionality of the previous buffer managers,
  providing improved memory management, caching, and performance metrics.
  '''

  use GenServer
  require Logger
  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.{
    ScreenBuffer,
    Buffer.MemoryManager,
    Buffer.Scroll,
    Cache.System
  }

  @type t :: %__MODULE__{
          active_buffer: ScreenBuffer.t(),
          back_buffer: ScreenBuffer.t(),
          scrollback_buffer: Scroll.t(),
          memory_usage: non_neg_integer(),
          memory_limit: non_neg_integer(),
          metrics: map(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          scrollback_limit: non_neg_integer()
        }

  defstruct [
    :active_buffer,
    :back_buffer,
    :scrollback_buffer,
    memory_usage: 0,
    memory_limit: 10_000_000,
    metrics: %{
      operations: %{},
      memory: %{},
      performance: %{}
    },
    width: 80,
    height: 24,
    scrollback_limit: 1000
  ]

  @doc '''
  Creates a new unified buffer manager with the specified dimensions.

  ## Parameters
    * `width` - The width of the buffer
    * `height` - The height of the buffer
    * `scrollback_limit` - Maximum number of scrollback lines (default: 1000)
    * `memory_limit` - Maximum memory usage in bytes (default: 10_000_000)

  ## Returns
    * `{:ok, state}` - The initialized buffer manager state
  '''
  def new(width, height, scrollback_limit \\ 1000, memory_limit \\ 10_000_000) do
    state = %__MODULE__{
      active_buffer: ScreenBuffer.new(width, height, scrollback_limit),
      back_buffer: ScreenBuffer.new(width, height, scrollback_limit),
      scrollback_buffer: Scroll.new(scrollback_limit),
      width: width,
      height: height,
      scrollback_limit: scrollback_limit,
      memory_limit: memory_limit
    }

    {:ok, state}
  end

  @doc '''
  Starts a new buffer manager process.

  ## Options
    * `:width` - The width of the buffer (default: 80)
    * `:height` - The height of the buffer (default: 24)
    * `:scrollback_limit` - Maximum number of scrollback lines (default: 1000)
    * `:memory_limit` - Maximum memory usage in bytes (default: 10_000_000)

  ## Returns
    * `{:ok, pid}` - The process ID of the started buffer manager
  '''
  def start_link(opts \\ []) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts
    GenServer.start_link(__MODULE__, opts)
  end

  @doc '''
  Gets a cell from the active buffer at the specified position.

  ## Parameters
    * `state` - The buffer manager state
    * `x` - The x coordinate
    * `y` - The y coordinate

  ## Returns
    * `{:ok, cell}` - The cell at the specified position
  '''
  def get_cell(%__MODULE__{} = state, x, y) do
    GenServer.call(state, {:get_cell, x, y})
  end

  @doc '''
  Sets a cell in the active buffer at the specified position.

  ## Parameters
    * `state` - The buffer manager state
    * `x` - The x coordinate
    * `y` - The y coordinate
    * `cell` - The cell to set

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  '''
  def set_cell(%__MODULE__{} = state, x, y, cell) do
    GenServer.call(state, {:set_cell, x, y, cell})
  end

  @doc '''
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
  '''
  def fill_region(%__MODULE__{} = state, x, y, width, height, cell) do
    GenServer.call(state, {:fill_region, x, y, width, height, cell})
  end

  @doc '''
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
  '''
  def scroll_region(%__MODULE__{} = state, x, y, width, height, amount) do
    GenServer.call(state, {:scroll_region, x, y, width, height, amount})
  end

  @doc '''
  Clears the active buffer.

  ## Parameters
    * `state` - The buffer manager state

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  '''
  def clear(%__MODULE__{} = state) do
    GenServer.call(state, :clear)
  end

  @doc '''
  Resizes the buffer to new dimensions.

  ## Parameters
    * `state` - The buffer manager state
    * `width` - The new width
    * `height` - The new height

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  '''
  def resize(%__MODULE__{} = state, width, height) do
    GenServer.call(state, {:resize, width, height})
  end

  @doc '''
  Gets the active buffer.
  '''
  def get_active_buffer(%__MODULE__{} = state) do
    {:ok, state.active_buffer}
  end

  @doc '''
  Updates the buffer with new commands.
  '''
  def update(%__MODULE__{} = state, commands) when is_list(commands) do
    Enum.reduce(commands, {:ok, state}, fn command, {:ok, current_state} ->
      case process_command(current_state, command) do
        {:ok, new_state} -> {:ok, new_state}
        error -> error
      end
    end)
  end

  @doc '''
  Updates the buffer manager configuration.
  Delegates to update/2 for compatibility.
  '''
  def update_config(buffer_manager, config) do
    update(buffer_manager, [config])
  end

  @doc '''
  Gets the visible content of the buffer.
  '''
  def get_visible_content(%__MODULE__{} = state) do
    {:ok, ScreenBuffer.get_visible_content(state.active_buffer)}
  end

  @doc '''
  Updates the visible region of the buffer.
  '''
  def update_visible_region(%__MODULE__{} = state, region) do
    GenServer.call(state, {:update_visible_region, region})
  end

  @doc '''
  Gets the total number of lines in the buffer.
  '''
  def get_total_lines(%__MODULE__{} = state) do
    {:ok, state.height + Scroll.get_size(state.scrollback_buffer)}
  end

  @doc '''
  Gets the number of visible lines in the buffer.
  '''
  def get_visible_lines(%__MODULE__{} = state) do
    {:ok, state.height}
  end

  @doc '''
  Writes data to the buffer.
  '''
  def write(%__MODULE__{} = state, data) do
    GenServer.call(state, {:write, data})
  end

  @doc '''
  Gets the memory usage of the buffer.
  '''
  def get_memory_usage(%__MODULE__{} = state) do
    active_usage = ScreenBuffer.get_memory_usage(state.active_buffer)
    back_usage = ScreenBuffer.get_memory_usage(state.back_buffer)
    scrollback_usage = Scroll.get_memory_usage(state.scrollback_buffer)

    total_usage = active_usage + back_usage + scrollback_usage
    {:ok, total_usage}
  end

  @doc '''
  Gets the buffer manager state.
  '''
  def get_buffer_manager(%__MODULE__{} = state) do
    {:ok, state}
  end

  @doc '''
  Cleans up the buffer manager.
  '''
  def cleanup(%__MODULE__{} = state) do
    ScreenBuffer.cleanup(state.active_buffer)
    ScreenBuffer.cleanup(state.back_buffer)
    Scroll.cleanup(state.scrollback_buffer)

    new_state = %{
      state
      | metrics: %{
          operations: %{},
          memory: %{},
          performance: %{}
        }
    }

    {:ok, new_state}
  end

  @doc '''
  Gets the visible content for a specific buffer.
  '''
  @spec get_visible_content(t(), String.t()) ::
          {:ok, list(list(Cell.t()))} | {:error, term()}
  def get_visible_content(manager, buffer_id) do
    case Map.get(manager.buffers, buffer_id) do
      nil -> {:error, :buffer_not_found}
      buffer -> {:ok, buffer.cells}
    end
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    scrollback_limit = Keyword.get(opts, :scrollback_limit, 1000)
    memory_limit = Keyword.get(opts, :memory_limit, 10_000_000)

    {:ok, state} = new(width, height, scrollback_limit, memory_limit)
    {:ok, state}
  end

  @impl true
  def handle_call({:get_cell, x, y}, _from, state) do
    start_time = System.monotonic_time()

    cache_key = {x, y, 1, 1}

    case System.get(cache_key, namespace: :buffer) do
      {:ok, cell} ->
        duration = System.monotonic_time() - start_time
        state = update_metrics(state, :get_cell_cache_hit, duration)
        {:reply, {:ok, cell}, state}

      {:error, _} ->
        cell = ScreenBuffer.get_cell(state.active_buffer, x, y)
        duration = System.monotonic_time() - start_time

        System.put(cache_key, cell, namespace: :buffer)

        state = update_metrics(state, :get_cell_cache_miss, duration)
        {:reply, {:ok, cell}, state}
    end
  end

  @impl true
  def handle_call({:set_cell, x, y, cell}, _from, state) do
    {new_buffer, duration} = update_cell(state.active_buffer, x, y, cell)
    new_state = update_state_after_cell_change(state, new_buffer, duration)
    {:reply, {:ok, new_state}, new_state}
  end

  @impl true
  def handle_call({:fill_region, x, y, width, height, cell}, _from, state) do
    start_time = System.monotonic_time()

    # Update buffer
    new_buffer =
      ScreenBuffer.fill_region(state.active_buffer, x, y, width, height, cell)

    # Invalidate cache for the entire region
    invalidate_region_cache(x, y, width, height)

    duration = System.monotonic_time() - start_time
    state = %{state | active_buffer: new_buffer}
    state = update_metrics(state, :fill_region, duration)
    state = update_memory_usage(state)
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:scroll_region, x, y, width, height, amount}, _from, state) do
    start_time = System.monotonic_time()

    # Update buffers
    {new_buffer, scrollback} =
      ScreenBuffer.scroll_region(
        state.active_buffer,
        state.scrollback_buffer,
        x,
        y,
        width,
        height,
        amount
      )

    # Invalidate cache for the entire region
    invalidate_region_cache(x, y, width, height)

    duration = System.monotonic_time() - start_time
    state = %{state | active_buffer: new_buffer, scrollback_buffer: scrollback}
    state = update_metrics(state, :scroll_region, duration)
    state = update_memory_usage(state)
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    start_time = System.monotonic_time()

    # Update buffer
    new_buffer = ScreenBuffer.clear(state.active_buffer)

    # Clear entire cache
    System.clear(namespace: :buffer)

    duration = System.monotonic_time() - start_time
    state = %{state | active_buffer: new_buffer}
    state = update_metrics(state, :clear, duration)
    state = update_memory_usage(state)
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:resize, width, height}, _from, state) do
    start_time = System.monotonic_time()

    # Initialize new buffers
    {new_active, new_back} =
      initialize_buffers(width, height, state.scrollback_limit)

    # Clear cache for new dimensions
    System.clear(namespace: :buffer)

    duration = System.monotonic_time() - start_time

    state = %{
      state
      | active_buffer: new_active,
        back_buffer: new_back,
        width: width,
        height: height
    }

    # Record metrics using unified collector
    Raxol.Core.Metrics.UnifiedCollector.record_performance(
      :buffer_resize,
      duration
    )

    Raxol.Core.Metrics.UnifiedCollector.record_operation(:buffer_resize, 1,
      tags: [:buffer, :resize]
    )

    {:reply, {:ok, state}, state}
  end

  defp update_cell(buffer, x, y, cell) do
    start_time = System.monotonic_time()
    new_buffer = ScreenBuffer.set_cell(buffer, x, y, cell)
    duration = System.monotonic_time() - start_time
    {new_buffer, duration}
  end

  defp update_state_after_cell_change(state, new_buffer, duration) do
    state
    |> Map.put(:active_buffer, new_buffer)
    |> update_metrics(:set_cell, duration)
    |> update_memory_usage()
  end

  defp initialize_buffers(width, height, scrollback_limit) do
    main_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    alt_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    {main_buffer, alt_buffer}
  end

  defp update_metrics(state, operation, duration) do
    # Record performance metric
    Raxol.Core.Metrics.UnifiedCollector.record_performance(
      String.to_atom("buffer_#{operation}"),
      duration,
      tags: [:buffer, operation]
    )

    # Record operation metric
    Raxol.Core.Metrics.UnifiedCollector.record_operation(
      String.to_atom("buffer_#{operation}"),
      1,
      tags: [:buffer, operation]
    )

    state
  end

  defp update_memory_usage(state) do
    # Optimize memory usage calculation by sampling
    usage =
      if rem(System.system_time(:millisecond), 1000) == 0 do
        memory =
          MemoryManager.get_total_usage(state.active_buffer, state.back_buffer)

        # Record memory usage metric
        Raxol.Core.Metrics.UnifiedCollector.record_resource(
          :buffer_memory_usage,
          memory,
          tags: [:buffer, :memory]
        )

        memory
      else
        state.memory_usage
      end

    %{state | memory_usage: usage}
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
end
