defmodule Raxol.Terminal.Buffer.Manager do
  @moduledoc """
  Manages terminal buffers including active buffer, alternate buffer, and scrollback.
  This module is responsible for buffer operations and state management.
  """

  use GenServer
  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Buffer.Manager.{
    BufferImpl,
    Behaviour,
    MemoryCalculator,
    ProcessManager
  }

  alias Raxol.Terminal.Buffer.{Operations, DamageTracker}
  alias Raxol.Terminal.MemoryManager
  alias Raxol.Terminal.Integration.Renderer
  alias Raxol.Core.ErrorHandling

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

  defmodule TestBufferManager do
    @moduledoc false

    defstruct active: nil, alternate: nil, scrollback: [], scrollback_size: 1000
  end

  # Client API

  def start_link(opts \\ []) do
    alias Raxol.Terminal.Buffer.GenServerHelpers
    GenServerHelpers.start_link_with_name_validation(__MODULE__, opts)
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

  def new(width, height, scrollback_height)
      when is_integer(scrollback_height) do
    new(width, height, scrollback_height: scrollback_height)
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
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, {:get_line, y})
  end

  def set_line(y, line) do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, {:set_line, y, line})
  end

  def clear do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, :clear)
  end

  def get_size do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, :get_size)
  end

  # Damage tracking functions
  # Only match on pid or atom for process-based API
  def mark_damaged(pid, x, y, width, height) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, {:mark_damaged, x, y, width, height})
  end

  @doc """
  Marks a region as damaged for rendering optimization.
  """
  def mark_damaged(%__MODULE__{} = manager, x, y, width, height) do
    # Convert width/height to end coordinates (inclusive) for test compatibility
    # Tests expect {x1, y1, x2, y2} where x2 and y2 are end coordinates
    x2 = x + width - 1
    y2 = y + height - 1

    damage_tracker =
      DamageTracker.add_damage_region(
        manager.damage_tracker,
        x,
        y,
        x2,
        y2
      )

    %{manager | damage_tracker: damage_tracker}
  end

  # Ensure all struct-based API functions handle nil gracefully
  def mark_damaged(nil, x, y, width, height),
    do: new() |> mark_damaged(x, y, width, height)

  def get_damage_regions(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :get_damage_regions)
  end

  @doc """
  Gets all damage regions for rendering optimization.
  """
  def get_damage_regions(%__MODULE__{} = manager) do
    DamageTracker.get_damage_regions(manager.damage_tracker)
  end

  def get_damage_regions(nil), do: []

  @impl Raxol.Terminal.Buffer.Manager.Behaviour
  def clear_damage(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :clear_damage)
  end

  def clear_damage(%__MODULE__{} = manager) do
    updated_damage_tracker = DamageTracker.clear_damage(manager.damage_tracker)
    %{manager | damage_tracker: updated_damage_tracker}
  end

  # Memory management functions
  # Only match on pid or atom for process-based API
  def update_memory_usage(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :update_memory_usage)
  end

  @doc """
  Updates memory usage tracking.
  """
  def update_memory_usage(%__MODULE__{} = manager) do
    # IO.puts("DEBUG: update_memory_usage called with %__MODULE__{} struct")
    # Calculate memory usage for both buffers
    active_memory =
      MemoryCalculator.calculate_buffer_memory(manager.active_buffer)

    back_memory = MemoryCalculator.calculate_buffer_memory(manager.back_buffer)
    total_memory = active_memory + back_memory

    # IO.puts(
    #   "DEBUG: update_memory_usage - active: #{active_memory}, back: #{back_memory}, total: #{total_memory}"
    # )

    # IO.puts("DEBUG: Before update - metrics: #{inspect(manager.metrics)}")

    metrics = Map.put(manager.metrics, :memory_usage, total_memory)
    updated_manager = %{manager | metrics: metrics}

    # IO.puts(
    #   "DEBUG: After update - metrics: #{inspect(updated_manager.metrics)}"
    # )

    updated_manager
  end

  def update_memory_usage(manager) do
    # IO.puts(
    #   "DEBUG: update_memory_usage called with other type: #{inspect(manager)}"
    # )

    manager
  end

  def within_memory_limits?(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :within_memory_limits)
  end

  @doc """
  Checks if the buffer is within memory limits.
  """
  def within_memory_limits?(%__MODULE__{} = manager) do
    current_usage = manager.metrics.memory_usage
    limit = manager.memory_limit
    current_usage <= limit
  end

  # Buffer access functions for tests
  # Only match on pid or atom for process-based API

  def get_back_buffer(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :get_back_buffer)
  end

  def get_screen_buffer(pid) when is_pid(pid) or is_atom(pid) do
    GenServer.call(pid, :get_screen_buffer)
  end

  def get_cursor do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, :get_cursor)
  end

  def set_cursor(cursor) do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, {:set_cursor, cursor})
  end

  def set_cursor(%__MODULE__{} = manager, {x, y})
      when is_integer(x) and is_integer(y) do
    %{manager | cursor_position: {x, y}}
  end

  def get_attributes do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, :get_attributes)
  end

  def set_attributes(attributes) do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, {:set_attributes, attributes})
  end

  def get_mode do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, :get_mode)
  end

  def set_mode(mode) do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, {:set_mode, mode})
  end

  def get_title do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, :get_title)
  end

  def set_title(title) do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, {:set_title, title})
  end

  def get_icon_name do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, :get_icon_name)
  end

  def set_icon_name(icon_name) do
    pid = ProcessManager.get_buffer_manager_pid()
    GenServer.call(pid, {:set_icon_name, icon_name})
  end

  def get_icon_title do
    pid = ProcessManager.get_buffer_manager_pid()
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

  def default_tab_stops(%__MODULE__{}) do
    {:ok, [8, 16, 24, 32, 40, 48, 56, 64, 72, 80]}
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

    result = safe_execute_operation(operation, state)
    
    # Release lock
    :ets.delete(state.lock, :lock)
    
    case result do
      {:ok, new_state} -> {:reply, {:ok, new_state}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp safe_execute_operation(operation, state) do
    ErrorHandling.safe_call(fn ->
      operation.(state)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, {:exit, reason}} -> {:error, {:exit, reason}}
      {:error, {:throw, reason}} -> {:error, {:throw, reason}}
      {:error, reason} -> {:error, {:exception, reason}}
    end
  end

  def handle_call({:write, data, opts}, _from, state) do
    with {:ok, new_buffer} <- safe_buffer_write(state.active_buffer, data, opts) do
      new_state = update_metrics(%{state | active_buffer: new_buffer}, :writes)
      {:reply, :ok, new_state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp safe_buffer_write(buffer, data, opts) do
    ErrorHandling.safe_call(fn ->
      Operations.write(buffer, data, opts)
    end)
    |> case do
      {:ok, new_buffer} -> {:ok, new_buffer}
      {:error, {:exit, reason}} -> {:error, {:exit, reason}}
      {:error, {:throw, reason}} -> {:error, {:throw, reason}}
      {:error, reason} -> {:error, {:write_exception, reason}}
    end
  end

  def handle_call({:read, opts}, _from, state) do
    with {:ok, {data, new_buffer}} <- safe_buffer_read(state.active_buffer, opts) do
      new_state = update_metrics(%{state | active_buffer: new_buffer}, :reads)
      {:reply, data, new_state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp safe_buffer_read(buffer, opts) do
    ErrorHandling.safe_call(fn ->
      Operations.read(buffer, opts)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, {:exit, reason}} -> {:error, {:exit, reason}}
      {:error, {:throw, reason}} -> {:error, {:throw, reason}}
      {:error, reason} -> {:error, {:read_exception, reason}}
    end
  end

  def handle_call({:resize, size, _opts}, _from, state) do
    with {:ok, {width, height}} <- validate_resize_size(size),
         {:ok, new_buffer} <- safe_buffer_resize(state.active_buffer, width, height),
         {:ok, new_back_buffer} <- safe_buffer_resize(state.back_buffer, width, height) do
      new_state = %{
        state
        | active_buffer: new_buffer,
          back_buffer: new_back_buffer
      }
      {:reply, :ok, new_state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp validate_resize_size(size) do
    case size do
      {width, height} when is_integer(width) and is_integer(height) and width > 0 and height > 0 ->
        {:ok, {width, height}}
      _ ->
        {:error, :invalid_size}
    end
  end

  defp safe_buffer_resize(buffer, width, height) do
    ErrorHandling.safe_call(fn ->
      BufferImpl.resize(buffer, width, height)
    end)
    |> case do
      {:ok, new_buffer} -> {:ok, new_buffer}
      {:error, {:exit, reason}} -> {:error, {:exit, reason}}
      {:error, {:throw, reason}} -> {:error, {:throw, reason}}
      {:error, reason} -> {:error, {:resize_exception, reason}}
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
      DamageTracker.add_damage_region(state.damage_tracker, x, y, width, height)

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

  def handle_call(:get_screen_buffer, _from, state) do
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
end
