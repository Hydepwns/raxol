defmodule Raxol.Terminal.Event.Handler do
  @moduledoc """
  Handles terminal events including input events, state changes, and notifications.
  This module is responsible for processing and dispatching events to appropriate handlers.
  """

  alias Raxol.Terminal.{Emulator, Event}
  require Raxol.Core.Runtime.Log

  @doc """
  Creates a new event handler.
  """
  @spec new() :: Event.t()
  def new do
    %Event{
      handlers: %{},
      queue: :queue.new()
    }
  end

  @doc """
  Registers an event handler for a specific event type.
  Returns the updated emulator.
  """
  @spec register_handler(Emulator.t(), atom(), function()) :: Emulator.t()
  def register_handler(emulator, event_type, handler) when is_atom(event_type) and is_function(handler, 2) do
    handlers = Map.put(emulator.event.handlers, event_type, handler)
    %{emulator | event: %{emulator.event | handlers: handlers}}
  end

  @doc """
  Unregisters an event handler for a specific event type.
  Returns the updated emulator.
  """
  @spec unregister_handler(Emulator.t(), atom()) :: Emulator.t()
  def unregister_handler(emulator, event_type) when is_atom(event_type) do
    handlers = Map.delete(emulator.event.handlers, event_type)
    %{emulator | event: %{emulator.event | handlers: handlers}}
  end

  @doc """
  Dispatches an event to its registered handler.
  Returns the updated emulator.
  """
  @spec dispatch_event(Emulator.t(), atom(), any()) :: Emulator.t()
  def dispatch_event(emulator, event_type, event_data) when is_atom(event_type) do
    case Map.get(emulator.event.handlers, event_type) do
      nil ->
        emulator
      handler ->
        handler.(emulator, event_data)
    end
  end

  @doc """
  Queues an event for later processing.
  Returns the updated emulator.
  """
  @spec queue_event(Emulator.t(), atom(), any()) :: Emulator.t()
  def queue_event(emulator, event_type, event_data) when is_atom(event_type) do
    queue = :queue.in({event_type, event_data}, emulator.event.queue)
    %{emulator | event: %{emulator.event | queue: queue}}
  end

  @doc """
  Processes all queued events.
  Returns the updated emulator.
  """
  @spec process_events(Emulator.t()) :: Emulator.t()
  def process_events(emulator) do
    case :queue.out(emulator.event.queue) do
      {{:value, {event_type, event_data}}, new_queue} ->
        emulator
        |> dispatch_event(event_type, event_data)
        |> Map.put(:event, %{emulator.event | queue: new_queue})
        |> process_events()
      {:empty, _} ->
        emulator
    end
  end

  @doc """
  Gets the current event queue.
  Returns the queue of events.
  """
  @spec get_event_queue(Emulator.t()) :: :queue.queue()
  def get_event_queue(emulator) do
    emulator.event.queue
  end

  @doc """
  Clears the event queue.
  Returns the updated emulator.
  """
  @spec clear_event_queue(Emulator.t()) :: Emulator.t()
  def clear_event_queue(emulator) do
    %{emulator | event: %{emulator.event | queue: :queue.new()}}
  end

  @doc """
  Resets the event handler to its initial state.
  Returns the updated emulator.
  """
  @spec reset_event_handler(Emulator.t()) :: Emulator.t()
  def reset_event_handler(emulator) do
    %{emulator | event: new()}
  end
end
