defmodule Raxol.Terminal.Split.Sync do
  @moduledoc """
  Handles synchronization between terminal splits, including event broadcasting,
  state sharing, and communication protocols.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def broadcast_event(split_id, event_type, payload) do
    GenServer.cast(__MODULE__, {:broadcast_event, split_id, event_type, payload})
  end

  def subscribe_to_events(split_id, callback) do
    GenServer.call(__MODULE__, {:subscribe, split_id, callback})
  end

  def unsubscribe_from_events(split_id) do
    GenServer.call(__MODULE__, {:unsubscribe, split_id})
  end

  def get_shared_state(split_id) do
    GenServer.call(__MODULE__, {:get_shared_state, split_id})
  end

  def update_shared_state(split_id, state_updates) do
    GenServer.call(__MODULE__, {:update_shared_state, split_id, state_updates})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      subscribers: %{},
      shared_states: %{},
      event_history: []
    }
    {:ok, state}
  end

  @impl true
  def handle_cast({:broadcast_event, split_id, event_type, payload}, state) do
    event = %{
      split_id: split_id,
      type: event_type,
      payload: payload,
      timestamp: DateTime.utc_now()
    }

    # Notify subscribers
    state.subscribers
    |> Map.values()
    |> Enum.each(fn callback -> callback.(event) end)

    # Update event history
    new_history = [event | state.event_history] |> Enum.take(100)

    {:noreply, %{state | event_history: new_history}}
  end

  @impl true
  def handle_call({:subscribe, split_id, callback}, _from, state) do
    new_subscribers = Map.put(state.subscribers, split_id, callback)
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end

  @impl true
  def handle_call({:unsubscribe, split_id}, _from, state) do
    new_subscribers = Map.delete(state.subscribers, split_id)
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end

  @impl true
  def handle_call({:get_shared_state, split_id}, _from, state) do
    shared_state = Map.get(state.shared_states, split_id, %{})
    {:reply, shared_state, state}
  end

  @impl true
  def handle_call({:update_shared_state, split_id, state_updates}, _from, state) do
    current_state = Map.get(state.shared_states, split_id, %{})
    new_state = Map.merge(current_state, state_updates)
    new_shared_states = Map.put(state.shared_states, split_id, new_state)
    {:reply, new_state, %{state | shared_states: new_shared_states}}
  end
end
