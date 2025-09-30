defmodule Raxol.Terminal.Event.Handler do
  @moduledoc """
  Handles terminal events including input events, state changes, and notifications.
  This module is responsible for processing and dispatching events to appropriate handlers.
  """

  use Raxol.Core.Behaviours.BaseManager

  alias Raxol.Terminal.Event

  # Client API

  @doc """
  Creates a new event handler with default values.
  """
  def new do
    %Event{handlers: %{}, queue: :queue.new()}
  end

  def register_handler(emulator, event_type, handler) do
    case emulator.event do
      nil ->
        emulator

      %Event{} = event_struct ->
        # Direct struct mode for testing
        new_handlers = Map.put(event_struct.handlers, event_type, handler)
        %{emulator | event: %{event_struct | handlers: new_handlers}}

      event_pid ->
        GenServer.call(event_pid, {:register_handler, event_type, handler})
        emulator
    end
  end

  def unregister_handler(emulator, event_type) do
    case emulator.event do
      nil ->
        emulator

      event_pid ->
        GenServer.call(event_pid, {:unregister_handler, event_type})
        emulator
    end
  end

  def queue_event(emulator, event_type, event_data) do
    case emulator.event do
      nil ->
        emulator

      %Event{} = event_struct ->
        # Direct struct mode for testing
        new_queue = :queue.in({event_type, event_data}, event_struct.queue)
        %{emulator | event: %{event_struct | queue: new_queue}}

      event_pid ->
        GenServer.cast(event_pid, {:queue_event, event_type, event_data})
        emulator
    end
  end

  def process_events(emulator) do
    case emulator.event do
      nil ->
        emulator

      %Event{} = event_struct ->
        # Direct struct mode for testing - process all events in queue
        process_event_queue(emulator, event_struct)

      event_pid ->
        GenServer.call(event_pid, :process_events)
        emulator
    end
  end

  def get_event_queue(emulator) do
    case emulator.event do
      nil -> :queue.new()
      %Event{} = event_struct -> event_struct.queue
      event_pid -> GenServer.call(event_pid, :get_event_queue)
    end
  end

  def clear_event_queue(emulator) do
    case emulator.event do
      nil ->
        emulator

      event_pid ->
        GenServer.call(event_pid, :clear_event_queue)
        emulator
    end
  end

  # Helper function for processing events in struct mode
  defp process_event_queue(emulator, event_struct) do
    case :queue.out(event_struct.queue) do
      {:empty, _} ->
        emulator

      {{:value, {event_type, event_data}}, remaining_queue} ->
        # Process this event and continue with remaining queue
        updated_emulator =
          case Map.get(event_struct.handlers, event_type) do
            nil -> emulator
            handler -> handler.(emulator, event_data)
          end

        # Update the queue and continue processing
        updated_event_struct = %{event_struct | queue: remaining_queue}
        updated_emulator = %{updated_emulator | event: updated_event_struct}
        process_event_queue(updated_emulator, updated_event_struct)
    end
  end

  def reset_event_handler(emulator) do
    case emulator.event do
      nil ->
        emulator

      event_pid ->
        GenServer.call(event_pid, :reset)
        emulator
    end
  end

  def dispatch_event(emulator, event_type, event_data) do
    case emulator.event do
      nil ->
        {:ok, emulator}

      %Event{} = event_struct ->
        # Direct struct mode for testing
        case Map.get(event_struct.handlers, event_type) do
          nil -> {:ok, emulator}
          handler -> {:ok, handler.(emulator, event_data)}
        end

      event_pid ->
        GenServer.call(
          event_pid,
          {:dispatch_event, event_type, event_data, emulator}
        )
    end
  end

  # BaseManager Callbacks
  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(_opts) do
    {:ok, %Event{handlers: %{}, queue: :queue.new()}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:register_handler, event_type, handler},
        _from,
        state
      ) do
    handlers = Map.put(state.handlers, event_type, handler)
    {:reply, :ok, %{state | handlers: handlers}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:unregister_handler, event_type}, _from, state) do
    handlers = Map.delete(state.handlers, event_type)
    {:reply, :ok, %{state | handlers: handlers}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:dispatch_event, event_type, event_data, emulator},
        _from,
        state
      ) do
    case Map.get(state.handlers, event_type) do
      nil ->
        {:reply, {:ok, emulator}, state}

      handler ->
        # Pass the actual emulator to the handler
        result = handler.(emulator, event_data)
        {:reply, result, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_event_queue, _from, state) do
    {:reply, state.queue, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:clear_event_queue, _from, state) do
    {:reply, :ok, %{state | queue: :queue.new()}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:reset, _from, _state) do
    {:reply, :ok, %Event{handlers: %{}, queue: :queue.new()}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:process_events, _from, state) do
    {processed_events, new_state} = process_queued_events(state)
    {:reply, processed_events, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:queue_event, event_type, event_data}, state) do
    queue = :queue.in({event_type, event_data}, state.queue)
    {:noreply, %{state | queue: queue}}
  end

  # Private functions
  defp process_queued_events(state) do
    process_queued_events_recursive(state, [])
  end

  defp process_queued_events_recursive(state, processed_events) do
    case :queue.out(state.queue) do
      {{:value, {event_type, event_data}}, remaining_queue} ->
        case Map.get(state.handlers, event_type) do
          nil ->
            # No handler for this event, skip it
            process_queued_events_recursive(
              %{state | queue: remaining_queue},
              processed_events
            )

          handler ->
            # Call the handler with a minimal emulator structure
            # Note: In queue processing, we don't have the full emulator context
            case handler.(%{event: self()}, event_data) do
              {:ok, _result} ->
                # Event processed successfully, continue with remaining events
                process_queued_events_recursive(
                  %{state | queue: remaining_queue},
                  [{event_type, event_data} | processed_events]
                )

              _ ->
                # Event processing failed, skip it
                process_queued_events_recursive(
                  %{state | queue: remaining_queue},
                  processed_events
                )
            end
        end

      {:empty, _} ->
        {Enum.reverse(processed_events), state}
    end
  end
end
