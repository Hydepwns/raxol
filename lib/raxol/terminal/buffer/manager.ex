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
  Clears all damage regions.

  ## Examples

      iex> {:ok, pid} = Buffer.Manager.start_link()
      iex> :ok = Buffer.Manager.clear_damage(pid)
      iex> Buffer.Manager.get_damage(pid)
      []
  """
  def clear_damage(pid) do
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
  Returns the default tab stop positions for a given width.

  ## Examples

      iex> Manager.default_tab_stops(8)
      [0, 8, 16, 24, 32, 40, 48, 56]
  """
  def default_tab_stops(width) when is_integer(width) and width > 0 do
    # Standard tab stops every 8 columns, up to the given width
    Enum.take_every(0..(width - 1), 8) |> Enum.to_list()
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    scrollback_height = Keyword.get(opts, :scrollback_height, 1000)
    memory_limit = Keyword.get(opts, :memory_limit, 10_000_000)

    state = State.new(width, height, scrollback_height, memory_limit)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
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
    state = Cursor.set_position(state, x, y)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_cursor, _from, state) do
    position = Cursor.get_position(state)
    {:reply, position, state}
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
end
