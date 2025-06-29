defmodule Raxol.Terminal.Buffer.Manager do
  @moduledoc """
  Manages terminal buffers including active buffer, alternate buffer, and scrollback.
  This module is responsible for buffer operations and state management.
  """

  use GenServer
  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Buffer.Manager.{BufferImpl, Behaviour}
  alias Raxol.Terminal.Buffer.{Operations, DamageTracker, ScrollbackManager}
  alias Raxol.Terminal.{MemoryManager, ScreenBuffer, Emulator, Buffer}
  alias Raxol.Terminal.Integration.Renderer

  @behaviour Behaviour

  defstruct [
    :buffer,
    :damage_tracker,
    :memory_manager,
    :metrics,
    :renderer,
    :scrollback_manager,
    :cursor_position,
    :lock
  ]

  @type t :: %__MODULE__{
          buffer: BufferImpl.t(),
          damage_tracker: term(),
          memory_manager: term(),
          metrics: term(),
          renderer: term(),
          scrollback_manager: term(),
          cursor_position: {non_neg_integer(), non_neg_integer()} | nil,
          lock: :ets.tid()
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts,
      name: Keyword.get(opts, :name, __MODULE__)
    )
  end

  @doc """
  Creates a new buffer manager with default dimensions.
  """
  def new do
    {:ok, pid} = start_link()
    GenServer.call(pid, :get_state)
  end

  @doc """
  Creates a new buffer manager with specified width and height.
  """
  def new(width, height) do
    {:ok, pid} = start_link(width: width, height: height)
    GenServer.call(pid, :get_state)
  end

  @doc """
  Creates a new buffer manager with specified width, height, and options.
  """
  def new(width, height, opts) do
    {:ok, pid} = start_link([width: width, height: height] ++ opts)
    GenServer.call(pid, :get_state)
  end

  @doc """
  Creates a new buffer manager with specified width, height, scrollback height, and memory limit.
  """
  def new(width, height, scrollback_height, memory_limit) do
    {:ok, pid} =
      start_link(
        width: width,
        height: height,
        scrollback_height: scrollback_height,
        memory_limit: memory_limit
      )

    GenServer.call(pid, :get_state)
  end

  @impl GenServer
  def init(opts) do
    {:ok, memory_manager} = MemoryManager.start_link()
    lock = :ets.new(:buffer_lock, [:set, :private])

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
      },
      lock: lock
    }

    {:ok, state}
  end

  @doc """
  Performs an atomic operation on the buffer.
  This ensures thread safety for concurrent operations.
  """
  def atomic_operation(pid, operation) when is_function(operation) do
    GenServer.call(pid, {:atomic_operation, operation})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def initialize_buffers(width, height, opts \\ []) do
    GenServer.call(__MODULE__, {:initialize_buffers, width, height, opts})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def write(data, opts \\ []) do
    GenServer.call(__MODULE__, {:write, data, opts})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def read(opts \\ []) do
    GenServer.call(__MODULE__, {:read, opts})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def resize(size, opts \\ []) do
    GenServer.call(__MODULE__, {:resize, size, opts})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def scroll(lines) do
    GenServer.call(__MODULE__, {:scroll, lines})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def set_cell(x, y, cell) do
    GenServer.call(__MODULE__, {:set_cell, x, y, cell})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
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

  def set_cursor(%__MODULE__{} = manager, {x, y})
      when is_integer(x) and is_integer(y) do
    %{manager | cursor_position: {x, y}}
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

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def get_memory_usage do
    GenServer.call(__MODULE__, :get_memory_usage)
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def get_scrollback_count do
    GenServer.call(__MODULE__, :get_scrollback_count)
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def clear_damage(%__MODULE__{} = manager) do
    %{
      manager
      | damage_tracker: DamageTracker.clear_damage(manager.damage_tracker)
    }
  end

  def get_active_buffer(%__MODULE__{} = state) do
    {:ok, state.buffer}
  end

  def default_tab_stops(%__MODULE__{}) do
    {:ok, [8, 16, 24, 32, 40, 48, 56, 64, 72, 80]}
  end

  @doc """
  Marks a region as damaged for rendering optimization.
  """
  def mark_damaged(%__MODULE__{} = manager, x, y, width, height) do
    %{
      manager
      | damage_tracker:
          DamageTracker.mark_damaged(
            manager.damage_tracker,
            x,
            y,
            width,
            height
          )
    }
  end

  @doc """
  Gets all damage regions for rendering optimization.
  """
  def get_damage_regions(%__MODULE__{} = manager) do
    DamageTracker.get_damage_regions(manager.damage_tracker)
  end

  @doc """
  Updates memory usage tracking.
  """
  def update_memory_usage(%__MODULE__{} = manager) do
    memory_usage = MemoryManager.get_usage(manager.memory_manager)
    %{manager | metrics: Map.put(manager.metrics, :memory_usage, memory_usage)}
  end

  @doc """
  Checks if the buffer is within memory limits.
  """
  def within_memory_limits?(%__MODULE__{} = manager) do
    current_usage = manager.metrics.memory_usage
    limit = MemoryManager.get_limit(manager.memory_manager)
    current_usage <= limit
  end

  # Server callbacks

  def handle_call({:initialize_buffers, width, height, _opts}, _from, state) do
    new_buffer = BufferImpl.new(width, height)
    new_state = %{state | buffer: new_buffer}
    {:reply, new_state, new_state}
  end

  def handle_call({:atomic_operation, operation}, _from, state) do
    # Acquire lock
    :ets.insert(state.lock, {:lock, self()})

    try do
      # Perform operation
      result = operation.(state)
      {:reply, {:ok, result}, result}
    catch
      kind, reason ->
        {:reply, {:error, {kind, reason}}, state}
    after
      # Release lock
      :ets.delete(state.lock, :lock)
    end
  end

  def handle_call({:write, data, opts}, _from, state) do
    try do
      new_buffer = Operations.write(state.buffer, data, opts)
      new_state = update_metrics(%{state | buffer: new_buffer}, :writes)
      {:reply, :ok, new_state}
    catch
      kind, reason ->
        {:reply, {:error, {kind, reason}}, state}
    end
  end

  def handle_call({:read, opts}, _from, state) do
    try do
      {data, new_buffer} = Operations.read(state.buffer, opts)
      new_state = update_metrics(%{state | buffer: new_buffer}, :reads)
      {:reply, data, new_state}
    catch
      kind, reason ->
        {:reply, {:error, {kind, reason}}, state}
    end
  end

  def handle_call({:resize, size, opts}, _from, state) do
    try do
      new_buffer = Operations.resize(state.buffer, size, opts)
      new_state = %{state | buffer: new_buffer}
      {:reply, :ok, new_state}
    catch
      kind, reason ->
        {:reply, {:error, {kind, reason}}, state}
    end
  end

  def handle_call({:scroll, lines}, _from, state) do
    new_buffer = Operations.scroll(state.buffer, lines)
    new_state = update_metrics(%{state | buffer: new_buffer}, :scrolls)
    {:reply, :ok, new_state}
  end

  def handle_call({:set_cell, x, y, cell}, _from, state) do
    new_buffer = BufferImpl.set_cell(state.buffer, x, y, cell)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call({:get_line, y}, _from, state) do
    line = BufferImpl.get_line(state.buffer, y)
    {:reply, line, state}
  end

  def handle_call({:set_line, y, line}, _from, state) do
    new_buffer = BufferImpl.set_line(state.buffer, y, line)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:clear, _from, state) do
    new_buffer = BufferImpl.clear(state.buffer)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_size, _from, state) do
    size = BufferImpl.get_size(state.buffer)
    {:reply, size, state}
  end

  def handle_call(:get_cursor, _from, state) do
    cursor = BufferImpl.get_cursor(state.buffer)
    {:reply, cursor, state}
  end

  def handle_call({:set_cursor, cursor}, _from, state) do
    new_buffer = BufferImpl.set_cursor(state.buffer, cursor)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_attributes, _from, state) do
    attributes = BufferImpl.get_attributes(state.buffer)
    {:reply, attributes, state}
  end

  def handle_call({:set_attributes, attributes}, _from, state) do
    new_buffer = BufferImpl.set_attributes(state.buffer, attributes)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_mode, _from, state) do
    mode = BufferImpl.get_mode(state.buffer)
    {:reply, mode, state}
  end

  def handle_call({:set_mode, mode}, _from, state) do
    new_buffer = BufferImpl.set_mode(state.buffer, mode)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_title, _from, state) do
    title = BufferImpl.get_title(state.buffer)
    {:reply, title, state}
  end

  def handle_call({:set_title, title}, _from, state) do
    new_buffer = BufferImpl.set_title(state.buffer, title)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_icon_name, _from, state) do
    icon_name = BufferImpl.get_icon_name(state.buffer)
    {:reply, icon_name, state}
  end

  def handle_call({:set_icon_name, icon_name}, _from, state) do
    new_buffer = BufferImpl.set_icon_name(state.buffer, icon_name)
    new_state = %{state | buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_icon_title, _from, state) do
    icon_title = BufferImpl.get_icon_title(state.buffer)
    {:reply, icon_title, state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call({:get, key, default}, _from, state) do
    value = Map.get(state, key, default)
    {:reply, value, state}
  end

  def handle_call({:get_cell, x, y}, _from, state) do
    cell = BufferImpl.get_cell(state.buffer, x, y)
    {:reply, cell, state}
  end

  def handle_call(:get_memory_usage, _from, state) do
    usage = MemoryManager.get_memory_usage(state.memory_manager)
    {:reply, usage, state}
  end

  def handle_call(:get_scrollback_count, _from, state) do
    count = ScrollbackManager.get_scrollback_count(state.scrollback_manager)
    {:reply, count, state}
  end

  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  # Private functions

  defp update_metrics(state, operation) do
    metrics = Map.update(state.metrics, operation, 1, &(&1 + 1))
    %{state | metrics: metrics}
  end

  @doc """
  Sets the active buffer.
  Returns the updated emulator.
  """
  @spec set_active_buffer(Emulator.t(), Buffer.t()) :: Emulator.t()
  def set_active_buffer(emulator, buffer) do
    %{emulator | buffer: %{emulator.buffer | active: buffer}}
  end

  @doc """
  Gets the alternate buffer.
  Returns the alternate buffer or nil.
  """
  @spec get_alternate_buffer(Emulator.t()) :: Buffer.t() | nil
  def get_alternate_buffer(emulator) do
    emulator.buffer.alternate
  end

  @doc """
  Sets the alternate buffer.
  Returns the updated emulator.
  """
  @spec set_alternate_buffer(Emulator.t(), Buffer.t()) :: Emulator.t()
  def set_alternate_buffer(emulator, buffer) do
    %{emulator | buffer: %{emulator.buffer | alternate: buffer}}
  end

  @doc """
  Switches between active and alternate buffers.
  Returns the updated emulator.
  """
  @spec switch_buffers(Emulator.t()) :: Emulator.t()
  def switch_buffers(emulator) do
    %{
      emulator
      | buffer: %{
          emulator.buffer
          | active: emulator.buffer.alternate,
            alternate: emulator.buffer.active
        }
    }
  end

  @doc """
  Gets the scrollback buffer.
  Returns the list of scrollback buffers.
  """
  @spec get_scrollback(Emulator.t()) :: [Buffer.t()]
  def get_scrollback(emulator) do
    emulator.buffer.scrollback
  end

  @doc """
  Adds a buffer to the scrollback.
  Returns the updated emulator.
  """
  @spec add_to_scrollback(Emulator.t(), Buffer.t()) :: Emulator.t()
  def add_to_scrollback(emulator, buffer) do
    scrollback = [buffer | emulator.buffer.scrollback]
    scrollback = Enum.take(scrollback, emulator.buffer.scrollback_size)
    %{emulator | buffer: %{emulator.buffer | scrollback: scrollback}}
  end

  @doc """
  Gets the scrollback size.
  Returns the maximum number of scrollback buffers.
  """
  @spec get_scrollback_size(Emulator.t()) :: non_neg_integer()
  def get_scrollback_size(emulator) do
    emulator.buffer.scrollback_size
  end

  @doc """
  Sets the scrollback size.
  Returns the updated emulator.
  """
  @spec set_scrollback_size(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def set_scrollback_size(emulator, size) when is_integer(size) and size >= 0 do
    scrollback = Enum.take(emulator.buffer.scrollback, size)

    %{
      emulator
      | buffer: %{
          emulator.buffer
          | scrollback: scrollback,
            scrollback_size: size
        }
    }
  end

  @doc """
  Clears the scrollback buffer.
  Returns the updated emulator.
  """
  @spec clear_scrollback(Emulator.t()) :: Emulator.t()
  def clear_scrollback(emulator) do
    %{emulator | buffer: %{emulator.buffer | scrollback: []}}
  end

  @doc """
  Resets the buffer manager to its initial state.
  Returns the updated emulator.
  """
  @spec reset_buffer_manager(Emulator.t()) :: Emulator.t()
  def reset_buffer_manager(emulator) do
    %{emulator | buffer: new()}
  end
end
