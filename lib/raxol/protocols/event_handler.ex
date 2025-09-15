defprotocol Raxol.Protocols.EventHandler do
  @moduledoc """
  Protocol for handling events in a polymorphic way.

  This protocol provides a unified interface for different types of components
  to handle events. It supports event filtering, handling, and bubbling.

  ## Event Structure

  Events are maps with at least the following keys:
    * `:type` - The event type (atom)
    * `:target` - The target of the event
    * `:timestamp` - When the event occurred
    * `:data` - Event-specific data

  ## Examples

      defimpl Raxol.Protocols.EventHandler, for: MyComponent do
        def handle_event(component, %{type: :click} = event, state) do
          # Handle click event
          {:ok, updated_component, new_state}
        end

        def handle_event(component, _event, state) do
          # Ignore other events
          {:unhandled, component, state}
        end

        def can_handle?(component, %{type: type}) do
          type in [:click, :keypress, :focus]
        end

        def get_event_listeners(component) do
          [:click, :keypress, :focus]
        end
      end
  """

  @type event :: %{
          type: atom(),
          target: any(),
          timestamp: integer(),
          data: map()
        }

  @type handler_result ::
          {:ok, t, any()}
          | {:error, term()}
          | {:unhandled, t, any()}
          | {:stop, t, any()}
          | {:bubble, t, any()}

  @doc """
  Handles an event.

  ## Parameters
    * `handler` - The handler receiving the event
    * `event` - The event to handle
    * `state` - Current state

  ## Returns
    * `{:ok, updated_handler, new_state}` - Event handled successfully
    * `{:error, reason}` - Error handling the event
    * `{:unhandled, handler, state}` - Event not handled
    * `{:stop, handler, state}` - Stop event propagation
    * `{:bubble, handler, state}` - Bubble event to parent
  """
  @spec handle_event(t, event(), any()) :: handler_result()
  def handle_event(handler, event, state)

  @doc """
  Determines if the handler can handle a specific event.

  ## Parameters
    * `handler` - The handler to check
    * `event` - The event to check

  ## Returns
  `true` if the handler can handle the event, `false` otherwise.
  """
  @spec can_handle?(t, event()) :: boolean()
  def can_handle?(handler, event)

  @doc """
  Gets the list of event types this handler listens to.

  ## Returns
  A list of event type atoms.
  """
  @spec get_event_listeners(t) :: [atom()]
  def get_event_listeners(handler)

  @doc """
  Subscribes to specific event types.

  ## Parameters
    * `handler` - The handler
    * `event_types` - List of event types to subscribe to

  ## Returns
  The updated handler.
  """
  @spec subscribe(t, [atom()]) :: t
  def subscribe(handler, event_types)

  @doc """
  Unsubscribes from specific event types.

  ## Parameters
    * `handler` - The handler
    * `event_types` - List of event types to unsubscribe from

  ## Returns
  The updated handler.
  """
  @spec unsubscribe(t, [atom()]) :: t
  def unsubscribe(handler, event_types)
end

# Implementation for GenServer processes
defimpl Raxol.Protocols.EventHandler, for: PID do
  def handle_event(pid, event, _state) when is_pid(pid) do
    case GenServer.call(pid, {:handle_event, event}, 5000) do
      {:ok, result} -> {:ok, pid, result}
      {:error, reason} -> {:error, reason}
      :unhandled -> {:unhandled, pid, nil}
    end
  rescue
    _ -> {:error, :process_unavailable}
  end

  def can_handle?(pid, event) when is_pid(pid) do
    case Process.info(pid) do
      nil -> false
      _ ->
        try do
          GenServer.call(pid, {:can_handle?, event}, 1000)
        rescue
          _ -> false
        end
    end
  end

  def get_event_listeners(pid) when is_pid(pid) do
    try do
      GenServer.call(pid, :get_event_listeners, 1000)
    rescue
      _ -> []
    end
  end

  def subscribe(pid, event_types) when is_pid(pid) do
    GenServer.cast(pid, {:subscribe, event_types})
    pid
  end

  def unsubscribe(pid, event_types) when is_pid(pid) do
    GenServer.cast(pid, {:unsubscribe, event_types})
    pid
  end
end

# Implementation for Maps (component-like structures)
defimpl Raxol.Protocols.EventHandler, for: Map do
  def handle_event(map, event, state) do
    handlers = Map.get(map, :event_handlers, %{})
    handler = Map.get(handlers, event.type)

    case handler do
      nil ->
        {:unhandled, map, state}

      fun when is_function(fun, 3) ->
        fun.(map, event, state)

      fun when is_function(fun, 2) ->
        case fun.(event, state) do
          {:ok, new_state} -> {:ok, map, new_state}
          other -> other
        end

      _ ->
        {:unhandled, map, state}
    end
  end

  def can_handle?(map, event) do
    handlers = Map.get(map, :event_handlers, %{})
    Map.has_key?(handlers, event.type)
  end

  def get_event_listeners(map) do
    map
    |> Map.get(:event_handlers, %{})
    |> Map.keys()
  end

  def subscribe(map, event_types) do
    listeners = Map.get(map, :subscribed_events, [])
    new_listeners = Enum.uniq(listeners ++ event_types)
    Map.put(map, :subscribed_events, new_listeners)
  end

  def unsubscribe(map, event_types) do
    listeners = Map.get(map, :subscribed_events, [])
    new_listeners = listeners -- event_types
    Map.put(map, :subscribed_events, new_listeners)
  end
end

# Implementation for Functions (simple event handlers)
defimpl Raxol.Protocols.EventHandler, for: Function do
  def handle_event(fun, event, state) when is_function(fun, 3) do
    fun.(fun, event, state)
  end

  def handle_event(fun, event, state) when is_function(fun, 2) do
    case fun.(event, state) do
      {:ok, new_state} -> {:ok, fun, new_state}
      other -> other
    end
  end

  def handle_event(fun, _event, state) do
    {:unhandled, fun, state}
  end

  def can_handle?(fun, _event) when is_function(fun) do
    true  # Functions can potentially handle any event
  end

  def get_event_listeners(_fun) do
    [:all]  # Functions listen to all events by default
  end

  def subscribe(fun, _event_types) do
    fun  # Functions don't maintain subscription state
  end

  def unsubscribe(fun, _event_types) do
    fun  # Functions don't maintain subscription state
  end
end