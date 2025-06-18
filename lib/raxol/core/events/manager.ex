defmodule Raxol.Core.Events.Manager do
  @moduledoc """
  Event manager for handling and dispatching events in Raxol applications.

  This module provides a simple event system that allows:
  - Registering event handlers
  - Dispatching events
  - Handling events
  - Managing subscriptions

  ## Usage

  ```elixir
  # Initialize the event manager
  EventManager.init()

  # Register an event handler
  EventManager.register_handler(:click, MyModule, :handle_click)

  # Subscribe to events
  {:ok, ref} = EventManager.subscribe([:click, :key_press])

  # Dispatch an event
  EventManager.dispatch({:click, %{x: 10, y: 20}})

  # Unsubscribe
  EventManager.unsubscribe(ref)
  ```
  """

  @behaviour Raxol.Core.Events.Manager.Behaviour

  @doc """
  Initialize the event manager.

  ## Examples

      iex> EventManager.init()
      :ok
  """
  def init do
    # Initialize event handlers registry and subscriptions
    Process.put(:event_handlers, %{})
    Process.put(:subscriptions, %{})
    :ok
  end

  @doc """
  Register an event handler.

  ## Parameters

  * `event_type` - The type of event to handle
  * `module` - The module containing the handler function
  * `function` - The function to call when the event occurs

  ## Examples

      iex> EventManager.register_handler(:click, MyModule, :handle_click)
      :ok
  """
  def register_handler(event_type, module, function)
      when is_atom(event_type) and is_atom(module) and is_atom(function) do
    # Get current handlers
    handlers = Process.get(:event_handlers) || %{}

    # Get handlers for this event type
    event_handlers = Map.get(handlers, event_type, [])

    # Add the new handler if not already registered
    updated_handlers =
      if {module, function} in event_handlers do
        event_handlers
      else
        [{module, function} | event_handlers]
      end

    # Update the registry
    updated_registry = Map.put(handlers, event_type, updated_handlers)
    Process.put(:event_handlers, updated_registry)

    :ok
  end

  @doc """
  Unregister an event handler.

  ## Parameters

  * `event_type` - The type of event
  * `module` - The module containing the handler function
  * `function` - The function that was registered

  ## Examples

      iex> EventManager.unregister_handler(:click, MyModule, :handle_click)
      :ok
  """
  def unregister_handler(event_type, module, function)
      when is_atom(event_type) and is_atom(module) and is_atom(function) do
    # Get current handlers
    handlers = Process.get(:event_handlers) || %{}

    # Get handlers for this event type
    event_handlers = Map.get(handlers, event_type, [])

    # Remove the handler
    updated_handlers =
      Enum.reject(event_handlers, fn {m, f} -> m == module and f == function end)

    # Update the registry
    updated_registry = Map.put(handlers, event_type, updated_handlers)
    Process.put(:event_handlers, updated_registry)

    :ok
  end

  @doc """
  Subscribe to events with optional filters.

  ## Parameters

  * `event_types` - List of event types to subscribe to
  * `opts` - Optional filters and options

  ## Examples

      iex> EventManager.subscribe([:click, :key_press])
      {:ok, ref}

      iex> EventManager.subscribe([:mouse], button: :left)
      {:ok, ref}
  """
  def subscribe(event_types, opts \\ []) when is_list(event_types) do
    # Generate unique subscription reference
    ref = System.unique_integer([:positive])

    # Get current subscriptions
    subscriptions = Process.get(:subscriptions) || %{}

    # Store subscription with filters
    subscription = %{
      event_types: event_types,
      filters: opts,
      pid: self()
    }

    # Update subscriptions
    updated_subscriptions = Map.put(subscriptions, ref, subscription)
    Process.put(:subscriptions, updated_subscriptions)

    {:ok, ref}
  end

  @doc """
  Unsubscribe from events using the subscription reference.

  ## Examples

      iex> EventManager.unsubscribe(ref)
      :ok
  """
  def unsubscribe(ref) when is_integer(ref) do
    # Get current subscriptions
    subscriptions = Process.get(:subscriptions) || %{}

    # Remove subscription
    updated_subscriptions = Map.delete(subscriptions, ref)
    Process.put(:subscriptions, updated_subscriptions)

    :ok
  end

  @doc """
  Dispatch an event to all registered handlers and subscribers.

  ## Parameters

  * `event` - The event to dispatch

  ## Examples

      iex> EventManager.dispatch({:click, %{x: 10, y: 20}})
      :ok

      iex> EventManager.dispatch(:accessibility_high_contrast)
      :ok
  """
  def dispatch(event) do
    # Extract event type from event
    event_type = extract_event_type(event)

    # Get handlers for this event type
    handlers = Process.get(:event_handlers) || %{}
    event_handlers = Map.get(handlers, event_type, [])

    # Call each handler
    Enum.each(event_handlers, fn {module, function} ->
      apply(module, function, [event])
    end)

    # Get subscriptions
    subscriptions = Process.get(:subscriptions) || %{}

    # Notify matching subscribers
    Enum.each(subscriptions, fn {_ref, subscription} ->
      if event_type in subscription.event_types and
           matches_filters?(event, subscription.filters) do
        send(subscription.pid, {:event, event})
      end
    end)

    :ok
  end

  @doc """
  Broadcast an event to all subscribers.

  ## Examples

      iex> EventManager.broadcast({:system_event, :shutdown})
      :ok
  """
  def broadcast(event) do
    # Get all subscriptions
    subscriptions = Process.get(:subscriptions) || %{}

    # Send event to all subscribers
    Enum.each(subscriptions, fn {_ref, subscription} ->
      send(subscription.pid, {:event, event})
    end)

    :ok
  end

  @doc """
  Get all registered event handlers.

  ## Examples

      iex> EventManager.get_handlers()
      %{click: [{MyModule, :handle_click}]}
  """
  def get_handlers do
    Process.get(:event_handlers) || %{}
  end

  @doc """
  Clear all event handlers.

  ## Examples

      iex> EventManager.clear_handlers()
      :ok
  """
  def clear_handlers do
    Process.put(:event_handlers, %{})
    :ok
  end

  @doc """
  Cleans up the event manager state.
  """
  def cleanup() do
    Process.delete(:event_handlers)
    Process.delete(:subscriptions)
    :ok
  end

  @doc """
  Triggers an event with a type and payload (alias for dispatch/1).
  This is provided for API compatibility; use dispatch/1 for generic events.
  """
  def trigger(event_type, payload) do
    dispatch({event_type, payload})
  end

  # Private functions

  defp extract_event_type(event) when is_atom(event), do: event

  defp extract_event_type({event_type, _data}) when is_atom(event_type),
    do: event_type

  defp extract_event_type(_), do: :unknown

  defp matches_filters?(_event, []), do: true

  defp matches_filters?(event, filters) do
    Enum.all?(filters, fn {key, value} ->
      case event do
        {_type, data} when is_map(data) -> Map.get(data, key) == value
        _ -> false
      end
    end)
  end
end
