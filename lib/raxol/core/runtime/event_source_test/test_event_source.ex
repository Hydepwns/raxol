defmodule Raxol.Core.Runtime.EventSourceTest.TestEventSource do
  @moduledoc """
  A test implementation of an event source for testing purposes.
  """

  use GenServer
  require Logger

  def start_link(args \\ %{}, context \\ %{}) do
    GenServer.start_link(__MODULE__, {args, context}, name: __MODULE__)
  end

  @impl GenServer
  def init({args, context}) do
    state = %{
      args: args,
      context: context,
      events: [],
      subscribers: MapSet.new()
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_events, _from, state) do
    {:reply, state.events, state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_cast({:emit, event}, state) do
    new_events = [event | state.events]
    notify_subscribers(event, state.subscribers)
    {:noreply, %{state | events: new_events}}
  end

  @impl GenServer
  def handle_cast({:subscribe, pid}, state) do
    new_subscribers = MapSet.put(state.subscribers, pid)
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  @impl GenServer
  def handle_cast({:unsubscribe, pid}, state) do
    new_subscribers = MapSet.delete(state.subscribers, pid)
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  @spec notify_subscribers(any(), any()) :: any()
  defp notify_subscribers(event, subscribers) do
    Enum.each(subscribers, fn pid ->
      case Process.alive?(pid) do
        true -> send(pid, {:event, event})
        false -> :ok
      end
    end)
  end

  # Client API

  def get_events do
    GenServer.call(__MODULE__, :get_events)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def emit(event) do
    GenServer.cast(__MODULE__, {:emit, event})
  end

  def subscribe(pid \\ self()) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end

  def unsubscribe(pid \\ self()) do
    GenServer.cast(__MODULE__, {:unsubscribe, pid})
  end
end
