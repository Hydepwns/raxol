defmodule Raxol.Terminal.Buffer.UnifiedManager do
  @moduledoc """
  Unified buffer management system for the Raxol terminal emulator.
  This module combines and enhances the functionality of the previous buffer managers,
  providing improved memory management, caching, and performance metrics.
  """

  @behaviour GenServer
  use GenServer
  require Logger
  require Raxol.Core.Runtime.Log
  import Raxol.Guards

  alias Raxol.Terminal.{
    ScreenBuffer,
    Buffer.MemoryManager,
    Buffer.Scroll,
    Cache.System,
    Buffer.Manager.State,
    Buffer.DamageTracker,
    Cell,
    ANSI.TextFormatting
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
  def resize(pid, width, height) when is_pid(pid) do
    GenServer.call(pid, {:resize, width, height})
  end

  @doc """
  Resizes the buffer to new dimensions (struct-based version).

  ## Parameters
    * `state` - The buffer manager state struct
    * `width` - The new width
    * `height` - The new height

  ## Returns
    * `{:ok, new_state}` - The updated buffer manager state
  """
  def resize(%__MODULE__{} = state, width, height) do
    # Validate dimensions
    if width <= 0 or height <= 0 do
      {:error, :invalid_dimensions}
    else
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
  def get_active_buffer(%__MODULE__{} = state) do
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
    case get_cell_at_coordinates(state, x, y) do
      {:valid, cell} -> {:reply, {:ok, cell}, state}
      {:invalid, cell} -> {:reply, {:ok, cell}, state}
    end
  end

  def handle_call({:set_cell, x, y, cell}, _from, state) do
    case validate_and_set_cell(state, x, y, cell) do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      {:invalid, state} -> {:reply, {:error, :invalid_coordinates}, state}
    end
  end

  def handle_call({:fill_region, x, y, width, height, cell}, _from, state) do
    if coordinates_valid_for_set?(state, x, y) and
         x + width <= state.active_buffer.width and
         y + height <= state.active_buffer.height do
      new_active_buffer = fill_region_with_cell(state.active_buffer, x, y, width, height, cell)
      new_state = %{state | active_buffer: new_active_buffer}
      new_state = update_memory_usage(new_state)
      {:reply, {:ok, new_state}, new_state}
    else
      {:reply, {:error, :invalid_region}, state}
    end
  end

  def handle_call({:scroll_region, x, y, width, height, amount}, _from, state) do
    {new_active_buffer, new_scrollback_buffer} = process_scroll_region(state, x, y, width, height, amount)
    new_state = %{state | active_buffer: new_active_buffer, scrollback_buffer: new_scrollback_buffer}
    new_state = update_memory_usage(new_state)
    {:reply, {:ok, new_state}, new_state}
  end

  def handle_call(:clear, _from, state) do
    # Clear the active buffer by creating a new one with the same dimensions
    new_active_buffer = ScreenBuffer.new(state.width, state.height)
    new_state = %{state | active_buffer: new_active_buffer}
    new_state = update_memory_usage(new_state)
    {:reply, {:ok, new_state}, new_state}
  end

  def handle_call({:resize, width, height}, _from, state) do
    case resize(state, width, height) do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:scroll_up, amount}, _from, state) do
    # Scroll the entire buffer up by the specified amount
    {new_active_buffer, new_scrollback_buffer} = process_scroll_region(state, 0, 0, state.width, state.height, amount)
    new_state = %{state | active_buffer: new_active_buffer, scrollback_buffer: new_scrollback_buffer}
    new_state = update_memory_usage(new_state)
    {:reply, {:ok, new_state}, new_state}
  end

  def handle_call({:get_history, start_line, count}, _from, state) do
    history = Scroll.get_content(state.scrollback_buffer, start_line, count)
    {:reply, {:ok, history}, state}
  end

  def handle_call({:update_visible_region, region}, _from, state) do
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
  Writes data to the buffer (PID-based version).
  """
  def write(pid, data) when is_pid(pid) do
    GenServer.call(pid, {:write, data})
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
    IO.puts("[UnifiedManager] init/1 called with opts: #{inspect(opts)}")
    Logger.debug("[UnifiedManager] init/1 called with opts: #{inspect(opts)}")
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    scrollback_limit = Keyword.get(opts, :scrollback_limit, 1000)
    memory_limit = Keyword.get(opts, :memory_limit, 10_000_000)

    # Create a minimal state for testing
    state = %__MODULE__{
      active_buffer: ScreenBuffer.new(width, height),
      back_buffer: ScreenBuffer.new(width, height),
      scrollback_buffer: Scroll.new(scrollback_limit),
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

  # Real cache wrapper functions
  defp safe_cache_get(key, namespace) do
    case System.get(key, namespace: namespace) do
      {:ok, value} -> {:ok, value}
      {:error, :not_found} -> {:error, :cache_miss}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :cache_unavailable}
  end

  defp safe_cache_put(key, value, namespace) do
    case System.put(key, value, namespace: namespace) do
      :ok -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :cache_unavailable}
  end

  defp safe_cache_clear(namespace) do
    case System.clear(namespace: namespace) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :cache_unavailable}
  end

  defp safe_cache_invalidate(key, namespace) do
    case System.invalidate(key, namespace: namespace) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    _ -> {:error, :cache_unavailable}
  end

  defp get_cell_at_coordinates(state, x, y) do
    if coordinates_valid?(state, x, y) do
      {:valid, extract_and_clean_cell(state, x, y)}
    else
      {:invalid, create_default_cell()}
    end
  end

  defp coordinates_valid?(state, x, y) do
    x >= 0 and y >= 0 and x < state.active_buffer.width and
      y < state.active_buffer.height
  end

  defp create_default_cell do
    %Raxol.Terminal.Cell{
      char: " ",
      style: nil,
      dirty: nil,
      wide_placeholder: false
    }
  end

  defp extract_and_clean_cell(state, x, y) do
    cell = get_cell_from_buffer(state.active_buffer, x, y)

    if cell_empty?(cell) do
      create_default_cell()
    else
      clean_cell_style(cell)
    end
  end

  defp get_cell_from_buffer(buffer, x, y) do
    buffer.cells
    |> Enum.at(y, [])
    |> Enum.at(x)
  end

  defp cell_empty?(cell) do
    nil?(cell) or cell == %{}
  end

  defp clean_cell_style(cell) do
    style = if has_default_style?(cell.style), do: nil, else: cell.style
    %{cell | dirty: nil, style: style}
  end

  defp has_default_style?(nil), do: true

  defp has_default_style?(style) do
    has_default_colors?(style) and
      has_default_attributes?(style) and
      has_default_effects?(style)
  end

  defp has_default_colors?(style) do
    style.foreground == nil and style.background == nil
  end

  defp has_default_attributes?(style) do
    style.bold == false and
      style.italic == false and
      style.underline == false and
      style.blink == false and
      style.reverse == false and
      style.faint == false and
      style.conceal == false and
      style.strikethrough == false and
      style.fraktur == false
  end

  defp has_default_effects?(style) do
    style.double_width == false and
      style.double_height == :none and
      style.double_underline == false and
      style.framed == false and
      style.encircled == false and
      style.overlined == false and
      style.hyperlink == nil
  end

  defp validate_and_set_cell(state, x, y, cell) do
    if coordinates_valid_for_set?(state, x, y) do
      new_cell = create_cell_from_input(cell)

      new_active_buffer =
        update_buffer_cell(state.active_buffer, x, y, new_cell)

      new_state = %{state | active_buffer: new_active_buffer}
      new_state = update_memory_usage(new_state)
      {:ok, new_state}
    else
      {:invalid, state}
    end
  end

  defp coordinates_valid_for_set?(state, x, y) do
    x >= 0 and y >= 0 and x < state.active_buffer.width and
      y < state.active_buffer.height
  end

  defp create_cell_from_input(cell) do
    %Raxol.Terminal.Cell{
      char: cell.char,
      style: cell.style,
      dirty: nil,
      wide_placeholder: false
    }
  end

  defp update_buffer_cell(buffer, x, y, new_cell) do
    updated_cells =
      buffer.cells
      |> List.update_at(y, fn row ->
        List.update_at(row, x, fn _ -> new_cell end)
      end)

    %{buffer | cells: updated_cells}
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
      cache_key = {:cell, i, j}
      safe_cache_invalidate(cache_key, :buffer)
    end
  end

  defp process_command(state, command) do
    Raxol.Terminal.Buffer.CommandHandler.handle_command(state, command)
  end

  # Add helper function for filling regions
  defp fill_region_with_cell(buffer, x, y, width, height, cell) do
    new_cell = create_cell_from_input(cell)

    updated_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_y} ->
        if row_in_region?(row_y, y, height) do
          update_row_in_region(row, x, width, new_cell)
        else
          row
        end
      end)

    %{buffer | cells: updated_cells}
  end

  defp row_in_region?(row_y, y, height) do
    row_y >= y and row_y < y + height
  end

  defp update_row_in_region(row, x, width, new_cell) do
    row
    |> Enum.with_index()
    |> Enum.map(fn {col_cell, col_x} ->
      if col_in_region?(col_x, x, width) do
        new_cell
      else
        col_cell
      end
    end)
  end

  defp col_in_region?(col_x, x, width) do
    col_x >= x and col_x < x + width
  end

  # Process scroll region function
  defp process_scroll_region(state, x, y, width, height, amount) do
    # Validate region bounds
    if x < 0 or y < 0 or width <= 0 or height <= 0 or
         x + width > state.active_buffer.width or
         y + height > state.active_buffer.height do
      # Invalid region, return unchanged buffers
      {state.active_buffer, state.scrollback_buffer}
    else
      # Perform scrolling within the region
      new_active_buffer =
        scroll_region_in_buffer(
          state.active_buffer,
          x,
          y,
          width,
          height,
          amount
        )

      # Add scrolled content to scrollback buffer
      scrolled_lines =
        extract_scrolled_lines(state.active_buffer, x, y, width, height, amount)

      new_scrollback_buffer =
        add_lines_to_scrollback(state.scrollback_buffer, scrolled_lines)

      {new_active_buffer, new_scrollback_buffer}
    end
  end

  # Extract lines that are scrolled out of the region
  defp extract_scrolled_lines(buffer, x, y, width, height, amount)
       when amount > 0 do
    # When scrolling up, the top 'amount' lines are scrolled out
    Enum.map(0..(amount - 1), fn i ->
      row_y = y + i

      if row_y < buffer.height do
        Enum.slice(buffer.cells |> Enum.at(row_y, []), x, width)
      else
        []
      end
    end)
    |> Enum.filter(fn line -> line != [] end)
  end

  defp extract_scrolled_lines(buffer, x, y, width, height, amount)
       when amount < 0 do
    # When scrolling down, the bottom 'abs(amount)' lines are scrolled out
    abs_amount = abs(amount)

    Enum.map((height - abs_amount)..(height - 1), fn i ->
      row_y = y + i

      if row_y < buffer.height do
        Enum.slice(buffer.cells |> Enum.at(row_y, []), x, width)
      else
        []
      end
    end)
    |> Enum.filter(fn line -> line != [] end)
  end

  # Add lines to scrollback buffer
  defp add_lines_to_scrollback(scrollback_buffer, lines) do
    if lines != [] do
      Scroll.add_content(scrollback_buffer, lines)
    else
      scrollback_buffer
    end
  end

  defp scroll_region_in_buffer(buffer, x, y, width, height, amount) do
    if amount > 0 do
      # Scroll up: move content up within the region
      scroll_region_up(buffer, x, y, width, height, amount)
    else
      # Scroll down: move content down within the region
      scroll_region_down(buffer, x, y, width, height, abs(amount))
    end
  end

  defp scroll_region_up(buffer, x, y, width, height, amount) do
    # Extract the region lines
    region_lines = Enum.slice(buffer.cells, y, height)

    # Split the region into scroll_lines (lines that will be scrolled out) and remaining (lines that will stay)
    {scroll_lines, remaining} = Enum.split(region_lines, amount)

    # Create empty lines for the scrolled-out lines - only for the region width
    empty_line = List.duplicate(Cell.new(), width)
    empty_lines = List.duplicate(empty_line, length(scroll_lines))

    # New region: remaining lines + empty lines at bottom
    new_region_lines = remaining ++ empty_lines

    # Replace only the region in the buffer
    replace_region_in_buffer(buffer, x, y, width, height, new_region_lines)
  end

  defp scroll_region_down(buffer, x, y, width, height, amount) do
    # Extract the region lines
    region_lines = Enum.slice(buffer.cells, y, height)

    # Scroll the region content down: move lines starting from 0 down by 'amount' positions
    # Lines height-amount to height-1 are lost, lines 0 to height-amount-1 move down
    {lines_to_move, _} = Enum.split(region_lines, height - amount)

    # Create empty lines for the top - only for the region width
    empty_line = List.duplicate(Cell.new(), width)
    empty_lines = List.duplicate(empty_line, amount)

    # New region: empty lines at top + moved lines
    new_region_lines = empty_lines ++ lines_to_move

    # Replace only the region in the buffer
    replace_region_in_buffer(buffer, x, y, width, height, new_region_lines)
  end

  # Helper function to replace a region in the buffer
  defp replace_region_in_buffer(buffer, x, y, width, height, new_region_lines) do
    new_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_y} ->
        if row_y >= y and row_y < y + height do
          region_row = Enum.at(new_region_lines, row_y - y)

          row
          |> Enum.with_index()
          |> Enum.map(fn {cell, col_x} ->
            if col_x >= x and col_x < x + width do
              Enum.at(region_row, col_x - x)
            else
              cell
            end
          end)
        else
          row
        end
      end)

    %{buffer | cells: new_cells}
  end

  # Private function to update state with commands (including config updates)
  defp update_state(state, commands) when is_list(commands) do
    Enum.reduce_while(commands, {:ok, state}, fn command,
                                                 {:ok, current_state} ->
      case update_single_command(current_state, command) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        error -> {:halt, error}
      end
    end)
  end

  defp update_state(state, command) do
    update_single_command(state, command)
  end

  # Handle individual command updates
  defp update_single_command(state, %{width: width, height: height} = _config) do
    # Update dimensions and resize buffers if needed
    if width != state.width or height != state.height do
      # Resize buffers
      new_active_buffer =
        ScreenBuffer.resize(state.active_buffer, height, width)

      new_back_buffer = ScreenBuffer.resize(state.back_buffer, height, width)

      # Clear cache since buffer dimensions changed
      safe_cache_clear(:buffer)

      {:ok,
       %{
         state
         | width: width,
           height: height,
           active_buffer: new_active_buffer,
           back_buffer: new_back_buffer
       }}
    else
      {:ok, state}
    end
  end

  defp update_single_command(state, %{scrollback_limit: limit}) do
    # Update scrollback limit
    new_scrollback_buffer =
      Scroll.set_max_height(state.scrollback_buffer, limit)

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

  defp process_write_data(state, data) when is_binary(data) do
    # Convert string data to cells and write to buffer
    cells =
      String.graphemes(data)
      |> Enum.with_index()
      |> Enum.map(fn {char, _index} ->
        %Raxol.Terminal.Cell{
          char: char,
          style: nil,
          dirty: true,
          wide_placeholder: false
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
      if x < buffer.width and y < buffer.height do
        ScreenBuffer.write_char(acc_buffer, x, y, cell.char, cell.style)
      else
        acc_buffer
      end
    end)
  end

  def handle_info(msg, state) do
    Logger.debug("[UnifiedManager] Ignored unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end
