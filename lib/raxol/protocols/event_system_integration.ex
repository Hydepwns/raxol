defmodule Raxol.Protocols.EventSystemIntegration do
  @moduledoc """
  Integration layer between the existing event system and the new EventHandler protocol.

  This module provides adapters and utilities to bridge the gap between
  the current event management system and the new protocol-based approach.
  """

  alias Raxol.Protocols.EventHandler
  alias Raxol.Core.Events.EventManager

  # Event Bus struct
  defmodule EventBus do
    defstruct handlers: %{}, middleware: [], error_handler: nil
  end

  @doc """
  Protocol-aware event dispatcher that can handle both protocol-implementing
  types and traditional event handlers.
  """
  def dispatch_event(target, event, state \\ %{}) do
    case EventHandler.handle_event(target, event, state) do
      {:ok, updated_target, new_state} ->
        {:ok, updated_target, new_state}

      {:error, reason} ->
        {:error, reason}

      {:unhandled, target, state} ->
        # Fall back to traditional event handling
        fallback_dispatch(target, event, state)

      {:stop, target, state} ->
        {:stop, target, state}

      {:bubble, target, state} ->
        {:bubble, target, state}
    end
  end

  @doc """
  Enhanced event manager that can work with protocol-implementing handlers.
  """
  def register_handler(event_type, handler) do
    if EventHandler.can_handle?(handler, %{type: event_type}) do
      # Use register_handler/3 with self() as the target process
      EventManager.register_handler(
        event_type,
        self(),
        &protocol_handler_wrapper(handler, &1, &2)
      )
    else
      {:error, :handler_cannot_handle_event}
    end
  end

  @doc """
  Subscribe a protocol-implementing handler to multiple event types.
  """
  def subscribe_handler(handler, event_types) do
    results =
      Enum.map(event_types, fn event_type ->
        {event_type, register_handler(event_type, handler)}
      end)

    # Update handler's subscription state
    updated_handler = EventHandler.subscribe(handler, event_types)

    {results, updated_handler}
  end

  @doc """
  Create a unified event bus that can dispatch to protocol handlers.
  """
  def create_event_bus(opts \\ []) do
    %EventBus{
      handlers: %{},
      middleware: Keyword.get(opts, :middleware, []),
      error_handler: Keyword.get(opts, :error_handler, &default_error_handler/2)
    }
  end

  @doc """
  Add a handler to the event bus.
  """
  def add_handler(%EventBus{} = bus, event_type, handler) do
    handlers = Map.update(bus.handlers, event_type, [handler], &[handler | &1])
    %{bus | handlers: handlers}
  end

  @doc """
  Dispatch an event through the event bus to all registered handlers.
  """
  def dispatch_through_bus(%EventBus{} = bus, event) do
    handlers = Map.get(bus.handlers, event.type, [])

    results =
      Enum.map(handlers, fn handler ->
        try do
          case EventHandler.handle_event(handler, event, %{}) do
            {:ok, updated_handler, state} ->
              {:ok, updated_handler, state}

            {:error, reason} ->
              bus.error_handler.(event, reason)
              {:error, reason}

            other ->
              other
          end
        rescue
          error ->
            bus.error_handler.(event, error)
            {:error, error}
        end
      end)

    # Apply middleware
    final_results =
      Enum.reduce(bus.middleware, results, fn middleware, acc ->
        middleware.(event, acc)
      end)

    final_results
  end

  # Protocol implementation for EventBus
  defimpl EventHandler, for: EventBus do
    def handle_event(bus, event, state) do
      results =
        Raxol.Protocols.EventSystemIntegration.dispatch_through_bus(bus, event)

      # Aggregate results
      case aggregate_results(results) do
        {:ok, _} -> {:ok, bus, Map.put(state, :bus_results, results)}
        {:error, reason} -> {:error, reason}
        _ -> {:unhandled, bus, state}
      end
    end

    def can_handle?(bus, event) do
      handlers = Map.get(bus.handlers, event.type, [])
      Enum.any?(handlers, &EventHandler.can_handle?(&1, event))
    end

    def get_event_listeners(bus) do
      Map.keys(bus.handlers)
    end

    def subscribe(bus, _event_types) do
      # EventBus doesn't maintain subscription state itself
      bus
    end

    def unsubscribe(bus, event_types) do
      # Remove handlers for specific event types
      updated_handlers =
        Enum.reduce(event_types, bus.handlers, fn event_type, acc ->
          Map.delete(acc, event_type)
        end)

      %{bus | handlers: updated_handlers}
    end

    defp aggregate_results(results) do
      errors = Enum.filter(results, &match?({:error, _}, &1))

      cond do
        length(errors) > 0 -> hd(errors)
        Enum.any?(results, &match?({:ok, _, _}, &1)) -> {:ok, :handled}
        true -> {:unhandled, :no_handlers}
      end
    end
  end

  # Enhanced event structure with protocol support
  defmodule ProtocolEvent do
    defstruct [
      :type,
      :target,
      :timestamp,
      :data,
      :metadata,
      :source,
      :propagation_stopped
    ]

    def new(type, data \\ %{}, opts \\ []) do
      %__MODULE__{
        type: type,
        target: Keyword.get(opts, :target),
        timestamp: System.monotonic_time(:millisecond),
        data: data,
        metadata: Keyword.get(opts, :metadata, %{}),
        source: Keyword.get(opts, :source),
        propagation_stopped: false
      }
    end

    def stop_propagation(event) do
      %{event | propagation_stopped: true}
    end

    def should_propagate?(event) do
      not event.propagation_stopped
    end
  end

  # Protocol implementation for ProtocolEvent
  defimpl EventHandler, for: ProtocolEvent do
    def handle_event(event, _incoming_event, state) do
      # Events can handle other events (event composition)
      {:unhandled, event, state}
    end

    def can_handle?(_event, _incoming_event) do
      # Events don't handle other events by default
      false
    end

    def get_event_listeners(_event) do
      []
    end

    def subscribe(event, _event_types) do
      event
    end

    def unsubscribe(event, _event_types) do
      event
    end
  end

  # Utility functions
  defp protocol_handler_wrapper(handler, event, state) do
    case EventHandler.handle_event(handler, event, state) do
      {:ok, _updated_handler, new_state} -> {:ok, new_state}
      {:error, reason} -> {:error, reason}
      {:unhandled, _handler, state} -> {:unhandled, state}
      {:stop, _handler, state} -> {:stop, state}
      {:bubble, _handler, state} -> {:bubble, state}
    end
  end

  defp fallback_dispatch(target, event, state) do
    # Try to use the existing event system
    case EventManager.dispatch(event) do
      :ok -> {:ok, target, state}
      {:error, reason} -> {:error, reason}
      _ -> {:unhandled, target, state}
    end
  rescue
    _ -> {:unhandled, target, state}
  end

  defp default_error_handler(event, error) do
    require Logger
    Logger.error("Event handling error for #{event.type}: #{inspect(error)}")
  end

  @doc """
  Create a middleware function for logging events.
  """
  def logging_middleware(opts \\ []) do
    level = Keyword.get(opts, :level, :info)

    fn event, results ->
      require Logger

      message = "Event #{event.type} processed with #{length(results)} results"
      Logger.log(level, message)

      results
    end
  end

  @doc """
  Create a middleware function for performance monitoring.
  """
  def performance_middleware(opts \\ []) do
    # milliseconds
    threshold = Keyword.get(opts, :threshold, 100)

    fn event, results ->
      duration = System.monotonic_time(:millisecond) - event.timestamp

      if duration > threshold do
        require Logger

        Logger.warning(
          "Slow event processing: #{event.type} took #{duration}ms"
        )
      end

      results
    end
  end

  @doc """
  Create a middleware function for event filtering.
  """
  def filtering_middleware(filter_fn) when is_function(filter_fn, 1) do
    fn event, results ->
      if filter_fn.(event) do
        results
      else
        # Filter out the event
        []
      end
    end
  end
end
