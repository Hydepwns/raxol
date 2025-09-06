defmodule Raxol.Terminal.Buffer.UnifiedManager do
  @moduledoc """
  Unified buffer management system for the Raxol terminal emulator.
  This module combines and enhances the functionality of the previous buffer managers,
  providing improved memory management, caching, and performance metrics.
  """

  use GenServer
  require Logger
  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.{
    ScreenBuffer,
    Buffer.Scroll,
    Buffer.DamageTracker,
    Buffer.Cell
  }

  # New modular components
  alias Raxol.Terminal.Buffer.UnifiedManager.{
    Cache,
    CellOperations,
    Memory,
    Region
  }

  alias Raxol.Terminal.Buffer.UnifiedManager.Scroll, as: ScrollOperations

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
      scrollback_buffer: Raxol.Terminal.Buffer.Scroll.new(scrollback_limit),
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
    opts = case is_map(opts) do
      true -> Enum.into(opts, [])
      false -> opts
    end
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

    start_genserver_with_name(valid_name, gen_server_opts)
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
  def get_cell(pid, x, y) when is_pid(pid) do
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
  def set_cell(pid, x, y, cell) when is_pid(pid) do
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
  def fill_region(pid, x, y, width, height, cell) when is_pid(pid) do
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
  def scroll_region(pid, x, y, width, height, amount) when is_pid(pid) do
    GenServer.call(pid, {:scroll_region, x, y, width, height, amount})
  end

  @doc """
  Clears the active buffer.

  ## Parameters
    * `state` - The buffer manager state

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def clear(pid) when is_pid(pid) do
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
  def resize(pid, width, height) when is_pid(pid) do
    GenServer.call(pid, {:resize, width, height})
  end

  def resize(%__MODULE__{} = state, width, height) do
    # Validate dimensions
    case validate_dimensions(width, height) do
      :valid ->
        # Resize buffers
        new_active_buffer =
          ScreenBuffer.resize(state.active_buffer, height, width)

        new_back_buffer = ScreenBuffer.resize(state.back_buffer, height, width)

        # Clear the resized buffers to ensure they start with empty content
        new_active_buffer = ScreenBuffer.clear(new_active_buffer, nil)
        new_back_buffer = ScreenBuffer.clear(new_back_buffer, nil)

        new_state = %{
          state
          | active_buffer: new_active_buffer,
            back_buffer: new_back_buffer,
            width: width,
            height: height
        }

        {:ok, new_state}

      :invalid ->
        {:error, :invalid_dimensions}
    end
  end

  @doc """
  Scrolls up in the buffer.

  ## Parameters
    * `state` - The buffer manager state
    * `amount` - The number of lines to scroll up

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def scroll_up(pid, amount) when is_pid(pid) do
    GenServer.call(pid, {:scroll_up, amount})
  end

  @doc """
  Scrolls the buffer up by the specified amount (3-parameter version for compatibility).

  ## Parameters
    * `pid` - The buffer manager process ID
    * `start_line` - The starting line (ignored, kept for compatibility)
    * `amount` - The number of lines to scroll up

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def scroll_up(pid, _start_line, amount) when is_pid(pid) do
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
  def get_history(pid, start_line, count) when is_pid(pid) do
    GenServer.call(pid, {:get_history, start_line, count})
  end

  @doc """
  Gets the active buffer.
  """
  def get_screen_buffer(%__MODULE__{} = state) do
    {:ok, state.active_buffer}
  end

  @doc """
  Updates the buffer with new commands.
  """
  def update(pid, commands) when is_pid(pid) do
    GenServer.call(pid, {:update, commands})
  end

  def handle_call({:update, commands}, _from, state) do
    case update_state(state, commands) do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:get_cell, x, y}, _from, state) do
    cache_key = "cell_#{x}_#{y}"

    # get_cell_with_cache always returns {:ok, cell}
    {:ok, cell} = get_cell_with_cache(state, x, y, cache_key)
    {:reply, {:ok, cell}, state}
  end

  def handle_call({:set_cell, x, y, cell}, _from, state) do
    case validate_and_set_cell(state, x, y, cell) do
      {:ok, new_state} ->
        # Invalidate cache for this cell
        cache_key = "cell_#{x}_#{y}"
        Cache.invalidate(cache_key, :buffer)
        {:reply, {:ok, new_state}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:fill_region, x, y, width, height, cell}, _from, state) do
    case process_fill_region(state, x, y, width, height, cell) do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:scroll_region, x, y, width, height, amount}, _from, state) do
    {new_active_buffer, new_scrollback_buffer} =
      ScrollOperations.process_scroll_region(state, x, y, width, height, amount)

    new_state = %{
      state
      | active_buffer: new_active_buffer,
        scrollback_buffer: new_scrollback_buffer
    }

    new_state = Memory.update_memory_usage(new_state)

    # Invalidate cache for the affected region
    Cache.invalidate_region(x, y, width, height, :buffer)

    {:reply, {:ok, new_state}, new_state}
  end

  def handle_call(:clear, _from, state) do
    # Clear the active buffer by creating a new one with the same dimensions
    new_active_buffer = ScreenBuffer.new(state.width, state.height)
    new_state = %{state | active_buffer: new_active_buffer}
    new_state = Memory.update_memory_usage(new_state)

    # Clear the entire buffer cache
    Cache.clear(:buffer)

    {:reply, {:ok, new_state}, new_state}
  end

  def handle_call({:resize, width, height}, _from, state) do
    case resize(state, width, height) do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:get_total_lines, _from, state) do
    total_lines =
      state.height + ScrollOperations.get_size(state.scrollback_buffer)

    {:reply, {:ok, total_lines}, state}
  end

  def handle_call({:scroll_up, amount}, _from, state) do
    # Scroll the entire buffer up by the specified amount
    {new_active_buffer, new_scrollback_buffer} =
      ScrollOperations.process_scroll_region(
        state,
        0,
        0,
        state.width,
        state.height,
        amount
      )

    new_state = %{
      state
      | active_buffer: new_active_buffer,
        scrollback_buffer: new_scrollback_buffer
    }

    new_state = Memory.update_memory_usage(new_state)

    # Invalidate cache for the entire buffer since scroll affects all content
    Cache.clear(:buffer)

    {:reply, {:ok, new_state}, new_state}
  end

  def handle_call({:get_history, _start_line, count}, _from, state) do
    history = ScrollOperations.get_view(state.scrollback_buffer, count)
    {:reply, {:ok, history}, state}
  end

  def handle_call({:update_visible_region, _region}, _from, state) do
    # Update the visible region (placeholder implementation)
    {:reply, {:ok, state}, state}
  end

  def handle_call({:write, data}, _from, state) do
    case process_write_data(state, data) do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
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
  def update_visible_region(pid \\ __MODULE__, region) do
    GenServer.call(pid, {:update_visible_region, region})
  end

  @doc """
  Gets the total number of lines in the buffer.
  """
  def get_total_lines(pid \\ __MODULE__) do
    GenServer.call(pid, :get_total_lines)
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
  def write(pid \\ __MODULE__, data) do
    GenServer.call(pid, {:write, data})
  end

  @doc """
  Gets the memory usage of the buffer.
  """
  def get_memory_usage(%__MODULE__{} = state) do
    Memory.get_memory_usage(state)
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
    ScrollOperations.cleanup(state.scrollback_buffer)
    Raxol.Terminal.Buffer.DamageTracker.cleanup(state.damage_tracker)
    :ok
  end

  def cleanup(_other) do
    # Handle cases where a plain map or other type is passed
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
    Logger.debug("[UnifiedManager] init/1 called with opts: #{inspect(opts)}")
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    scrollback_limit = Keyword.get(opts, :scrollback_limit, 1000)
    memory_limit = Keyword.get(opts, :memory_limit, 10_000_000)

    # Create a minimal state for testing
    state = %__MODULE__{
      active_buffer: ScreenBuffer.new(width, height),
      back_buffer: ScreenBuffer.new(width, height),
      scrollback_buffer: Raxol.Terminal.Buffer.Scroll.new(scrollback_limit),
      damage_tracker: DamageTracker.new(),
      width: width,
      height: height,
      scrollback_limit: scrollback_limit,
      memory_limit: memory_limit,
      memory_usage: 0,
      metrics: %{
        operations: %{},
        memory: %{},
        performance: %{}
      }
    }

    Logger.debug("[UnifiedManager] init/1 completed, state initialized")
    {:ok, state}
  end

  defp validate_and_set_cell(state, x, y, cell) do
    coordinates_valid = CellOperations.coordinates_valid_for_set?(state, x, y)
    process_cell_setting(coordinates_valid, state, x, y, cell)
  end

  defp process_cell_setting(false, _state, _x, _y, _cell),
    do: {:error, :invalid_coordinates}

  defp process_cell_setting(true, state, x, y, cell) do
    new_cell = CellOperations.create_cell_from_input(cell)

    new_active_buffer =
      CellOperations.update_buffer_cell(state.active_buffer, x, y, new_cell)

    new_state = %{state | active_buffer: new_active_buffer}
    new_state = Memory.update_memory_usage(new_state)
    {:ok, new_state}
  end

  # Private function to update state with commands (including config updates)
  defp update_state(state, commands) when is_list(commands) do
    Enum.reduce_while(commands, {:ok, state}, fn command,
                                                 {:ok, current_state} ->
      case update_single_command(current_state, command) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
      end
    end)
  end

  defp update_state(state, command) do
    update_single_command(state, command)
  end

  # Handle individual command updates
  defp update_single_command(state, %{width: width, height: height} = _config) do
    # Update dimensions and resize buffers if needed
    dimensions_changed = width != state.width or height != state.height
    handle_dimension_update(dimensions_changed, state, width, height)
  end

  defp update_single_command(state, %{scrollback_limit: limit}) do
    # Update scrollback limit
    new_scrollback_buffer =
      ScrollOperations.set_max_height(state.scrollback_buffer, limit)

    {:ok,
     %{
       state
       | scrollback_limit: limit,
         scrollback_buffer: new_scrollback_buffer
     }}
  end

  defp update_single_command(state, %{memory_limit: limit}) do
    # Update memory limit
    {:ok, %{state | memory_limit: limit}}
  end

  defp update_single_command(state, config) when is_map(config) do
    # Handle any other config fields by merging them into state
    updated_state = Map.merge(state, config)
    {:ok, updated_state}
  end

  defp update_single_command(state, _command) do
    # Unknown command, return state unchanged
    {:ok, state}
  end

  defp handle_dimension_update(false, state, _width, _height), do: {:ok, state}

  defp handle_dimension_update(true, state, width, height) do
    # Resize buffers
    new_active_buffer =
      ScreenBuffer.resize(state.active_buffer, height, width)

    new_back_buffer = ScreenBuffer.resize(state.back_buffer, height, width)

    # Clear cache since buffer dimensions changed
    Cache.clear(:buffer)

    {:ok,
     %{
       state
       | width: width,
         height: height,
         active_buffer: new_active_buffer,
         back_buffer: new_back_buffer
     }}
  end

  defp process_write_data(state, data) when is_binary(data) do
    # Convert string data to cells and write to buffer
    cells =
      String.graphemes(data)
      |> Enum.with_index()
      |> Enum.map(fn {char, _index} ->
        %Raxol.Terminal.Buffer.Cell{
          char: char,
          foreground: nil,
          background: nil,
          attributes: %{},
          hyperlink: nil,
          width: 1,
          fg: nil,
          bg: nil
        }
      end)

    # Write cells to the active buffer starting at cursor position
    # For now, just write to the beginning of the buffer
    new_active_buffer = write_cells_to_buffer(state.active_buffer, cells, 0, 0)

    {:ok, %{state | active_buffer: new_active_buffer}}
  end

  defp process_write_data(_state, _data) do
    {:error, :invalid_data}
  end

  defp write_cells_to_buffer(buffer, cells, start_x, start_y) do
    # Write cells to the buffer starting at the specified position
    Enum.reduce(Enum.with_index(cells), buffer, fn {cell, index}, acc_buffer ->
      x = start_x + index
      y = start_y

      # Only write if within buffer bounds
      within_bounds = x < buffer.width and y < buffer.height
      write_cell_if_in_bounds(within_bounds, acc_buffer, x, y, cell)
    end)
  end

  def handle_info(msg, state) do
    Logger.debug("[UnifiedManager] Ignored unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private helper functions

  defp get_cell_with_cache(state, x, y, cache_key) do
    # Try to get from cache first
    case Cache.get(cache_key, :buffer) do
      {:ok, cached_cell} ->
        {:ok, cached_cell}

      {:error, :cache_miss} ->
        # Cache miss, get from buffer and cache the result
        # get_cell_direct always returns {:ok, cell}
        {:ok, cell} = get_cell_direct(state, x, y)
        Cache.put(cache_key, cell, :buffer)
        {:ok, cell}

      {:error, _reason} ->
        # Cache unavailable, fall back to direct access
        get_cell_direct(state, x, y)
    end
  end

  defp get_cell_direct(state, x, y) do
    case CellOperations.get_cell_at_coordinates(state, x, y) do
      {:valid, cell} ->
        {:ok, cell}

      {:invalid, cell} ->
        # Return default cell for invalid coordinates
        {:ok, cell}
    end
  end

  defp process_fill_region(state, x, y, width, height, cell) do
    region_valid = Region.region_valid?(state, x, y, width, height)
    handle_fill_region(region_valid, state, x, y, width, height, cell)
  end

  defp handle_fill_region(false, _state, _x, _y, _width, _height, _cell) do
    {:error, :invalid_region}
  end

  defp handle_fill_region(true, state, x, y, width, height, cell) do
    new_active_buffer =
      Region.fill_region_with_cell(
        state.active_buffer,
        x,
        y,
        width,
        height,
        cell
      )

    new_state = %{state | active_buffer: new_active_buffer}
    new_state = Memory.update_memory_usage(new_state)
    Cache.invalidate_region(x, y, width, height, :buffer)
    {:ok, new_state}
  end

  # Missing helper functions

  defp start_genserver_with_name(nil, opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  defp start_genserver_with_name(name, opts) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  defp validate_dimensions(width, height) when width > 0 and height > 0,
    do: :valid

  defp validate_dimensions(_width, _height), do: :invalid

  defp write_cell_if_in_bounds(false, acc_buffer, _x, _y, _cell), do: acc_buffer

  defp write_cell_if_in_bounds(true, acc_buffer, x, y, cell) do
    # Convert Buffer.Cell to proper style format for ScreenBuffer
    style = %{
      foreground: cell.foreground,
      background: cell.background
    }

    ScreenBuffer.write_char(acc_buffer, x, y, cell.char, style)
  end
end
