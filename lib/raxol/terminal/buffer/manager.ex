defmodule Raxol.Terminal.Buffer.Manager do
  @moduledoc """
  Manages terminal buffers including active buffer, alternate buffer, and scrollback.
  This module is responsible for buffer operations and state management.
  """

  use GenServer
  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Buffer.Manager.{BufferImpl, Behaviour}
  alias Raxol.Terminal.Buffer.{Operations, DamageTracker, ScrollbackManager}
  alias Raxol.Terminal.{ScreenBuffer, Emulator, Buffer}
  alias Raxol.Terminal.MemoryManager
  alias Raxol.Terminal.Integration.Renderer

  @behaviour Behaviour

  defstruct [
    :active_buffer,
    :back_buffer,
    :damage_tracker,
    :memory_manager,
    :metrics,
    :renderer,
    :scrollback,
    :cursor_position,
    :lock,
    :memory_limit
  ]

  @type t :: %__MODULE__{
          active_buffer: BufferImpl.t(),
          back_buffer: BufferImpl.t(),
          damage_tracker: term(),
          memory_manager: term(),
          metrics: term(),
          renderer: term(),
          scrollback: term(),
          cursor_position: {non_neg_integer(), non_neg_integer()} | nil,
          lock: :ets.tid(),
          memory_limit: non_neg_integer()
        }

  # Test struct for buffer manager API compatibility
  defmodule TestBufferManager do
    defstruct active: nil, alternate: nil, scrollback: [], scrollback_size: 1000
  end

  # Client API

  def start_link(opts \\ []) do
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
  Creates a new buffer manager with default dimensions.
  """
  def new do
    %TestBufferManager{}
  end

  @doc """
  Creates a new buffer manager with specified width and height.
  """
  def new(width, height) do
    {:ok, pid} = start_link(width: width, height: height)
    state = GenServer.call(pid, :get_state)
    {:ok, state}
  end

  @doc """
  Creates a new buffer manager with specified width, height, and options.
  """
  def new(width, height, opts) when is_list(opts) do
    {:ok, pid} = start_link([width: width, height: height] ++ opts)
    state = GenServer.call(pid, :get_state)
    {:ok, state}
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

    state = GenServer.call(pid, :get_state)
    {:ok, state}
  end

  @doc """
  Creates a new buffer manager with specified width, height, scrollback height.
  """
  def new(width, height, scrollback_height)
      when is_integer(scrollback_height) do
    new(width, height, scrollback_height: scrollback_height)
  end

  @impl GenServer
  def init(opts) do
    memory_manager =
      case MemoryManager.start_link() do
        {:ok, pid} ->
          pid

        {:error, {:already_started, pid}} ->
          pid

        {:error, reason} ->
          raise "Failed to start MemoryManager: #{inspect(reason)}"
      end

    lock = :ets.new(:buffer_lock, [:set, :private])

    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    scrollback_height = Keyword.get(opts, :scrollback_height, 1000)
    memory_limit = Keyword.get(opts, :memory_limit, 1_000_000)

    buffer = BufferImpl.new(width, height)

    state = %__MODULE__{
      active_buffer: buffer,
      back_buffer: buffer,
      memory_manager: memory_manager,
      damage_tracker: DamageTracker.new(),
      scrollback: %{limit: scrollback_height, buffers: []},
      renderer: Renderer.new(width: width, height: height),
      metrics: %{
        writes: 0,
        reads: 0,
        scrolls: 0,
        memory_usage: 0,
        memory_limit: memory_limit
      },
      lock: lock,
      memory_limit: memory_limit
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
  def initialize_buffers(pid, width, height, opts \\ []) do
    GenServer.call(pid, {:initialize_buffers, width, height, opts})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def write(pid, data, opts \\ []) do
    GenServer.call(pid, {:write, data, opts})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def read(pid, opts \\ []) do
    GenServer.call(pid, {:read, opts})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def resize(pid, size, opts \\ []) do
    GenServer.call(pid, {:resize, size, opts})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def scroll(pid, lines) do
    GenServer.call(pid, {:scroll, lines})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def set_cell(pid, x, y, cell) do
    GenServer.call(pid, {:set_cell, x, y, cell})
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def get_cell(pid, x, y) do
    GenServer.call(pid, {:get_cell, x, y})
  end

  def get_line(y) do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, {:get_line, y})
  end

  def set_line(y, line) do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, {:set_line, y, line})
  end

  def clear do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, :clear)
  end

  def get_size do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, :get_size)
  end

  # Damage tracking functions
  # Only match on pid or atom for process-based API
  def mark_damaged(pid, x, y, width, height) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, {:mark_damaged, x, y, width, height})
  end

  def get_damage_regions(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :get_damage_regions)
  end

  def clear_damage(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :clear_damage)
  end

  # Memory management functions
  # Only match on pid or atom for process-based API
  def update_memory_usage(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :update_memory_usage)
  end

  def within_memory_limits?(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :within_memory_limits)
  end

  # Buffer access functions for tests
  # Only match on pid or atom for process-based API
  def get_active_buffer(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :get_active_buffer)
  end

  def get_back_buffer(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :get_back_buffer)
  end

  # Struct-based versions
  # Already present below, but ensure they are not shadowed
  def get_active_buffer(%__MODULE__{} = state) do
    {:ok, state.active_buffer}
  end

  def get_back_buffer(%__MODULE__{} = state) do
    {:ok, state.back_buffer}
  end

  def get_active_buffer(emulator) when is_map(emulator) do
    Map.get(emulator, :active, nil)
  end

  def get_cursor do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, :get_cursor)
  end

  def set_cursor(cursor) do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, {:set_cursor, cursor})
  end

  def set_cursor(%__MODULE__{} = manager, {x, y})
      when is_integer(x) and is_integer(y) do
    %{manager | cursor_position: {x, y}}
  end

  def get_attributes do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, :get_attributes)
  end

  def set_attributes(attributes) do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, {:set_attributes, attributes})
  end

  def get_mode do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, :get_mode)
  end

  def set_mode(mode) do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, {:set_mode, mode})
  end

  def get_title do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, :get_title)
  end

  def set_title(title) do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, {:set_title, title})
  end

  def get_icon_name do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, :get_icon_name)
  end

  def set_icon_name(icon_name) do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, {:set_icon_name, icon_name})
  end

  def get_icon_title do
    pid = get_buffer_manager_pid()
    GenServer.call(pid, :get_icon_title)
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def get_memory_usage(pid) do
    GenServer.call(pid, :get_memory_usage)
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def get_scrollback_count(pid) do
    GenServer.call(pid, :get_scrollback_count)
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def get_metrics(pid) do
    GenServer.call(pid, :get_metrics)
  end

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def clear_damage(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :clear_damage)
  end

  def get_active_buffer(%__MODULE__{} = state) do
    {:ok, state.active_buffer}
  end

  def default_tab_stops(%__MODULE__{}) do
    {:ok, [8, 16, 24, 32, 40, 48, 56, 64, 72, 80]}
  end

  @doc """
  Marks a region as damaged for rendering optimization.
  """
  def mark_damaged(%__MODULE__{} = manager, x, y, width, height) do
    # Convert width/height to end coordinates (inclusive)
    # DamageTracker expects {x1, y1, x2, y2} where x2 and y2 are end coordinates
    x2 = x + width - 1
    y2 = y + height - 1

    damage_tracker =
      DamageTracker.mark_damaged(manager.damage_tracker, x, y, x2, y2)

    %{manager | damage_tracker: damage_tracker}
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
    IO.puts("DEBUG: update_memory_usage called with %__MODULE__{} struct")
    # Calculate memory usage for both buffers
    active_memory = calculate_buffer_memory(manager.active_buffer)
    back_memory = calculate_buffer_memory(manager.back_buffer)
    total_memory = active_memory + back_memory

    IO.puts(
      "DEBUG: update_memory_usage - active: #{active_memory}, back: #{back_memory}, total: #{total_memory}"
    )

    IO.puts("DEBUG: Before update - metrics: #{inspect(manager.metrics)}")

    metrics = Map.put(manager.metrics, :memory_usage, total_memory)
    updated_manager = %{manager | metrics: metrics}

    IO.puts(
      "DEBUG: After update - metrics: #{inspect(updated_manager.metrics)}"
    )

    updated_manager
  end

  def update_memory_usage(manager) do
    IO.puts(
      "DEBUG: update_memory_usage called with other type: #{inspect(manager)}"
    )

    manager
  end

  @doc """
  Checks if the buffer is within memory limits.
  """
  def within_memory_limits?(%__MODULE__{} = manager) do
    current_usage = manager.metrics.memory_usage
    limit = manager.memory_limit
    current_usage <= limit
  end

  # Server callbacks

  def handle_call({:initialize_buffers, width, height, _opts}, _from, state) do
    new_buffer = BufferImpl.new(width, height)
    new_state = %{state | active_buffer: new_buffer, back_buffer: new_buffer}
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
      new_buffer = Operations.write(state.active_buffer, data, opts)
      new_state = update_metrics(%{state | active_buffer: new_buffer}, :writes)
      {:reply, :ok, new_state}
    catch
      kind, reason ->
        {:reply, {:error, {kind, reason}}, state}
    end
  end

  def handle_call({:read, opts}, _from, state) do
    try do
      {data, new_buffer} = Operations.read(state.active_buffer, opts)
      new_state = update_metrics(%{state | active_buffer: new_buffer}, :reads)
      {:reply, data, new_state}
    catch
      kind, reason ->
        {:reply, {:error, {kind, reason}}, state}
    end
  end

  def handle_call({:resize, size, opts}, _from, state) do
    try do
      new_buffer = Operations.resize(state.active_buffer, size, opts)
      new_state = %{state | active_buffer: new_buffer}
      {:reply, :ok, new_state}
    catch
      kind, reason ->
        {:reply, {:error, {kind, reason}}, state}
    end
  end

  def handle_call({:scroll, lines}, _from, state) do
    new_buffer = Operations.scroll(state.active_buffer, lines)
    new_state = update_metrics(%{state | active_buffer: new_buffer}, :scrolls)
    {:reply, :ok, new_state}
  end

  def handle_call({:set_cell, x, y, cell}, _from, state) do
    new_buffer = BufferImpl.set_cell(state.active_buffer, x, y, cell)
    new_state = %{state | active_buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call({:get_line, y}, _from, state) do
    line = BufferImpl.get_line(state.active_buffer, y)
    {:reply, line, state}
  end

  def handle_call({:set_line, y, line}, _from, state) do
    new_buffer = BufferImpl.set_line(state.active_buffer, y, line)
    new_state = %{state | active_buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:clear, _from, state) do
    new_buffer = BufferImpl.clear(state.active_buffer)
    new_state = %{state | active_buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_size, _from, state) do
    size = BufferImpl.get_size(state.active_buffer)
    {:reply, size, state}
  end

  def handle_call(:get_cursor, _from, state) do
    cursor = BufferImpl.get_cursor(state.active_buffer)
    {:reply, cursor, state}
  end

  def handle_call({:set_cursor, cursor}, _from, state) do
    new_buffer = BufferImpl.set_cursor(state.active_buffer, cursor)
    new_state = %{state | active_buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_attributes, _from, state) do
    attributes = BufferImpl.get_attributes(state.active_buffer)
    {:reply, attributes, state}
  end

  def handle_call({:set_attributes, attributes}, _from, state) do
    new_buffer = BufferImpl.set_attributes(state.active_buffer, attributes)
    new_state = %{state | active_buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_mode, _from, state) do
    mode = BufferImpl.get_mode(state.active_buffer)
    {:reply, mode, state}
  end

  def handle_call({:set_mode, mode}, _from, state) do
    new_buffer = BufferImpl.set_mode(state.active_buffer, mode)
    new_state = %{state | active_buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_title, _from, state) do
    title = BufferImpl.get_title(state.active_buffer)
    {:reply, title, state}
  end

  def handle_call({:set_title, title}, _from, state) do
    new_buffer = BufferImpl.set_title(state.active_buffer, title)
    new_state = %{state | active_buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_icon_name, _from, state) do
    icon_name = BufferImpl.get_icon_name(state.active_buffer)
    {:reply, icon_name, state}
  end

  def handle_call({:set_icon_name, icon_name}, _from, state) do
    new_buffer = BufferImpl.set_icon_name(state.active_buffer, icon_name)
    new_state = %{state | active_buffer: new_buffer}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_icon_title, _from, state) do
    icon_title = BufferImpl.get_icon_title(state.active_buffer)
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
    cell = BufferImpl.get_cell(state.active_buffer, x, y)
    {:reply, cell, state}
  end

  def handle_call(:get_memory_usage, _from, state) do
    usage = MemoryManager.get_memory_usage(state.memory_manager)
    {:reply, usage, state}
  end

  def handle_call(:get_scrollback_count, _from, state) do
    count = length(state.scrollback.buffers)
    {:reply, count, state}
  end

  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  def handle_call(:clear_damage, _from, state) do
    new_damage_tracker = DamageTracker.clear_damage(state.damage_tracker)
    new_state = %{state | damage_tracker: new_damage_tracker}
    {:reply, :ok, new_state}
  end

  def handle_call(:clear_scrollback, _from, state) do
    new_state = %{state | scrollback: %{state.scrollback | buffers: []}}
    {:reply, new_state, new_state}
  end

  def handle_call({:mark_damaged, x, y, width, height}, _from, state) do
    new_damage_tracker =
      DamageTracker.mark_damaged(state.damage_tracker, x, y, width, height)

    new_state = %{state | damage_tracker: new_damage_tracker}
    {:reply, new_state, new_state}
  end

  def handle_call(:get_damage_regions, _from, state) do
    regions = DamageTracker.get_damage_regions(state.damage_tracker)
    {:reply, regions, state}
  end

  def handle_call(:update_memory_usage, _from, state) do
    usage = MemoryManager.get_memory_usage(state.memory_manager)
    new_state = %{state | metrics: Map.put(state.metrics, :memory_usage, usage)}
    {:reply, new_state, new_state}
  end

  def handle_call(:within_memory_limits, _from, state) do
    usage = MemoryManager.get_memory_usage(state.memory_manager)
    # Default 1MB
    limit = Map.get(state.metrics, :memory_limit, 1_000_000)
    {:reply, usage <= limit, state}
  end

  def handle_call(:get_active_buffer, _from, state) do
    {:reply, state.active_buffer, state}
  end

  def handle_call(:get_back_buffer, _from, state) do
    # For now, return the same buffer as active (no back buffer implementation yet)
    {:reply, state.back_buffer, state}
  end

  # Private functions

  defp update_metrics(state, operation) do
    metrics = Map.update(state.metrics, operation, 1, &(&1 + 1))
    %{state | metrics: metrics}
  end

  # Struct-based set_active_buffer/2
  @doc """
  Sets the active buffer on the struct or emulator.
  """
  def set_active_buffer(nil, buffer), do: new() |> set_active_buffer(buffer)

  def set_active_buffer(%__MODULE__{} = manager, buffer) do
    %{manager | active_buffer: buffer}
  end

  def set_active_buffer(%{active: _} = emulator, buffer) do
    %{emulator | active: buffer}
  end

  def set_active_buffer(emulator, buffer) when is_map(emulator) do
    Map.put(emulator, :active, buffer)
  end

  # Struct-based set_alternate_buffer/2
  def set_alternate_buffer(nil, buffer),
    do: new() |> set_alternate_buffer(buffer)

  def set_alternate_buffer(%__MODULE__{} = manager, buffer) do
    %{manager | back_buffer: buffer}
  end

  def set_alternate_buffer(%{alternate: _} = emulator, buffer) do
    %{emulator | alternate: buffer}
  end

  def set_alternate_buffer(emulator, buffer) when is_map(emulator) do
    Map.put(emulator, :alternate, buffer)
  end

  # Struct-based reset_buffer_manager/1
  def reset_buffer_manager(%{buffer: _} = emulator) do
    %{emulator | buffer: new()}
  end

  def reset_buffer_manager(%{active: _} = emulator) do
    %{
      emulator
      | active: nil,
        alternate: nil,
        scrollback: [],
        scrollback_size: 1000
    }
  end

  def reset_buffer_manager(emulator) when is_map(emulator) do
    emulator
    |> Map.put(:active, nil)
    |> Map.put(:alternate, nil)
    |> Map.put(:scrollback, [])
    |> Map.put(:scrollback_size, 1000)
  end

  def reset_buffer_manager(_manager) do
    new()
  end

  # Ensure all struct-based API functions handle nil gracefully
  def mark_damaged(nil, x, y, width, height),
    do: new() |> mark_damaged(x, y, width, height)

  def get_damage_regions(nil), do: []

  def add_to_scrollback(nil, buffer),
    do: %{scrollback: [buffer], scrollback_size: 1000}

  def add_to_scrollback(
        %{scrollback: scrollback, scrollback_size: scrollback_size} = emulator,
        buffer
      ) do
    new_scrollback = [buffer | scrollback] |> Enum.take(scrollback_size)
    %{emulator | scrollback: new_scrollback}
  end

  def add_to_scrollback(emulator, buffer) when is_map(emulator) do
    scrollback = Map.get(emulator, :scrollback, [])
    scrollback_size = Map.get(emulator, :scrollback_size, 1000)
    new_scrollback = [buffer | scrollback] |> Enum.take(scrollback_size)

    Map.put(emulator, :scrollback, new_scrollback)
    |> Map.put(:scrollback_size, scrollback_size)
  end

  def get_scrollback(nil), do: []
  def get_scrollback(%{scrollback: scrollback}), do: scrollback

  def get_scrollback(emulator) when is_map(emulator) do
    Map.get(emulator, :scrollback, [])
  end

  def set_scrollback_size(nil, size) when is_integer(size) and size >= 0,
    do: %{scrollback: [], scrollback_size: size}

  def set_scrollback_size(%{scrollback: scrollback} = emulator, size)
      when is_integer(size) and size >= 0 do
    new_scrollback = Enum.take(scrollback, size)
    %{emulator | scrollback: new_scrollback, scrollback_size: size}
  end

  def set_scrollback_size(emulator, size)
      when is_map(emulator) and is_integer(size) and size >= 0 do
    scrollback = Map.get(emulator, :scrollback, []) |> Enum.take(size)

    Map.put(emulator, :scrollback, scrollback)
    |> Map.put(:scrollback_size, size)
  end

  def get_scrollback_size(nil), do: 1000
  def get_scrollback_size(%{scrollback_size: size}), do: size

  def get_scrollback_size(emulator) when is_map(emulator) do
    Map.get(emulator, :scrollback_size, 1000)
  end

  def clear_scrollback(nil), do: %{scrollback: []}

  def clear_scrollback(%{scrollback: _} = emulator),
    do: %{emulator | scrollback: []}

  def clear_scrollback(emulator) when is_map(emulator) do
    Map.put(emulator, :scrollback, [])
  end

  def reset_buffer_manager(emulator) when is_map(emulator) do
    IO.puts("DEBUG: reset_buffer_manager called with: #{inspect(emulator)}")

    updated =
      emulator
      |> Map.put(:active, nil)
      |> Map.put(:alternate, nil)
      |> Map.put(:scrollback, [])
      |> Map.put(:scrollback_size, 1000)

    IO.puts("DEBUG: reset_buffer_manager result: #{inspect(updated)}")
    updated
  end

  # Emulator-based get_active_buffer/1 and get_alternate_buffer/1
  def get_active_buffer(%{active: active}), do: active
  def get_alternate_buffer(%{alternate: alternate}), do: alternate

  def get_alternate_buffer(%__MODULE__{} = state) do
    {:ok, state.alternate_buffer}
  end

  def get_alternate_buffer(emulator) when is_map(emulator) do
    Map.get(emulator, :alternate, nil)
  end

  # Swaps the active and alternate buffers for emulator structs.
  def switch_buffers(%{active: active, alternate: alternate} = emulator) do
    %{emulator | active: alternate, alternate: active}
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
    if is_pid(emulator.buffer) do
      # If buffer is a PID, call the GenServer
      GenServer.call(emulator.buffer, :clear_scrollback)
    else
      # If buffer is a map (for backward compatibility)
      %{emulator | buffer: %{emulator.buffer | scrollback: []}}
    end
  end

  @doc """
  Resets the buffer manager to its initial state.
  Returns the updated emulator.
  """
  @spec reset_buffer_manager(Emulator.t()) :: Emulator.t()
  def reset_buffer_manager(emulator) do
    %{emulator | buffer: new()}
  end

  # Emulator/struct-based scrollback functions
  def add_to_scrollback(%Raxol.Terminal.Emulator{} = emulator, buffer) do
    scrollback = Map.get(emulator, :scrollback_buffer, [])
    scrollback_size = Map.get(emulator, :scrollback_limit, 1000)
    new_scrollback = [buffer | scrollback] |> Enum.take(scrollback_size)

    %{
      emulator
      | scrollback_buffer: new_scrollback,
        scrollback_limit: scrollback_size
    }
  end

  def add_to_scrollback(emulator, buffer) when is_map(emulator) do
    scrollback = Map.get(emulator, :scrollback, [])
    scrollback_size = Map.get(emulator, :scrollback_size, 1000)
    new_scrollback = [buffer | scrollback] |> Enum.take(scrollback_size)
    %{emulator | scrollback: new_scrollback, scrollback_size: scrollback_size}
  end

  def get_scrollback(%Raxol.Terminal.Emulator{} = emulator),
    do: Map.get(emulator, :scrollback_buffer, [])

  def get_scrollback(emulator) when is_map(emulator),
    do: Map.get(emulator, :scrollback, [])

  def set_scrollback_size(%Raxol.Terminal.Emulator{} = emulator, size)
      when is_integer(size) and size >= 0 do
    scrollback = Map.get(emulator, :scrollback_buffer, []) |> Enum.take(size)
    %{emulator | scrollback_buffer: scrollback, scrollback_limit: size}
  end

  def set_scrollback_size(emulator, size)
      when is_map(emulator) and is_integer(size) and size >= 0 do
    scrollback = Map.get(emulator, :scrollback, []) |> Enum.take(size)
    %{emulator | scrollback: scrollback, scrollback_size: size}
  end

  def get_scrollback_size(%Raxol.Terminal.Emulator{} = emulator),
    do: Map.get(emulator, :scrollback_limit, 1000)

  def get_scrollback_size(emulator) when is_map(emulator),
    do: Map.get(emulator, :scrollback_size, 1000)

  def clear_scrollback(%Raxol.Terminal.Emulator{} = emulator),
    do: %{emulator | scrollback_buffer: []}

  def clear_scrollback(emulator) when is_map(emulator),
    do: %{emulator | scrollback: []}

  def reset_buffer_manager(emulator) when is_map(emulator) do
    IO.puts("DEBUG: reset_buffer_manager called with: #{inspect(emulator)}")

    updated = %{
      emulator
      | active: nil,
        alternate: nil,
        scrollback: [],
        scrollback_size: 1000
    }

    IO.puts("DEBUG: reset_buffer_manager result: #{inspect(updated)}")
    updated
  end

  # Helper function to get the buffer manager PID
  defp get_buffer_manager_pid do
    if Mix.env() == :test do
      find_buffer_manager_in_test()
    else
      __MODULE__
    end
  end

  defp find_buffer_manager_in_test do
    case GenServer.whereis(__MODULE__) do
      nil -> find_buffer_manager_by_initial_call()
      pid -> pid
    end
  end

  defp find_buffer_manager_by_initial_call do
    case Process.list() |> Enum.find(&is_buffer_manager_process?/1) do
      nil -> raise "No buffer manager process found in test environment"
      pid -> pid
    end
  end

  defp is_buffer_manager_process?(pid) do
    case Process.info(pid, :initial_call) do
      {:initial_call, {__MODULE__, :init, 1}} -> true
      _ -> false
    end
  end

  # new/0 for test struct
  def new() do
    %TestBufferManager{}
  end

  # Struct-based API for test struct
  def get_active_buffer(%TestBufferManager{active: active}), do: active

  def get_alternate_buffer(%TestBufferManager{alternate: alternate}),
    do: alternate

  def set_active_buffer(%TestBufferManager{} = mgr, buffer),
    do: %{mgr | active: buffer}

  def set_alternate_buffer(%TestBufferManager{} = mgr, buffer),
    do: %{mgr | alternate: buffer}

  def switch_buffers(%TestBufferManager{active: a, alternate: b} = mgr),
    do: %{mgr | active: b, alternate: a}

  def add_to_scrollback(
        %TestBufferManager{scrollback: sb, scrollback_size: sz} = mgr,
        buffer
      ) do
    %{mgr | scrollback: [buffer | sb] |> Enum.take(sz)}
  end

  def get_scrollback(%TestBufferManager{scrollback: sb}), do: sb

  def set_scrollback_size(%TestBufferManager{scrollback: sb} = mgr, size)
      when is_integer(size) and size >= 0 do
    %{mgr | scrollback: Enum.take(sb, size), scrollback_size: size}
  end

  def get_scrollback_size(%TestBufferManager{scrollback_size: sz}), do: sz
  def clear_scrollback(%TestBufferManager{} = mgr), do: %{mgr | scrollback: []}

  def reset_buffer_manager(%TestBufferManager{} = mgr),
    do: %TestBufferManager{
      scrollback_size: mgr.scrollback_size,
      active: nil,
      alternate: nil,
      scrollback: []
    }

  # Struct-based damage tracking functions

  def get_damage_regions(%__MODULE__{} = manager) do
    DamageTracker.get_regions(manager.damage_tracker)
  end

  def clear_damage(%__MODULE__{} = manager) do
    damage_tracker = DamageTracker.clear_regions(manager.damage_tracker)
    %{manager | damage_tracker: damage_tracker}
  end

  defp calculate_buffer_memory(buffer) do
    # Simple memory calculation based on buffer size
    # For BufferImpl, calculate based on cells map size or list size
    case buffer do
      %Raxol.Terminal.Buffer.Manager.BufferImpl{} ->
        # Calculate memory based on cells storage type
        case buffer.cells do
          cells when is_map(cells) ->
            # Map-based storage
            # Estimate 64 bytes per cell
            memory = map_size(cells) * 64

            IO.puts(
              "DEBUG: Map-based cells, size: #{map_size(cells)}, memory: #{memory}"
            )

            memory

          cells when is_list(cells) ->
            # List-based storage (2D array)
            total_cells =
              Enum.reduce(cells, 0, fn row, acc -> acc + length(row) end)

            # Estimate 64 bytes per cell
            memory = total_cells * 64

            IO.puts(
              "DEBUG: List-based cells, total_cells: #{total_cells}, memory: #{memory}"
            )

            memory

          _ ->
            # Fallback to width * height
            # 8 bytes per cell estimate
            memory = buffer.width * buffer.height * 8

            IO.puts(
              "DEBUG: Fallback calculation, width: #{buffer.width}, height: #{buffer.height}, memory: #{memory}"
            )

            memory
        end

      _ ->
        # Fallback for other buffer types
        # 8 bytes per cell estimate
        memory = buffer.width * buffer.height * 8

        IO.puts(
          "DEBUG: Other buffer type, width: #{buffer.width}, height: #{buffer.height}, memory: #{memory}"
        )

        memory
    end
  end

  # Fix reset_buffer_manager to properly reset active and alternate buffers
  def reset_buffer_manager(%TestBufferManager{} = mgr),
    do: %TestBufferManager{
      scrollback_size: mgr.scrollback_size,
      active: nil,
      alternate: nil,
      scrollback: []
    }

  def reset_buffer_manager(emulator) when is_map(emulator) do
    %{
      emulator
      | active: nil,
        alternate: nil,
        scrollback: [],
        scrollback_size: 1000
    }
  end
end
