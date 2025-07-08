defmodule Raxol.Core.Runtime.EventSourceTest.TestEventSource do
  @moduledoc """
  A test implementation of an event source for testing purposes.
  """

  use GenServer
  require Logger

  def start_link(args \\ %{}, context \\ %{}) do
    GenServer.start_link(__MODULE__, {args, context})
  end

  @impl GenServer
  def init({args, context}) do
    if Map.get(args, :fail_init, false) do
      {:stop, :init_failed}
    else
      state = %{
        args: args,
        context: context,
        events: [],
        subscribers: MapSet.new()
      }

      {:ok, state}
    end
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

  defp notify_subscribers(event, subscribers) do
    Enum.each(subscribers, fn pid ->
      if Process.alive?(pid) do
        send(pid, {:event, event})
      end
    end)
  end

  # Client API

  def get_events(pid) do
    GenServer.call(pid, :get_events)
  end

  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def emit(pid, event) do
    GenServer.cast(pid, {:emit, event})
  end

  def subscribe(pid, subscriber_pid \\ self()) do
    GenServer.cast(pid, {:subscribe, subscriber_pid})
  end

  def unsubscribe(pid, subscriber_pid \\ self()) do
    GenServer.cast(pid, {:unsubscribe, subscriber_pid})
  end
end
