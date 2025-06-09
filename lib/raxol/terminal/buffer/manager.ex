defmodule Raxol.Terminal.Buffer.Manager do
  @moduledoc """
  Manages terminal buffers and their operations.
  Coordinates between different buffer-related modules.
  """

  alias Raxol.Terminal.{
    ScreenBuffer,
    Buffer.Manager.State,
    Buffer.Manager.Buffer,
    Buffer.Manager.Cursor,
    Buffer.Manager.Damage,
    Buffer.Manager.Memory,
    Buffer.Manager.Scrollback
  }

  @type t :: State.t()

  use GenServer

  # Client API

  @doc """
  Creates a new buffer manager with the specified dimensions.

  ## Examples

      iex> {:ok, manager} = Manager.new(80, 24)
      iex> manager.active_buffer.width
      80
      iex> manager.active_buffer.height
      24
  """
  def new(width, height, scrollback_limit \\ 1000, memory_limit \\ 10_000_000) do
    State.new(width, height, scrollback_limit, memory_limit)
  end

  @doc """
  Initializes main and alternate screen buffers with the specified dimensions.

  ## Examples

      iex> {main_buffer, alt_buffer} = Manager.initialize_buffers(80, 24, 1000)
      iex> main_buffer.width
      80
      iex> alt_buffer.height
      24
  """
  def initialize_buffers(width, height, scrollback_limit) do
    main_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    alt_buffer = ScreenBuffer.new(width, height, scrollback_limit)
    {main_buffer, alt_buffer}
  end

  @doc """
  Starts a new buffer manager process.

  ## Options

    * `:width` - The width of the buffer (default: 80)
    * `:height` - The height of the buffer (default: 24)
    * `:scrollback_height` - The maximum number of scrollback lines (default: 1000)
    * `:memory_limit` - The maximum memory usage in bytes (default: 10_000_000)

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link(width: 100, height: 30)
      iex> Process.alive?(pid)
      true
  """
  def start_link(opts \\ []) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Gets the current state of the buffer manager.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> state = Buffer.Manager.get_state(pid)
      iex> state.active_buffer.width
      80
  """
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Sets a cell in the active buffer.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> cell = %Cell{char: "A", fg: :red, bg: :blue}
      iex> :ok = Buffer.Manager.set_cell(pid, 0, 0, cell)
      iex> state = Buffer.Manager.get_state(pid)
      iex> Buffer.get_cell(state, 0, 0)
      %Cell{char: "A", fg: :red, bg: :blue}
  """
  def set_cell(pid, x, y, cell) do
    GenServer.call(pid, {:set_cell, x, y, cell})
  end

  @doc """
  Gets a cell from the active buffer.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> Buffer.Manager.get_cell(pid, 0, 0)
      %Cell{char: " ", fg: :default, bg: :default}
  """
  def get_cell(pid, x, y) do
    GenServer.call(pid, {:get_cell, x, y})
  end

  @doc """
  Sets the cursor position.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> :ok = Buffer.Manager.set_cursor(pid, 10, 5)
      iex> state = Buffer.Manager.get_state(pid)
      iex> Cursor.get_position(state)
      {10, 5}
  """
  def set_cursor(pid, x, y) do
    GenServer.call(pid, {:set_cursor, x, y})
  end

  @doc """
  Gets the current cursor position.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> Buffer.Manager.get_cursor(pid)
      {0, 0}
  """
  def get_cursor(pid) do
    GenServer.call(pid, :get_cursor)
  end

  @doc """
  Gets the damaged regions in the buffer.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> Buffer.Manager.get_damage(pid)
      []
  """
  def get_damage(pid) do
    GenServer.call(pid, :get_damage)
  end

  @doc """
  Clears the damage tracking for the buffer.
  Works with both state struct and PID versions.
  """
  def clear_damage(%State{} = state) do
    Damage.clear_regions(state)
  end

  def clear_damage(pid) when is_pid(pid) do
    GenServer.call(pid, :clear_damage)
  end

  @doc """
  Gets the current memory usage.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> Buffer.Manager.get_memory_usage(pid)
      0
  """
  def get_memory_usage(pid) do
    GenServer.call(pid, :get_memory_usage)
  end

  @doc """
  Gets the number of lines in the scrollback buffer.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> Buffer.Manager.get_scrollback_count(pid)
      0
  """
  def get_scrollback_count(pid) do
    GenServer.call(pid, :get_scrollback_count)
  end

  @doc """
  Resizes the buffer.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> :ok = Buffer.Manager.resize(pid, 100, 30)
      iex> state = Buffer.Manager.get_state(pid)
      iex> state.active_buffer.width
      100
      iex> state.active_buffer.height
      30
  """
  def resize(pid, width, height) do
    GenServer.call(pid, {:resize, width, height})
  end

  @doc """
  Fills a region in the active buffer with a cell.
  Delegated from Raxol.Terminal.Buffer.
  Coordinates (x1, y1) and (x2, y2) define the top-left and bottom-right of the region.
  """
  def fill_region(pid, x1, y1, x2, y2, cell) do
    GenServer.call(pid, {:fill_region, x1, y1, x2, y2, cell})
  end

  @doc """
  Copies a region from (x1, y1)-(x2, y2) to (dest_x, dest_y) in the active buffer.
  Delegated from Raxol.Terminal.Buffer.
  """
  def copy_region(pid, x1, y1, x2, y2, dest_x, dest_y) do
    GenServer.call(pid, {:copy_region, x1, y1, x2, y2, dest_x, dest_y})
  end

  @doc """
  Scrolls a region (x1, y1)-(x2, y2) by a given amount in the active buffer.
  Delegated from Raxol.Terminal.Buffer.
  """
  def scroll_region(pid, x1, y1, x2, y2, amount) do
    GenServer.call(pid, {:scroll_region, x1, y1, x2, y2, amount})
  end

  @doc """
  Clears the active buffer.
  Delegated from Raxol.Terminal.Buffer.
  """
  def clear(pid) do
    GenServer.call(pid, :clear)
  end

  @doc """
  Returns the default tab stop positions for a given width.

  ## Examples

      iex> Manager.default_tab_stops(8)
      [0, 8, 16, 24, 32, 40, 48, 56]
  """
  def default_tab_stops(width) when is_integer(width) and width > 0 do
    # Standard tab stops every 8 columns, up to the given width
    Enum.take_every(0..(width - 1), 8) |> Enum.to_list()
  end

  @doc """
  Marks a region of the buffer as damaged (needs redraw).
  """
  def mark_damaged(state, x, y, width, height) do
    # Mark the region from (x, y) to (x + width - 1, y + height - 1)
    Damage.mark_region(state, x, y, x + width - 1, y + height - 1)
  end

  @doc """
  Updates the memory usage tracking for the buffer.
  Works with both state struct and PID versions.
  """
  def update_memory_usage(%State{} = state) do
    %{state | memory_usage: Memory.update_usage(state)}
  end

  def update_memory_usage(pid) when is_pid(pid) do
    GenServer.call(pid, :get_state)
    |> update_memory_usage()
  end

  @doc """
  Sets the cursor position in the buffer manager.
  """
  def set_cursor_position(state, x, y) do
    # Stub: Update a cursor_position field if present, else just return state
    Map.put(state, :cursor_position, {x, y})
  end

  @doc """
  Checks if the buffer needs to scroll (stub implementation).
  Returns the state unchanged for now.
  """
  def maybe_scroll(state) do
    state
  end

  @doc """
  Returns all damaged regions in the buffer manager state.
  """
  def get_damage_regions(state) do
    Damage.get_regions(state)
  end

  @doc """
  Returns true if the buffer manager's memory usage is within limits.
  """
  def within_memory_limits?(state) do
    Memory.within_limits?(state)
  end

  @doc """
  Gets the active buffer (either main or scrollback).
  """
  def get_active_buffer(%State{} = state) do
    case state.active_buffer do
      :main -> state.active_buffer
      :scrollback -> state.scrollback
    end
  end

  @doc """
  Updates the active buffer with new content.
  """
  def update_active_buffer(%State{} = state, new_content) do
    case state.active_buffer do
      :main -> %{state | active_buffer: new_content}
      :scrollback -> %{state | scrollback: new_content}
    end
  end

  @doc """
  Gets the cursor position from the manager state.
  """
  def get_cursor_position(state) do
    state.cursor_position
  end

  @doc """
  Gets the visible content of the buffer.
  """
  def get_visible_content(
        %{active_buffer: buffer, scrollback: scrollback} = _state
      ) do
    # Get scrollback lines (if any)
    scrollback_lines =
      case scrollback do
        %{lines: lines} when is_list(lines) -> lines
        _ -> []
      end

    # Get visible buffer lines as strings
    buffer_lines =
      buffer.cells
      |> Enum.map(fn row ->
        row
        |> Enum.map(&Raxol.Terminal.Cell.get_char/1)
        |> Enum.join("")
        |> String.trim_trailing()
      end)

    scrollback_lines ++ buffer_lines
  end

  @doc """
  Creates a copy of the current buffer state.
  Returns a new buffer with the same content and dimensions.
  """
  def copy(pid) do
    GenServer.call(pid, :copy)
  end

  @doc """
  Gets the differences between two buffers.
  Returns a list of {x, y, cell} tuples where the cells differ.
  """
  def get_differences(pid1, pid2) do
    GenServer.call(pid1, {:get_differences, pid2})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    scrollback_limit = Keyword.get(opts, :scrollback_height, 1000)
    memory_limit = Keyword.get(opts, :memory_limit, 10_000_000)

    state = new(width, height, scrollback_limit, memory_limit)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    new_state = Map.new(state)
    {:reply, new_state, state}
  end

  @impl true
  def handle_call({:set_cell, x, y, cell}, _from, state) do
    state = Buffer.set_cell(state, x, y, cell)
    state = Damage.mark_region(state, x, y, 1, 1)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_cell, x, y}, _from, state) do
    cell = Buffer.get_cell(state, x, y)
    {:reply, cell, state}
  end

  @impl true
  def handle_call({:set_cursor, x, y}, _from, state) do
    state = Cursor.move_to(state, x, y)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_cursor, _from, state) do
    position = Cursor.get_position(state)
    {:reply, position, state}
  end

  @impl true
  def handle_call({:set_cursor_position, x, y}, _from, state) do
    new_state = %{state | cursor: %{state.cursor | x: x, y: y}}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_damage, _from, state) do
    regions = Damage.get_regions(state)
    {:reply, regions, state}
  end

  @impl true
  def handle_call(:clear_damage, _from, state) do
    state = Damage.clear_regions(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_memory_usage, _from, state) do
    usage = Memory.get_usage(state)
    {:reply, usage, state}
  end

  @impl true
  def handle_call(:get_scrollback_count, _from, state) do
    count = Scrollback.get_line_count(state)
    {:reply, count, state}
  end

  @impl true
  def handle_call({:resize, width, height}, _from, state) do
    state = Buffer.resize(state, width, height)
    state = Damage.mark_all(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:fill_region, x1, y1, x2, y2, cell}, _from, state) do
    # x2, y2 are inclusive end coordinates.
    # Raxol.Terminal.Buffer.Manager.Buffer.fill_region expects x, y, width, height
    width = x2 - x1 + 1
    height = y2 - y1 + 1

    if width <= 0 or height <= 0 do
      Raxol.Core.Runtime.Log.warning_with_context(
        "[BufferManager] fill_region called with non-positive width/height.",
        %{x1: x1, y1: y1, x2: x2, y2: y2, width: width, height: height}
      )

      {:reply, {:error, :invalid_region}, state}
    else
      new_state =
        Raxol.Terminal.Buffer.Manager.Buffer.fill_region(
          state,
          x1,
          y1,
          width,
          height,
          cell
        )

      # Mark damage using the original x1,y1,x2,y2
      new_state_damaged =
        Raxol.Terminal.Buffer.Manager.Damage.mark_region(
          new_state,
          x1,
          y1,
          x2,
          y2
        )

      {:reply, :ok, new_state_damaged}
    end
  end

  @impl true
  def handle_call({:copy_region, x1, y1, x2, y2, dest_x, dest_y}, _from, state) do
    width = x2 - x1 + 1
    height = y2 - y1 + 1

    if width <= 0 or height <= 0 do
      Raxol.Core.Runtime.Log.warning_with_context(
        "[BufferManager] copy_region called with non-positive width/height for source.",
        %{x1: x1, y1: y1, x2: x2, y2: y2, width: width, height: height}
      )

      {:reply, {:error, :invalid_source_region}, state}
    else
      # Assuming Raxol.Terminal.Buffer.Manager.Buffer.copy_region(state, src_x, src_y, dst_x, dst_y, width, height)
      new_state =
        Raxol.Terminal.Buffer.Manager.Buffer.copy_region(
          state,
          x1,
          y1,
          dest_x,
          dest_y,
          width,
          height
        )

      # Mark damage at destination
      new_state_damaged =
        Raxol.Terminal.Buffer.Manager.Damage.mark_region(
          new_state,
          dest_x,
          dest_y,
          dest_x + width - 1,
          dest_y + height - 1
        )

      {:reply, :ok, new_state_damaged}
    end
  end

  @impl true
  def handle_call({:scroll_region, x1, y1, x2, y2, amount}, _from, state) do
    width = x2 - x1 + 1
    height = y2 - y1 + 1

    if width <= 0 or height <= 0 do
      Raxol.Core.Runtime.Log.warning_with_context(
        "[BufferManager] scroll_region called with non-positive width/height.",
        %{x1: x1, y1: y1, x2: x2, y2: y2, width: width, height: height}
      )

      {:reply, {:error, :invalid_region}, state}
    else
      # Assuming Raxol.Terminal.Buffer.Manager.Buffer.scroll_region(state, x, y, width, height, lines)
      new_state =
        Raxol.Terminal.Buffer.Manager.Buffer.scroll_region(
          state,
          x1,
          y1,
          width,
          height,
          amount
        )

      # Mark scrolled region as damaged
      new_state_damaged =
        Raxol.Terminal.Buffer.Manager.Damage.mark_region(
          new_state,
          x1,
          y1,
          x2,
          y2
        )

      {:reply, :ok, new_state_damaged}
    end
  end

  @impl true
  def handle_call(:clear, _from, state) do
    # Use Raxol.Terminal.Buffer.Manager.Buffer.clear/1 to clear the active buffer
    new_state = Raxol.Terminal.Buffer.Manager.Buffer.clear(state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:copy, _from, state) do
    new_state = Map.new(state)
    {:reply, new_state, state}
  end

  @impl true
  def handle_call({:get_differences, other_pid}, _from, state) do
    other_state = get_state(other_pid)
    differences = calculate_differences(state, other_state)
    {:reply, differences, state}
  end

  defp calculate_differences(state, other_state) do
    # Compare each field and return a map of differences
    Map.keys(state)
    |> Enum.reduce(%{}, fn key, acc ->
      if Map.get(state, key) != Map.get(other_state, key) do
        Map.put(acc, key, {Map.get(state, key), Map.get(other_state, key)})
      else
        acc
      end
    end)
  end
end
