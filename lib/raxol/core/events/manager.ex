defmodule Raxol.Core.Events.Manager do
  @moduledoc """
  Refactored Events.Manager that delegates to GenServer implementation.
  
  This module provides the same API as the original Events.Manager but uses
  a supervised GenServer with PubSub pattern instead of the Process dictionary
  for state management.
  
  ## Migration Notice
  This module is a drop-in replacement for `Raxol.Core.Events.Manager`.
  All functions maintain backward compatibility while providing improved
  fault tolerance and functional programming patterns.
  
  ## Benefits over Process Dictionary
  - Supervised state management with fault tolerance
  - Pure functional event handling
  - Process monitoring for automatic cleanup
  - Priority-based handler execution
  - Optional event history tracking
  - Better debugging and testing capabilities
  - No global state pollution
  
  ## New Features
  - Priority handlers: Execute handlers in defined order
  - Process monitoring: Automatic cleanup when subscribers die
  - Event history: Optional tracking of dispatched events
  - Synchronous dispatch: Wait for handlers to complete
  """

  @behaviour Raxol.Core.Events.Manager.Behaviour

  alias Raxol.Core.Events.Manager.Server
  require Raxol.Core.Runtime.Log

  @doc """
  Ensures the Events.Manager server is started.
  Called automatically when using any function.
  """
  def ensure_started do
    case Process.whereis(Server) do
      nil ->
        {:ok, _pid} = Server.start_link()
        :ok
      _pid ->
        :ok
    end
  end

  @doc """
  Initialize the event manager.
  
  This resets the event manager state while preserving configuration.
  For backward compatibility with Process dictionary version.
  """
  def init do
    ensure_started()
    Server.init_manager()
  end

  @doc """
  Register an event handler.
  
  ## Parameters
  - `event_type` - The type of event to handle
  - `module` - The module containing the handler function
  - `function` - The function to call when the event occurs
  
  ## Examples
  ```elixir
  EventManager.register_handler(:click, MyModule, :handle_click)
  ```
  """
  def register_handler(event_type, module, function)
      when is_atom(event_type) and is_atom(module) and is_atom(function) do
    ensure_started()
    Server.register_handler(event_type, module, function)
  end

  @doc """
  Register an event handler with priority.
  
  Lower priority numbers execute first.
  Default priority is 50.
  """
  def register_handler_with_priority(event_type, module, function, priority)
      when is_atom(event_type) and is_atom(module) and is_atom(function) and is_integer(priority) do
    ensure_started()
    Server.register_handler(event_type, module, function, priority: priority)
  end

  @doc """
  Unregister an event handler.
  """
  def unregister_handler(event_type, module, function)
      when is_atom(event_type) and is_atom(module) and is_atom(function) do
    ensure_started()
    Server.unregister_handler(event_type, module, function)
  end

  @doc """
  Subscribe to events with optional filters.
  
  ## Parameters
  - `event_types` - List of event types to subscribe to
  - `opts` - Optional filters and options
  
  ## Returns
  - `{:ok, ref}` - Subscription reference for later unsubscribe
  
  ## Examples
  ```elixir
  {:ok, ref} = EventManager.subscribe([:click, :key_press])
  {:ok, ref} = EventManager.subscribe([:mouse], button: :left)
  ```
  """
  def subscribe(event_types, opts \\ []) when is_list(event_types) do
    ensure_started()
    Server.subscribe(event_types, opts)
  end

  @doc """
  Unsubscribe from events using the subscription reference.
  """
  def unsubscribe(ref) when is_integer(ref) do
    ensure_started()
    Server.unsubscribe(ref)
  end

  @doc """
  Dispatch an event to all registered handlers and subscribers.
  
  This is asynchronous - handlers are executed in a cast.
  Use `dispatch_sync/1` if you need to wait for completion.
  """
  def dispatch(event) do
    ensure_started()
    
    Raxol.Core.Runtime.Log.debug(
      "EventManager.dispatch called with event: #{inspect(event)}"
    )
    
    Server.dispatch(event)
    :ok
  end

  @doc """
  Dispatch an event synchronously.
  
  Waits for all handlers to complete before returning.
  Useful for testing or when handler completion is required.
  """
  def dispatch_sync(event) do
    ensure_started()
    Server.dispatch_sync(event)
  end

  @doc """
  Broadcast an event to all subscribers.
  
  Ignores subscription filters - all subscribers receive the event.
  """
  def broadcast(event) do
    ensure_started()
    Server.broadcast(event)
    :ok
  end

  @doc """
  Get all registered event handlers.
  
  Returns a map of event_type => [{module, function, priority}]
  """
  def get_handlers do
    ensure_started()
    Server.get_handlers()
  end

  @doc """
  Clear all event handlers.
  """
  def clear_handlers do
    ensure_started()
    Server.clear_handlers()
  end

  @doc """
  Cleans up the event manager state.
  
  Clears all handlers and subscriptions.
  For backward compatibility with Process dictionary version.
  """
  def cleanup do
    ensure_started()
    Server.clear_handlers()
    Server.clear_subscriptions()
    :ok
  end

  @doc """
  Triggers an event with a type and payload.
  
  Alias for dispatch/1 for API compatibility.
  """
  def trigger(event_type, payload) do
    ensure_started()
    Server.trigger(event_type, payload)
    :ok
  end

  # Additional helper functions

  @doc """
  Get all active subscriptions.
  
  Returns a map of ref => subscription details.
  Useful for debugging and monitoring.
  """
  def get_subscriptions do
    ensure_started()
    Server.get_subscriptions()
  end

  @doc """
  Get event history (if enabled).
  
  ## Parameters
  - `limit` - Optional limit on number of events to return
  
  ## Returns
  List of {event, timestamp} tuples, newest first.
  """
  def get_event_history(limit \\ nil) do
    ensure_started()
    Server.get_event_history(limit)
  end

  @doc """
  Clear event history.
  """
  def clear_history do
    ensure_started()
    Server.clear_history()
  end

  @doc """
  Subscribe a specific process to events.
  
  Useful for subscribing other processes besides the caller.
  """
  def subscribe_process(pid, event_types, opts \\ []) 
      when is_pid(pid) and is_list(event_types) do
    ensure_started()
    Server.subscribe_pid(pid, event_types, opts)
  end

  @doc """
  Count active subscriptions.
  """
  def count_subscriptions do
    ensure_started()
    subscriptions = Server.get_subscriptions()
    map_size(subscriptions)
  end

  @doc """
  Count registered handlers.
  """
  def count_handlers do
    ensure_started()
    handlers = Server.get_handlers()
    
    Enum.reduce(handlers, 0, fn {_event_type, handler_list}, acc ->
      acc + length(handler_list)
    end)
  end

  @doc """
  Check if a specific handler is registered.
  """
  def handler_registered?(event_type, module, function) do
    ensure_started()
    handlers = Server.get_handlers()
    
    case Map.get(handlers, event_type) do
      nil -> false
      handler_list ->
        Enum.any?(handler_list, fn {m, f, _p} -> 
          m == module && f == function 
        end)
    end
  end
end