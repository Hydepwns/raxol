defmodule Raxol.Terminal.Event.Handler do
  @moduledoc """
  Handles terminal events including input events, state changes, and notifications.
  This module is responsible for processing and dispatching events to appropriate handlers.
  """

  use GenServer
  alias Raxol.Terminal.Event

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts,
      name: Keyword.get(opts, :name, __MODULE__)
    )
  end

  @doc """
  Creates a new event handler with default values.
  """
  def new() do
    %Event{handlers: %{}, queue: :queue.new()}
  end

  def register_handler(emulator, event_type, handler) do
    handlers = Map.get(emulator.event_handlers, :handlers, %{})
    handlers = Map.put(handlers, event_type, handler)

    %{
      emulator
      | event_handlers: %{emulator.event_handlers | handlers: handlers}
    }
  end

  def unregister_handler(emulator, event_type) do
    handlers = Map.get(emulator.event_handlers, :handlers, %{})
    handlers = Map.delete(handlers, event_type)

    %{
      emulator
      | event_handlers: %{emulator.event_handlers | handlers: handlers}
    }
  end

  def queue_event(emulator, event_type, event_data) do
    queue = Map.get(emulator.event_handlers, :queue, [])
    queue = queue ++ [{event_type, event_data}]
    %{emulator | event_handlers: %{emulator.event_handlers | queue: queue}}
  end

  def process_events(emulator) do
    _queue = Map.get(emulator.event_handlers, :queue, [])
    handlers = Map.get(emulator.event_handlers, :handlers, %{})

    {_processed_events, emulator} =
      Enum.reduce(_queue, {[], emulator}, fn {event_type, event_data},
                                             {processed, emu} ->
        case Map.get(handlers, event_type) do
          nil ->
            {processed, emu}

          handler ->
            case handler.(emu, event_data) do
              {:ok, new_emu} ->
                {processed ++ [{event_type, event_data}], new_emu}

              _ ->
                {processed, emu}
            end
        end
      end)

    %{emulator | event_handlers: %{emulator.event_handlers | queue: []}}
  end

  def get_event_queue(emulator) do
    Map.get(emulator.event_handlers, :queue, [])
  end

  def clear_event_queue(emulator) do
    %{emulator | event_handlers: %{emulator.event_handlers | queue: []}}
  end

  def reset_event_handler(emulator) do
    %{emulator | event_handlers: %{handlers: %{}, queue: []}}
  end

  def dispatch_event(emulator, event_type, event_data) do
    handlers = Map.get(emulator.event_handlers, :handlers, %{})

    case Map.get(handlers, event_type) do
      nil -> {:ok, emulator}
      handler -> handler.(emulator, event_data)
    end
  end

  # Server Callbacks
  def init(_opts) do
    {:ok, %Event{handlers: %{}, queue: :queue.new()}}
  end
end
