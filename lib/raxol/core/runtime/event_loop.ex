defmodule Raxol.Core.Runtime.EventLoop do
  @moduledoc """
  Manages the event processing loop for terminal events.

  The event loop:
  * Polls for terminal events
  * Converts them to Raxol events
  * Handles timers and intervals
  * Manages the event queue
  """

  use GenServer

  alias Raxol.Core.Events.{Event, Manager}
  alias ExTermbox.Event, as: TermboxEvent

  require Logger

  @poll_interval 16 # ~60 FPS

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sets up a timer that will trigger after the specified delay.
  """
  def set_timer(delay, data) when is_integer(delay) and delay > 0 do
    GenServer.call(__MODULE__, {:set_timer, delay, data})
  end

  @doc """
  Sets up an interval that will trigger repeatedly.
  """
  def set_interval(interval, data) when is_integer(interval) and interval > 0 do
    GenServer.call(__MODULE__, {:set_interval, interval, data})
  end

  @doc """
  Cancels a timer or interval by its reference.
  """
  def cancel_timer(ref) when is_reference(ref) do
    GenServer.cast(__MODULE__, {:cancel_timer, ref})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Start the event polling loop
    schedule_poll()

    {:ok, %{
      timers: %{},
      intervals: %{},
      event_queue: :queue.new()
    }}
  end

  @impl true
  def handle_call({:set_timer, delay, data}, _from, state) do
    ref = make_ref()
    timer_ref = Process.send_after(self(), {:timer, ref}, delay)
    
    timers = Map.put(state.timers, ref, %{
      ref: timer_ref,
      data: data
    })
    
    {:reply, {:ok, ref}, %{state | timers: timers}}
  end

  @impl true
  def handle_call({:set_interval, interval, data}, _from, state) do
    ref = make_ref()
    timer_ref = Process.send_after(self(), {:interval, ref}, interval)
    
    intervals = Map.put(state.intervals, ref, %{
      ref: timer_ref,
      interval: interval,
      data: data
    })
    
    {:reply, {:ok, ref}, %{state | intervals: intervals}}
  end

  @impl true
  def handle_cast({:cancel_timer, ref}, state) do
    case Map.pop(state.timers, ref) do
      {nil, _} ->
        case Map.pop(state.intervals, ref) do
          {nil, _} ->
            {:noreply, state}
          {interval, intervals} ->
            Process.cancel_timer(interval.ref)
            {:noreply, %{state | intervals: intervals}}
        end
      {timer, timers} ->
        Process.cancel_timer(timer.ref)
        {:noreply, %{state | timers: timers}}
    end
  end

  @impl true
  def handle_info(:poll, state) do
    # Poll for terminal events
    case poll_event() do
      nil ->
        :ok
      event ->
        # Convert and dispatch the event
        case Event.from_termbox(event) do
          nil -> :ok
          raxol_event -> Manager.dispatch(raxol_event)
        end
    end

    # Schedule the next poll
    schedule_poll()
    {:noreply, state}
  end

  def handle_info({:timer, ref}, state) do
    case Map.pop(state.timers, ref) do
      {nil, _} ->
        {:noreply, state}
      {timer, timers} ->
        # Dispatch the timer event
        Manager.dispatch(Event.timer(timer.data))
        {:noreply, %{state | timers: timers}}
    end
  end

  def handle_info({:interval, ref}, state) do
    case Map.get(state.intervals, ref) do
      nil ->
        {:noreply, state}
      interval ->
        # Reschedule the interval
        timer_ref = Process.send_after(self(), {:interval, ref}, interval.interval)
        intervals = Map.put(state.intervals, ref, %{interval | ref: timer_ref})
        
        # Dispatch the interval event
        Manager.dispatch(Event.timer(interval.data))
        
        {:noreply, %{state | intervals: intervals}}
    end
  end

  # Private Helpers

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defp poll_event do
    try do
      TermboxEvent.poll()
    rescue
      e ->
        Logger.error("Error polling terminal events: #{inspect(e)}")
        nil
    end
  end
end 