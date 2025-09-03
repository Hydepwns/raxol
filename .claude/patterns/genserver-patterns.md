# GenServer Design Patterns

## Basic GenServer Structure

### Standard Template
```elixir
defmodule Raxol.MyServer do
  use GenServer
  require Logger
  
  # Type definitions
  @type state :: %{
    data: map(),
    config: keyword(),
    stats: map()
  }
  
  @type option :: 
    {:name, atom()} |
    {:timeout, timeout()} |
    {:config, keyword()}
  
  # Client API
  
  @doc """
  Starts the GenServer with the given options.
  """
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Synchronous call example.
  """
  @spec get_data(GenServer.server()) :: map()
  def get_data(server \\ __MODULE__) do
    GenServer.call(server, :get_data)
  end
  
  @doc """
  Asynchronous cast example.
  """
  @spec update_data(GenServer.server(), map()) :: :ok
  def update_data(server \\ __MODULE__, data) do
    GenServer.cast(server, {:update_data, data})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    # Trap exits if managing other processes
    Process.flag(:trap_exit, true)
    
    state = %{
      data: %{},
      config: Keyword.get(opts, :config, []),
      stats: %{started_at: System.monotonic_time()}
    }
    
    # Continue with async initialization
    {:ok, state, {:continue, :after_init}}
  end
  
  @impl true
  def handle_continue(:after_init, state) do
    # Perform initialization that shouldn't block init/1
    schedule_periodic_work()
    {:noreply, state}
  end
  
  @impl true
  def handle_call(:get_data, _from, state) do
    {:reply, state.data, state}
  end
  
  @impl true
  def handle_cast({:update_data, data}, state) do
    new_state = %{state | data: data}
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:periodic_work, state) do
    # Handle periodic tasks
    perform_periodic_work(state)
    schedule_periodic_work()
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    Logger.warn("Process #{inspect(pid)} exited: #{inspect(reason)}")
    {:noreply, handle_process_exit(pid, state)}
  end
  
  @impl true
  def terminate(reason, state) do
    # Cleanup
    Logger.info("Terminating: #{inspect(reason)}")
    cleanup(state)
  end
  
  # Private Functions
  
  defp schedule_periodic_work do
    Process.send_after(self(), :periodic_work, :timer.seconds(30))
  end
  
  defp perform_periodic_work(state) do
    # Implementation
  end
  
  defp handle_process_exit(pid, state) do
    # Handle linked process termination
    state
  end
  
  defp cleanup(state) do
    # Cleanup resources
    :ok
  end
end
```

## State Management Patterns

### Complex State with Struct
```elixir
defmodule Raxol.BufferServer do
  use GenServer
  
  defmodule State do
    @enforce_keys [:width, :height]
    defstruct [
      :width,
      :height,
      :buffer,
      :cursor,
      dirty_regions: [],
      mode: :normal,
      metadata: %{}
    ]
    
    @type t :: %__MODULE__{
      width: pos_integer(),
      height: pos_integer(),
      buffer: term(),
      cursor: {non_neg_integer(), non_neg_integer()},
      dirty_regions: [term()],
      mode: atom(),
      metadata: map()
    }
    
    def new(width, height) do
      %__MODULE__{
        width: width,
        height: height,
        buffer: create_buffer(width, height),
        cursor: {0, 0}
      }
    end
    
    defp create_buffer(width, height) do
      # Buffer initialization
    end
  end
  
  @impl true
  def init(opts) do
    width = Keyword.fetch!(opts, :width)
    height = Keyword.fetch!(opts, :height)
    
    state = State.new(width, height)
    {:ok, state}
  end
end
```

### State Versioning for Hot Code Upgrades
```elixir
defmodule Raxol.StatefulServer do
  use GenServer
  
  @vsn "2.0.0"
  
  defmodule StateV1 do
    defstruct [:data, :config]
  end
  
  defmodule StateV2 do
    defstruct [:data, :config, :metadata, version: 2]
  end
  
  @impl true
  def code_change("1.0.0", %StateV1{} = old_state, _extra) do
    # Migrate from V1 to V2
    new_state = %StateV2{
      data: old_state.data,
      config: old_state.config,
      metadata: %{},
      version: 2
    }
    {:ok, new_state}
  end
  
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end
end
```

## Call/Cast/Info Patterns

### Timeout Handling
```elixir
defmodule Raxol.TimeoutServer do
  use GenServer
  
  def slow_operation(server, data) do
    timeout = :timer.seconds(5)
    
    try do
      GenServer.call(server, {:slow_op, data}, timeout)
    catch
      :exit, {:timeout, _} ->
        {:error, :timeout}
    end
  end
  
  @impl true
  def handle_call({:slow_op, data}, from, state) do
    # Spawn task for long operation
    task = Task.async(fn ->
      perform_slow_operation(data)
    end)
    
    # Store the from reference
    new_state = Map.put(state, :pending_calls, [{task.ref, from}])
    
    # Don't reply immediately
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({ref, result}, state) when is_reference(ref) do
    # Task completed
    case List.keytake(state.pending_calls, ref, 0) do
      {{^ref, from}, rest} ->
        GenServer.reply(from, result)
        Process.demonitor(ref, [:flush])
        {:noreply, %{state | pending_calls: rest}}
      
      nil ->
        {:noreply, state}
    end
  end
  
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    # Task failed
    case List.keytake(state.pending_calls, ref, 0) do
      {{^ref, from}, rest} ->
        GenServer.reply(from, {:error, reason})
        {:noreply, %{state | pending_calls: rest}}
      
      nil ->
        {:noreply, state}
    end
  end
end
```

### Batching Operations
```elixir
defmodule Raxol.BatchProcessor do
  use GenServer
  
  @batch_size 100
  @batch_timeout 1000
  
  defmodule State do
    defstruct [
      batch: [],
      batch_timer: nil,
      processor: nil
    ]
  end
  
  def add_item(server, item) do
    GenServer.cast(server, {:add_item, item})
  end
  
  @impl true
  def handle_cast({:add_item, item}, state) do
    new_batch = [item | state.batch]
    
    cond do
      length(new_batch) >= @batch_size ->
        # Batch is full, process immediately
        process_batch(new_batch)
        cancel_timer(state.batch_timer)
        {:noreply, %State{state | batch: [], batch_timer: nil}}
      
      state.batch_timer == nil ->
        # First item in batch, start timer
        timer = Process.send_after(self(), :batch_timeout, @batch_timeout)
        {:noreply, %State{state | batch: new_batch, batch_timer: timer}}
      
      true ->
        # Add to existing batch
        {:noreply, %State{state | batch: new_batch}}
    end
  end
  
  @impl true
  def handle_info(:batch_timeout, state) do
    if state.batch != [] do
      process_batch(state.batch)
    end
    
    {:noreply, %State{state | batch: [], batch_timer: nil}}
  end
  
  defp process_batch(batch) do
    # Process the batch
    Enum.reverse(batch) |> do_process()
  end
  
  defp cancel_timer(nil), do: :ok
  defp cancel_timer(ref), do: Process.cancel_timer(ref)
end
```

## Supervision Patterns

### GenServer Under Supervisor
```elixir
defmodule Raxol.MyApp.Supervisor do
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # Simple specification
      {Raxol.CacheServer, [name: :cache]},
      
      # Full specification
      %{
        id: Raxol.BufferServer,
        start: {Raxol.BufferServer, :start_link, [[width: 80, height: 24]]},
        restart: :permanent,
        shutdown: 5000,
        type: :worker
      },
      
      # With restart strategy
      Supervisor.child_spec(
        {Raxol.SessionServer, []},
        restart: :transient,
        shutdown: 10_000
      )
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### Dynamic GenServer Creation
```elixir
defmodule Raxol.TerminalManager do
  use DynamicSupervisor
  
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
  
  def start_terminal(id, config) do
    spec = {Raxol.Terminal, [id: id, config: config]}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
  
  def stop_terminal(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
```

## Registry Patterns

### Named GenServers with Registry
```elixir
defmodule Raxol.SessionRegistry do
  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end
  
  def via_tuple(session_id) do
    {:via, Registry, {__MODULE__, session_id}}
  end
  
  def whereis(session_id) do
    case Registry.lookup(__MODULE__, session_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end
  
  def list_sessions do
    Registry.select(__MODULE__, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
  end
end

defmodule Raxol.Session do
  use GenServer
  
  def start_link(session_id, opts) do
    name = Raxol.SessionRegistry.via_tuple(session_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def get_state(session_id) do
    session_id
    |> Raxol.SessionRegistry.via_tuple()
    |> GenServer.call(:get_state)
  end
end
```

## Error Handling Patterns

### Retry Logic
```elixir
defmodule Raxol.ResilientServer do
  use GenServer
  
  @max_retries 3
  @retry_delay 1000
  
  def handle_call({:fetch_data, source}, from, state) do
    Task.start(fn ->
      result = fetch_with_retry(source, @max_retries)
      GenServer.reply(from, result)
    end)
    
    {:noreply, state}
  end
  
  defp fetch_with_retry(source, retries_left) do
    case do_fetch(source) do
      {:ok, data} ->
        {:ok, data}
      
      {:error, reason} when retries_left > 0 ->
        Logger.warn("Fetch failed: #{inspect(reason)}, retrying...")
        Process.sleep(@retry_delay)
        fetch_with_retry(source, retries_left - 1)
      
      {:error, reason} ->
        Logger.error("Fetch failed after #{@max_retries} retries")
        {:error, reason}
    end
  end
end
```

### Circuit Breaker
```elixir
defmodule Raxol.CircuitBreaker do
  use GenServer
  
  defmodule State do
    defstruct [
      status: :closed,
      failure_count: 0,
      failure_threshold: 5,
      timeout: :timer.seconds(30),
      reset_timer: nil
    ]
  end
  
  def call(server, fun) do
    GenServer.call(server, {:call, fun})
  end
  
  @impl true
  def handle_call({:call, fun}, _from, %{status: :open} = state) do
    {:reply, {:error, :circuit_open}, state}
  end
  
  def handle_call({:call, fun}, _from, %{status: :closed} = state) do
    case safe_call(fun) do
      {:ok, result} ->
        {:reply, {:ok, result}, reset_failure_count(state)}
      
      {:error, _} = error ->
        new_state = increment_failure_count(state)
        
        if new_state.failure_count >= new_state.failure_threshold do
          opened_state = open_circuit(new_state)
          {:reply, error, opened_state}
        else
          {:reply, error, new_state}
        end
    end
  end
  
  def handle_call({:call, fun}, _from, %{status: :half_open} = state) do
    case safe_call(fun) do
      {:ok, result} ->
        # Success in half-open, close circuit
        {:reply, {:ok, result}, close_circuit(state)}
      
      {:error, _} = error ->
        # Failure in half-open, open circuit again
        {:reply, error, open_circuit(state)}
    end
  end
  
  @impl true
  def handle_info(:reset_circuit, state) do
    {:noreply, %{state | status: :half_open}}
  end
  
  defp safe_call(fun) do
    try do
      {:ok, fun.()}
    rescue
      error -> {:error, error}
    end
  end
  
  defp open_circuit(state) do
    timer = Process.send_after(self(), :reset_circuit, state.timeout)
    %{state | status: :open, reset_timer: timer}
  end
  
  defp close_circuit(state) do
    cancel_timer(state.reset_timer)
    %{state | status: :closed, failure_count: 0, reset_timer: nil}
  end
  
  defp reset_failure_count(state) do
    %{state | failure_count: 0}
  end
  
  defp increment_failure_count(state) do
    %{state | failure_count: state.failure_count + 1}
  end
  
  defp cancel_timer(nil), do: :ok
  defp cancel_timer(ref), do: Process.cancel_timer(ref)
end
```

## Testing GenServers

### Test Helper for GenServers
```elixir
defmodule Raxol.GenServerTestHelper do
  def start_supervised!(module, opts \\ []) do
    opts = Keyword.put_new(opts, :name, nil)
    child_spec = {module, opts}
    
    ExUnit.Callbacks.start_supervised!(child_spec)
  end
  
  def wait_for_state(server, expected_state, timeout \\ 1000) do
    wait_until(timeout, fn ->
      :sys.get_state(server) == expected_state
    end)
  end
  
  def wait_until(timeout, fun) do
    start_time = System.monotonic_time(:millisecond)
    
    Stream.repeatedly(fn ->
      if fun.() do
        :ok
      else
        Process.sleep(10)
        :retry
      end
    end)
    |> Enum.find(fn result ->
      result == :ok || 
      System.monotonic_time(:millisecond) - start_time > timeout
    end)
    |> case do
      :ok -> :ok
      _ -> raise "Timeout waiting for condition"
    end
  end
end
```

### Testing with Mox
```elixir
defmodule Raxol.ServerTest do
  use ExUnit.Case, async: true
  
  setup do
    server = start_supervised!(Raxol.MyServer)
    {:ok, server: server}
  end
  
  test "handles call", %{server: server} do
    assert {:ok, _} = GenServer.call(server, :get_state)
  end
  
  test "handles cast", %{server: server} do
    assert :ok = GenServer.cast(server, {:update, %{key: "value"}})
    
    # Wait for cast to be processed
    :sys.get_state(server)
    
    assert %{key: "value"} = GenServer.call(server, :get_data)
  end
  
  test "handles info", %{server: server} do
    send(server, :custom_message)
    
    # Verify message was handled
    assert :ok = wait_for_condition(fn ->
      :sys.get_state(server).message_received
    end)
  end
end
```

## Performance Patterns

### Pooling GenServers
```elixir
defmodule Raxol.WorkerPool do
  use Supervisor
  
  @pool_size 10
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    children = for i <- 1..@pool_size do
      %{
        id: {Raxol.Worker, i},
        start: {Raxol.Worker, :start_link, [[name: :"worker_#{i}"]]},
        restart: :permanent
      }
    end
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  def checkout do
    worker = :"worker_#{:rand.uniform(@pool_size)}"
    {:ok, worker}
  end
  
  def checkin(worker) do
    # Optional: track usage
    :ok
  end
end
```

## Best Practices

1. **Always implement `handle_info`** for unexpected messages
2. **Use `{:continue, term}` for async init** instead of blocking in `init/1`
3. **Trap exits** when managing other processes
4. **Use `call` for synchronous operations** that need a response
5. **Use `cast` for fire-and-forget** operations
6. **Always specify timeouts** for GenServer.call when appropriate
7. **Use Registry or named processes** for process discovery
8. **Implement `terminate/2`** for cleanup
9. **Use `code_change/3`** for hot code upgrades
10. **Test with `:sys.get_state/1`** for internal state verification