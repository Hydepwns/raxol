defmodule Raxol.Core.Events.Manager.Server do
  @moduledoc """
  GenServer implementation for event management in Raxol applications.

  This server provides a pure functional approach to event management using
  a PubSub pattern, eliminating Process dictionary usage and implementing
  proper OTP supervision patterns.

  ## Features
  - Event handler registration with module/function callbacks
  - PubSub-style subscriptions with filters
  - Broadcast and targeted event dispatching
  - Supervised state management with fault tolerance
  - Support for priority handlers
  - Event history tracking (optional)

  ## State Structure
  The server maintains state with the following structure:
  ```elixir
  %{
    handlers: %{event_type => [{module, function, priority}]},
    subscriptions: %{ref => %{pid: pid, event_types: [], filters: [], monitor_ref: ref}},
    monitors: %{monitor_ref => subscription_ref},
    event_history: [], # Optional, configurable
    config: %{
      history_limit: 100,
      enable_history: false
    }
  }
  ```

  ## Event Dispatching
  Events are dispatched in priority order (lower numbers = higher priority).
  Handlers with the same priority are executed in registration order.
  """

  use GenServer
  require Logger
  require Raxol.Core.Runtime.Log

  @default_config %{
    history_limit: 100,
    enable_history: false
  }

  @default_state %{
    handlers: %{},
    subscriptions: %{},
    monitors: %{},
    event_history: [],
    config: @default_config
  }

  # Client API

  @doc """
  Starts the Events.Manager server with optional configuration.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    config = Keyword.get(opts, :config, @default_config)
    initial_state = %{@default_state | config: Map.merge(@default_config, config)}
    GenServer.start_link(__MODULE__, initial_state, name: name)
  end

  @doc """
  Initializes the event manager (for backward compatibility).
  """
  def init_manager(server \\ __MODULE__) do
    GenServer.call(server, :init_manager)
  end

  @doc """
  Registers an event handler with optional priority.
  
  ## Parameters
  - `event_type` - The type of event to handle
  - `module` - The module containing the handler function
  - `function` - The function to call when the event occurs
  - `opts` - Options including:
    - `:priority` - Handler priority (default: 50, lower = higher priority)
  """
  def register_handler(server \\ __MODULE__, event_type, module, function, opts \\ [])
      when is_atom(event_type) and is_atom(module) and is_atom(function) do
    priority = Keyword.get(opts, :priority, 50)
    GenServer.call(server, {:register_handler, event_type, module, function, priority})
  end

  @doc """
  Unregisters an event handler.
  """
  def unregister_handler(server \\ __MODULE__, event_type, module, function)
      when is_atom(event_type) and is_atom(module) and is_atom(function) do
    GenServer.call(server, {:unregister_handler, event_type, module, function})
  end

  @doc """
  Subscribes to events with optional filters.
  
  ## Parameters
  - `event_types` - List of event types to subscribe to
  - `opts` - Optional filters and options
  
  ## Returns
  - `{:ok, ref}` - Subscription reference for later unsubscribe
  """
  def subscribe(server \\ __MODULE__, event_types, opts \\ []) when is_list(event_types) do
    GenServer.call(server, {:subscribe, self(), event_types, opts})
  end

  @doc """
  Subscribes a specific process to events.
  """
  def subscribe_pid(server \\ __MODULE__, pid, event_types, opts \\ []) 
      when is_pid(pid) and is_list(event_types) do
    GenServer.call(server, {:subscribe, pid, event_types, opts})
  end

  @doc """
  Unsubscribes from events using the subscription reference.
  """
  def unsubscribe(server \\ __MODULE__, ref) when is_integer(ref) do
    GenServer.call(server, {:unsubscribe, ref})
  end

  @doc """
  Dispatches an event to all registered handlers and subscribers.
  
  This is an asynchronous operation - use dispatch_sync for synchronous dispatch.
  """
  def dispatch(server \\ __MODULE__, event) do
    GenServer.cast(server, {:dispatch, event})
  end

  @doc """
  Dispatches an event synchronously, waiting for all handlers to complete.
  """
  def dispatch_sync(server \\ __MODULE__, event) do
    GenServer.call(server, {:dispatch_sync, event})
  end

  @doc """
  Broadcasts an event to all subscribers regardless of filters.
  """
  def broadcast(server \\ __MODULE__, event) do
    GenServer.cast(server, {:broadcast, event})
  end

  @doc """
  Gets all registered event handlers.
  """
  def get_handlers(server \\ __MODULE__) do
    GenServer.call(server, :get_handlers)
  end

  @doc """
  Gets all active subscriptions.
  """
  def get_subscriptions(server \\ __MODULE__) do
    GenServer.call(server, :get_subscriptions)
  end

  @doc """
  Gets event history (if enabled).
  """
  def get_event_history(server \\ __MODULE__, limit \\ nil) do
    GenServer.call(server, {:get_event_history, limit})
  end

  @doc """
  Clears all event handlers.
  """
  def clear_handlers(server \\ __MODULE__) do
    GenServer.call(server, :clear_handlers)
  end

  @doc """
  Clears all subscriptions.
  """
  def clear_subscriptions(server \\ __MODULE__) do
    GenServer.call(server, :clear_subscriptions)
  end

  @doc """
  Clears event history.
  """
  def clear_history(server \\ __MODULE__) do
    GenServer.call(server, :clear_history)
  end

  @doc """
  Gets the current state (for debugging/testing).
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  @doc """
  Triggers an event with type and payload (compatibility alias).
  """
  def trigger(server \\ __MODULE__, event_type, payload) do
    dispatch(server, {event_type, payload})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl GenServer
  def handle_call(:init_manager, _from, state) do
    # Reset to initial state while preserving config
    new_state = %{@default_state | config: state.config}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:register_handler, event_type, module, function, priority}, _from, state) do
    handler = {module, function, priority}
    
    current_handlers = Map.get(state.handlers, event_type, [])
    
    # Check if handler already exists
    updated_handlers = 
      if Enum.any?(current_handlers, fn {m, f, _p} -> m == module && f == function end) do
        # Update priority if handler exists
        current_handlers
        |> Enum.reject(fn {m, f, _p} -> m == module && f == function end)
        |> Kernel.++([handler])
      else
        [handler | current_handlers]
      end
      |> Enum.sort_by(fn {_m, _f, p} -> p end)
    
    new_handlers = Map.put(state.handlers, event_type, updated_handlers)
    new_state = %{state | handlers: new_handlers}
    
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unregister_handler, event_type, module, function}, _from, state) do
    current_handlers = Map.get(state.handlers, event_type, [])
    
    updated_handlers = 
      Enum.reject(current_handlers, fn {m, f, _p} -> m == module && f == function end)
    
    new_handlers = 
      if updated_handlers == [] do
        Map.delete(state.handlers, event_type)
      else
        Map.put(state.handlers, event_type, updated_handlers)
      end
    
    new_state = %{state | handlers: new_handlers}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:subscribe, pid, event_types, opts}, _from, state) do
    ref = System.unique_integer([:positive])
    
    # Monitor the subscribing process
    monitor_ref = Process.monitor(pid)
    
    subscription = %{
      pid: pid,
      event_types: event_types,
      filters: opts,
      monitor_ref: monitor_ref
    }
    
    new_subscriptions = Map.put(state.subscriptions, ref, subscription)
    new_monitors = Map.put(state.monitors, monitor_ref, ref)
    
    new_state = %{state | subscriptions: new_subscriptions, monitors: new_monitors}
    {:reply, {:ok, ref}, new_state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, ref}, _from, state) do
    case Map.get(state.subscriptions, ref) do
      nil ->
        {:reply, {:error, :not_found}, state}
      
      subscription ->
        # Stop monitoring
        Process.demonitor(subscription.monitor_ref, [:flush])
        
        new_subscriptions = Map.delete(state.subscriptions, ref)
        new_monitors = Map.delete(state.monitors, subscription.monitor_ref)
        
        new_state = %{state | subscriptions: new_subscriptions, monitors: new_monitors}
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:dispatch_sync, event}, _from, state) do
    new_state = do_dispatch(state, event)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_handlers, _from, state) do
    {:reply, state.handlers, state}
  end

  @impl GenServer
  def handle_call(:get_subscriptions, _from, state) do
    {:reply, state.subscriptions, state}
  end

  @impl GenServer
  def handle_call({:get_event_history, limit}, _from, state) do
    history = 
      if limit do
        Enum.take(state.event_history, limit)
      else
        state.event_history
      end
    
    {:reply, history, state}
  end

  @impl GenServer
  def handle_call(:clear_handlers, _from, state) do
    new_state = %{state | handlers: %{}}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:clear_subscriptions, _from, state) do
    # Demonitor all subscriptions
    Enum.each(state.subscriptions, fn {_ref, sub} ->
      Process.demonitor(sub.monitor_ref, [:flush])
    end)
    
    new_state = %{state | subscriptions: %{}, monitors: %{}}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:clear_history, _from, state) do
    new_state = %{state | event_history: []}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_cast({:dispatch, event}, state) do
    new_state = do_dispatch(state, event)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:broadcast, event}, state) do
    # Send to all subscribers without filtering
    Enum.each(state.subscriptions, fn {_ref, subscription} ->
      send(subscription.pid, {:event, event})
    end)
    
    new_state = maybe_record_event(state, event)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:DOWN, monitor_ref, :process, _pid, _reason}, state) do
    # Clean up subscription when process dies
    case Map.get(state.monitors, monitor_ref) do
      nil ->
        {:noreply, state}
      
      subscription_ref ->
        new_subscriptions = Map.delete(state.subscriptions, subscription_ref)
        new_monitors = Map.delete(state.monitors, monitor_ref)
        
        new_state = %{state | subscriptions: new_subscriptions, monitors: new_monitors}
        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Helper Functions

  defp do_dispatch(state, event) do
    event_type = extract_event_type(event)
    
    Raxol.Core.Runtime.Log.debug(
      "EventManager.Server dispatching event: #{inspect(event)}, type: #{inspect(event_type)}"
    )
    
    # Execute handlers in priority order
    handlers = Map.get(state.handlers, event_type, [])
    
    Raxol.Core.Runtime.Log.debug(
      "Found #{length(handlers)} handlers for event type #{inspect(event_type)}"
    )
    
    Enum.each(handlers, fn {module, function, _priority} ->
      try do
        Raxol.Core.Runtime.Log.debug(
          "Calling handler: #{inspect(module)}.#{inspect(function)}"
        )
        apply(module, function, [event])
      rescue
        error ->
          Logger.error("Event handler #{module}.#{function} failed: #{inspect(error)}")
      end
    end)
    
    # Notify matching subscribers
    Enum.each(state.subscriptions, fn {_ref, subscription} ->
      if event_type in subscription.event_types && matches_filters?(event, subscription.filters) do
        send(subscription.pid, {:event, event})
      end
    end)
    
    maybe_record_event(state, event)
  end

  defp maybe_record_event(state, event) do
    if state.config.enable_history do
      history = [{event, DateTime.utc_now()} | state.event_history]
      limited_history = Enum.take(history, state.config.history_limit)
      %{state | event_history: limited_history}
    else
      state
    end
  end

  defp extract_event_type(event) when is_tuple(event) and tuple_size(event) > 0 do
    elem(event, 0)
  end

  defp extract_event_type(event) when is_atom(event), do: event
  defp extract_event_type(_), do: :unknown

  defp matches_filters?(_event, []), do: true

  defp matches_filters?(event, filters) do
    Enum.all?(filters, fn {key, value} ->
      case event do
        {_type, data} when is_map(data) -> 
          Map.get(data, key) == value
        _ -> 
          false
      end
    end)
  end
end