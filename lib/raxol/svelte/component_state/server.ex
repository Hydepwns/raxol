defmodule Raxol.Svelte.ComponentState.Server do
  @moduledoc """
  GenServer implementation for Svelte component state management.
  
  This server manages component slots and state without Process dictionary usage,
  providing per-process slot tracking and automatic cleanup.
  
  ## Features
  - Per-process slot tracking
  - Component render context management
  - Automatic cleanup on process termination
  - Support for nested component slots
  """
  
  use GenServer
  require Logger
  
  # Client API
  
  @doc """
  Starts the Svelte Component State server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Returns a child specification for this server.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end
  
  @doc """
  Sets the current component slots for the calling process.
  """
  def set_current_slots(slots, pid \\ nil) do
    pid = pid || self()
    GenServer.call(__MODULE__, {:set_slots, pid, slots})
  end
  
  @doc """
  Gets the current component slots for the calling process.
  """
  def get_current_slots(pid \\ nil) do
    pid = pid || self()
    GenServer.call(__MODULE__, {:get_slots, pid})
  end
  
  @doc """
  Clears the current component slots for the calling process.
  """
  def clear_current_slots(pid \\ nil) do
    pid = pid || self()
    GenServer.call(__MODULE__, {:clear_slots, pid})
  end
  
  @doc """
  Executes a function with specific slots set for the duration.
  """
  def with_slots(slots, fun, pid \\ nil) when is_function(fun, 0) do
    pid = pid || self()
    GenServer.call(__MODULE__, {:with_slots, pid, slots, fun})
  end
  
  @doc """
  Sets component state for a specific component ID.
  """
  def set_component_state(component_id, state) do
    GenServer.call(__MODULE__, {:set_component_state, component_id, state})
  end
  
  @doc """
  Gets component state for a specific component ID.
  """
  def get_component_state(component_id) do
    GenServer.call(__MODULE__, {:get_component_state, component_id})
  end
  
  @doc """
  Gets statistics about managed components and slots.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      # Map of pid -> slots
      process_slots: %{},
      # Map of component_id -> component_state
      component_states: %{},
      # Map of pid -> monitor_ref
      monitors: %{},
      # Slot tracking history for debugging
      slot_history: []
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:set_slots, pid, slots}, _from, state) do
    # Monitor the process if not already monitored
    state = ensure_monitored(pid, state)
    
    # Update slots for this process
    process_slots = Map.put(state.process_slots, pid, slots)
    
    # Add to history for debugging
    history_entry = %{
      action: :set_slots,
      pid: pid,
      slots: Map.keys(slots),
      timestamp: System.monotonic_time(:millisecond)
    }
    
    slot_history = [history_entry | state.slot_history]
                   |> Enum.take(100) # Keep last 100 entries
    
    updated_state = %{state | 
      process_slots: process_slots,
      slot_history: slot_history
    }
    
    {:reply, :ok, updated_state}
  end
  
  @impl true
  def handle_call({:get_slots, pid}, _from, state) do
    slots = Map.get(state.process_slots, pid, %{})
    {:reply, slots, state}
  end
  
  @impl true
  def handle_call({:clear_slots, pid}, _from, state) do
    process_slots = Map.delete(state.process_slots, pid)
    
    # Add to history for debugging
    history_entry = %{
      action: :clear_slots,
      pid: pid,
      timestamp: System.monotonic_time(:millisecond)
    }
    
    slot_history = [history_entry | state.slot_history]
                   |> Enum.take(100)
    
    updated_state = %{state | 
      process_slots: process_slots,
      slot_history: slot_history
    }
    
    {:reply, :ok, updated_state}
  end
  
  @impl true
  def handle_call({:with_slots, pid, slots, fun}, _from, state) do
    # Store current slots
    previous_slots = Map.get(state.process_slots, pid, %{})
    
    # Set new slots temporarily
    state = ensure_monitored(pid, state)
    process_slots = Map.put(state.process_slots, pid, slots)
    temp_state = %{state | process_slots: process_slots}
    
    # Execute function
    result = try do
      fun.()
    catch
      kind, reason ->
        Logger.error("Error in with_slots function: #{inspect(kind)}, #{inspect(reason)}")
        {:error, {kind, reason}}
    end
    
    # Restore previous slots
    final_process_slots = if previous_slots == %{} do
      Map.delete(temp_state.process_slots, pid)
    else
      Map.put(temp_state.process_slots, pid, previous_slots)
    end
    
    final_state = %{temp_state | process_slots: final_process_slots}
    
    {:reply, result, final_state}
  end
  
  @impl true
  def handle_call({:set_component_state, component_id, component_state}, _from, state) do
    component_states = Map.put(state.component_states, component_id, component_state)
    {:reply, :ok, %{state | component_states: component_states}}
  end
  
  @impl true
  def handle_call({:get_component_state, component_id}, _from, state) do
    component_state = Map.get(state.component_states, component_id)
    {:reply, component_state, state}
  end
  
  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      active_processes: map_size(state.process_slots),
      total_components: map_size(state.component_states),
      monitored_processes: map_size(state.monitors),
      history_entries: length(state.slot_history)
    }
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Clean up state for dead process
    state = %{state |
      process_slots: Map.delete(state.process_slots, pid),
      monitors: Map.delete(state.monitors, pid)
    }
    
    # Add to history for debugging
    history_entry = %{
      action: :process_down,
      pid: pid,
      timestamp: System.monotonic_time(:millisecond)
    }
    
    slot_history = [history_entry | state.slot_history]
                   |> Enum.take(100)
    
    {:noreply, %{state | slot_history: slot_history}}
  end
  
  # Private helpers
  
  defp ensure_monitored(pid, state) do
    if Map.has_key?(state.monitors, pid) do
      state
    else
      ref = Process.monitor(pid)
      %{state | monitors: Map.put(state.monitors, pid, ref)}
    end
  end
end