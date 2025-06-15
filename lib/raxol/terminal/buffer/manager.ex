defmodule Raxol.Terminal.Buffer.Manager do
  @moduledoc """
  Manages terminal buffer operations and state.
  """

  use GenServer
  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Buffer.Manager.{BufferImpl, Behaviour}
  alias Raxol.Terminal.Buffer.{Operations, DamageTracker, ScrollbackManager}
  alias Raxol.Terminal.{MemoryManager, ScreenBuffer}
  alias Raxol.Terminal.Integration.Renderer

  @behaviour Behaviour

  defstruct [
    :buffer,
    :damage_tracker,
    :memory_manager,
    :metrics,
    :renderer,
    :scrollback_manager,
    :cursor_position
  ]

  @type t :: %__MODULE__{
          buffer: BufferImpl.t(),
          damage_tracker: term(),
          memory_manager: term(),
          metrics: term(),
          renderer: term(),
          scrollback_manager: term(),
          cursor_position: {non_neg_integer(), non_neg_integer()} | nil
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts,
      name: Keyword.get(opts, :name, __MODULE__)
    )
  end

  @impl true
  def init(opts) do
    {:ok, memory_manager} = MemoryManager.start_link()

    state = %__MODULE__{
      buffer: Operations.new(opts),
      memory_manager: memory_manager,
      damage_tracker: DamageTracker.new(),
      scrollback_manager: ScrollbackManager.new(),
      renderer: Renderer.new(ScreenBuffer.new(80, 24)),
      metrics: %{
        writes: 0,
        reads: 0,
        scrolls: 0,
        memory_usage: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def initialize_buffers(width, height, opts \\ []) do
    GenServer.call(__MODULE__, {:initialize_buffers, width, height, opts})
  end

  @impl true
  def write(data, opts \\ []) do
    GenServer.call(__MODULE__, {:write, data, opts})
  end

  @impl true
  def read(opts \\ []) do
    GenServer.call(__MODULE__, {:read, opts})
  end

  @impl true
  def resize(size, opts \\ []) do
    GenServer.call(__MODULE__, {:resize, size, opts})
  end

  @impl true
  def scroll(lines) do
    GenServer.call(__MODULE__, {:scroll, lines})
  end

  @impl true
  def set_cell(x, y, cell) do
    GenServer.call(__MODULE__, {:set_cell, x, y, cell})
  end

  @impl true
  def get_cell(x, y) do
    GenServer.call(__MODULE__, {:get_cell, x, y})
  end

  def get_line(y) do
    GenServer.call(__MODULE__, {:get_line, y})
  end

  def set_line(y, line) do
    GenServer.call(__MODULE__, {:set_line, y, line})
  end

  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  def get_size do
    GenServer.call(__MODULE__, :get_size)
  end

  def get_cursor do
    GenServer.call(__MODULE__, :get_cursor)
  end

  def set_cursor(cursor) do
    GenServer.call(__MODULE__, {:set_cursor, cursor})
  end

  def get_attributes do
    GenServer.call(__MODULE__, :get_attributes)
  end

  def set_attributes(attributes) do
    GenServer.call(__MODULE__, {:set_attributes, attributes})
  end

  def get_mode do
    GenServer.call(__MODULE__, :get_mode)
  end

  def set_mode(mode) do
    GenServer.call(__MODULE__, {:set_mode, mode})
  end

  def get_title do
    GenServer.call(__MODULE__, :get_title)
  end

  def set_title(title) do
    GenServer.call(__MODULE__, {:set_title, title})
  end

  def get_icon_name do
    GenServer.call(__MODULE__, :get_icon_name)
  end

  def set_icon_name(icon_name) do
    GenServer.call(__MODULE__, {:set_icon_name, icon_name})
  end

  def get_icon_title do
    GenServer.call(__MODULE__, :get_icon_title)
  end

  @impl true
  def get_memory_usage do
    GenServer.call(__MODULE__, :get_memory_usage)
  end

  @impl true
  def get_scrollback_count do
    GenServer.call(__MODULE__, :get_scrollback_count)
  end

  @impl true
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  def get_active_buffer(%__MODULE__{} = state) do
    {:ok, state.buffer}
  end

  def default_tab_stops(%__MODULE__{}) do
    {:ok, [8, 16, 24, 32, 40, 48, 56, 64, 72, 80]}
  end

  def set_cursor(%__MODULE__{} = manager, {x, y})
      when is_integer(x) and is_integer(y) do
    %{manager | cursor_position: {x, y}}
  end

  @impl true
  def clear_damage do
    GenServer.call(__MODULE__, :clear_damage)
  end

  # Server callbacks

  @impl true
  def handle_call({:initialize_buffers, width, height, _opts}, _from, state) do
    new_buffer = BufferImpl.new(width, height)
    new_state = %{state | buffer: new_buffer}
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:write, data, opts}, _from, state) do
    new_buffer = Operations.write(state.buffer, data, opts)
    new_state = update_metrics(%{state | buffer: new_buffer}, :writes)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:read, opts}, _from, state) do
    {data, new_buffer} = Operations.read(state.buffer, opts)
    new_state = update_metrics(%{state | buffer: new_buffer}, :reads)
    {:reply, data, new_state}
  end

  @impl true
  def handle_call({:resize, size, opts}, _from, state) do
    new_buffer = Operations.resize(state.buffer, size, opts)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:scroll, lines}, _from, state) do
    new_buffer = Operations.scroll(state.buffer, lines)
    new_state = update_metrics(%{state | buffer: new_buffer}, :scrolls)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:set_cell, x, y, cell}, _from, state) do
    new_buffer = BufferImpl.set_cell(state.buffer, x, y, cell)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_cell, x, y}, _from, state) do
    cell = BufferImpl.get_cell(state.buffer, x, y)
    {:reply, cell, state}
  end

  @impl true
  def handle_call({:get_line, y}, _from, state) do
    line = BufferImpl.get_line(state.buffer, y)
    {:reply, line, state}
  end

  @impl true
  def handle_call({:set_line, y, line}, _from, state) do
    new_buffer = BufferImpl.set_line(state.buffer, y, line)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    new_buffer = BufferImpl.clear(state.buffer)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_size, _from, state) do
    size = BufferImpl.get_size(state.buffer)
    {:reply, size, state}
  end

  @impl true
  def handle_call(:get_cursor, _from, state) do
    cursor = BufferImpl.get_cursor(state.buffer)
    {:reply, cursor, state}
  end

  @impl true
  def handle_call({:set_cursor, cursor}, _from, state) do
    new_buffer = BufferImpl.set_cursor(state.buffer, cursor)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_attributes, _from, state) do
    attributes = BufferImpl.get_attributes(state.buffer)
    {:reply, attributes, state}
  end

  @impl true
  def handle_call({:set_attributes, attributes}, _from, state) do
    new_buffer = BufferImpl.set_attributes(state.buffer, attributes)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_mode, _from, state) do
    mode = BufferImpl.get_mode(state.buffer)
    {:reply, mode, state}
  end

  @impl true
  def handle_call({:set_mode, mode}, _from, state) do
    new_buffer = BufferImpl.set_mode(state.buffer, mode)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_title, _from, state) do
    title = BufferImpl.get_title(state.buffer)
    {:reply, title, state}
  end

  @impl true
  def handle_call({:set_title, title}, _from, state) do
    new_buffer = BufferImpl.set_title(state.buffer, title)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_icon_name, _from, state) do
    icon_name = BufferImpl.get_icon_name(state.buffer)
    {:reply, icon_name, state}
  end

  @impl true
  def handle_call({:set_icon_name, icon_name}, _from, state) do
    new_buffer = BufferImpl.set_icon_name(state.buffer, icon_name)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:clear_damage, _from, state) do
    new_damage_tracker = DamageTracker.clear_regions(state.damage_tracker)
    new_state = %{state | damage_tracker: new_damage_tracker}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_memory_usage, _from, state) do
    usage = MemoryManager.get_memory_usage(state.memory_manager)
    {:reply, usage, state}
  end

  @impl true
  def handle_call(:get_scrollback_count, _from, state) do
    count = ScrollbackManager.get_scrollback_count(state.scrollback_manager)
    {:reply, count, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  # Private functions

  defp update_metrics(state, metric) do
    metrics = Map.update!(state.metrics, metric, &(&1 + 1))
    %{state | metrics: metrics}
  end
end
