defmodule Raxol.UI.State.Store do
  @moduledoc """
  Global state management store with reactive patterns for Raxol UI.

  The Store provides a centralized state management solution with:
  - Immutable state updates
  - Action-based state changes (Redux-like)
  - Reactive subscriptions
  - Middleware support for logging, persistence, etc.
  - Time-travel debugging capabilities
  - Optimistic updates
  - State persistence

  ## Usage

      # Define actions
      defmodule CounterActions do
        def increment, do: {:counter, :increment}
        def decrement, do: {:counter, :decrement}
        def set(value), do: {:counter, :set, value}
      end
      
      # Define reducer
      defmodule CounterReducer do
        def reduce({:counter, :increment}, state) do
          put_in(state, [:counter], Map.get(state, :counter, 0) + 1)
        end
        
        def reduce({:counter, :decrement}, state) do
          put_in(state, [:counter], Map.get(state, :counter, 0) - 1)
        end
        
        def reduce({:counter, :set, value}, state) do
          put_in(state, [:counter], value)
        end
        
        def reduce(_action, state), do: state
      end
      
      # Use the store
      Store.dispatch(CounterActions.increment())
      counter_value = Store.get_state([:counter])
      
      # Subscribe to changes
      unsubscribe = Store.subscribe([:counter], fn new_value ->
        IO.puts("Counter changed to: \#{new_value}")
      end)
  """

  use GenServer
  require Logger

  # Store state structure
  defmodule State do
    defstruct [
      :data,
      :subscribers,
      :middleware,
      :reducers,
      :history,
      :future,
      :max_history_size,
      :paused
    ]

    def new(initial_data \\ %{}) do
      %__MODULE__{
        data: initial_data,
        subscribers: %{},
        middleware: [],
        reducers: [],
        history: [],
        future: [],
        max_history_size: 50,
        paused: false
      }
    end
  end

  # Subscription structure
  defmodule Subscription do
    defstruct [:id, :path, :callback, :options]

    def new(id, path, callback, options \\ []) do
      %__MODULE__{
        id: id,
        path: path,
        callback: callback,
        options: options
      }
    end
  end

  # Action structure for history/debugging
  defmodule Action do
    defstruct [:type, :payload, :timestamp, :meta]

    def new(type, payload \\ nil, meta \\ %{}) do
      %__MODULE__{
        type: type,
        payload: payload,
        timestamp: System.monotonic_time(:millisecond),
        meta: meta
      }
    end
  end

  ## Public API

  @doc """
  Starts the global state store.
  """
  def start_link(initial_state \\ %{}, opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      initial_state,
      Keyword.put_new(opts, :name, __MODULE__)
    )
  end

  @doc """
  Dispatches an action to update the store.

  ## Examples

      Store.dispatch({:user, :login, user_data})
      Store.dispatch({:theme, :toggle})
      Store.dispatch({:counter, :increment})
  """
  def dispatch(action, store \\ __MODULE__) do
    GenServer.call(store, {:dispatch, action})
  end

  @doc """
  Gets the current state or a value at a specific path.

  ## Examples

      # Get entire state
      state = Store.get_state()
      
      # Get value at path
      counter = Store.get_state([:counter])
      user = Store.get_state([:user, :current])
  """
  def get_state(path \\ [], store \\ __MODULE__) do
    GenServer.call(store, {:get_state, path})
  end

  @doc """
  Updates state at a specific path directly (use sparingly - prefer dispatch).

  ## Examples

      Store.update_state([:counter], 42)
      Store.update_state([:user, :name], "John Doe")
  """
  def update_state(path, value, store \\ __MODULE__) do
    GenServer.call(store, {:update_state, path, value})
  end

  @doc """
  Deletes state at a specific path.

  ## Examples

      Store.delete_state([:temporary_data])
      Store.delete_state([:cache, :expired_item])
  """
  def delete_state(path, store \\ __MODULE__) do
    GenServer.call(store, {:delete_state, path})
  end

  @doc """
  Subscribes to state changes at a specific path.

  ## Examples

      # Subscribe to counter changes
      unsubscribe = Store.subscribe([:counter], fn new_value ->
        IO.puts("Counter: \#{new_value}")
      end)
      
      # Subscribe with options
      unsubscribe = Store.subscribe([:user], fn user ->
        update_ui(user)
      end, debounce: 100)
      
      # Unsubscribe
      unsubscribe.()
  """
  def subscribe(path, callback, options \\ [], store \\ __MODULE__)
      when is_function(callback, 1) do
    subscription_id = System.unique_integer([:positive, :monotonic])

    GenServer.call(
      store,
      {:subscribe, subscription_id, path, callback, options}
    )

    # Return unsubscribe function
    fn -> unsubscribe(subscription_id, store) end
  end

  @doc """
  Unsubscribes from state changes.
  """
  def unsubscribe(subscription_id, store \\ __MODULE__) do
    GenServer.call(store, {:unsubscribe, subscription_id})
  end

  @doc """
  Registers a reducer function for handling actions.

  ## Examples

      Store.register_reducer(fn
        {:counter, :increment}, state ->
          update_in(state, [:counter], &((&1 || 0) + 1))
        
        {:counter, :decrement}, state ->
          update_in(state, [:counter], &((&1 || 0) - 1))
        
        _action, state ->
          state
      end)
  """
  def register_reducer(reducer_fn, store \\ __MODULE__)
      when is_function(reducer_fn, 2) do
    GenServer.call(store, {:register_reducer, reducer_fn})
  end

  @doc """
  Registers middleware for intercepting actions.

  ## Examples

      # Logging middleware
      Store.register_middleware(fn action, state, next ->
        Logger.info("Action: \#{inspect(action)}")
        result = next.(action, state)
        Logger.info("New state: \#{inspect(result)}")
        result
      end)
      
      # Persistence middleware
      Store.register_middleware(fn action, state, next ->
        result = next.(action, state)
        persist_state(result)
        result
      end)
  """
  def register_middleware(middleware_fn, store \\ __MODULE__)
      when is_function(middleware_fn, 3) do
    GenServer.call(store, {:register_middleware, middleware_fn})
  end

  @doc """
  Enables/disables time-travel debugging.
  """
  def set_time_travel(enabled, store \\ __MODULE__) do
    GenServer.call(store, {:set_time_travel, enabled})
  end

  @doc """
  Travels back in time to a previous state.
  """
  def time_travel_back(steps \\ 1, store \\ __MODULE__) do
    GenServer.call(store, {:time_travel_back, steps})
  end

  @doc """
  Travels forward in time (undo a time travel back).
  """
  def time_travel_forward(steps \\ 1, store \\ __MODULE__) do
    GenServer.call(store, {:time_travel_forward, steps})
  end

  @doc """
  Gets the action history for debugging.
  """
  def get_history(store \\ __MODULE__) do
    GenServer.call(store, :get_history)
  end

  @doc """
  Pauses/resumes store updates (useful for batch operations).
  """
  def pause_updates(paused \\ true, store \\ __MODULE__) do
    GenServer.call(store, {:pause_updates, paused})
  end

  @doc """
  Performs a batch update with multiple actions.

  ## Examples

      Store.batch_update([
        {:counter, :increment},
        {:user, :set_name, "John"},
        {:theme, :toggle}
      ])
  """
  def batch_update(actions, store \\ __MODULE__) when is_list(actions) do
    GenServer.call(store, {:batch_update, actions})
  end

  @doc """
  Creates a derived state selector with memoization.

  ## Examples

      # Create a selector for total price
      total_selector = Store.create_selector(
        [[:cart, :items], [:tax_rate]],
        fn items, tax_rate ->
          subtotal = Enum.reduce(items, 0, &(&1.price * &1.quantity + &2))
          subtotal * (1 + tax_rate)
        end
      )
      
      # Use the selector
      total = total_selector.()
  """
  def create_selector(paths, compute_fn, store \\ __MODULE__)
      when is_list(paths) and is_function(compute_fn) do
    fn ->
      values = Enum.map(paths, &get_state(&1, store))
      apply(compute_fn, values)
    end
  end

  ## GenServer Implementation

  @impl GenServer
  def init(initial_state) do
    state = State.new(initial_state)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:dispatch, action}, _from, state) do
    if state.paused do
      {:reply, :ok, state}
    else
      action_struct = Action.new(action, nil, %{source: :dispatch})
      new_state = apply_action(action_struct, state)
      {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_state, path}, _from, state) do
    value = get_in(state.data, path)
    {:reply, value, state}
  end

  @impl GenServer
  def handle_call({:update_state, path, value}, _from, state) do
    new_data = put_in(state.data, path, value)
    new_state = %{state | data: new_data}

    # Notify subscribers
    notify_subscribers(path, value, new_state)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:delete_state, path}, _from, state) do
    new_data = delete_in(state.data, path)
    new_state = %{state | data: new_data}

    # Notify subscribers
    notify_subscribers(path, nil, new_state)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:subscribe, id, path, callback, options}, _from, state) do
    subscription = Subscription.new(id, path, callback, options)
    new_subscribers = Map.put(state.subscribers, id, subscription)
    new_state = %{state | subscribers: new_subscribers}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, id}, _from, state) do
    new_subscribers = Map.delete(state.subscribers, id)
    new_state = %{state | subscribers: new_subscribers}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:register_reducer, reducer_fn}, _from, state) do
    new_reducers = [reducer_fn | state.reducers]
    new_state = %{state | reducers: new_reducers}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:register_middleware, middleware_fn}, _from, state) do
    new_middleware = [middleware_fn | state.middleware]
    new_state = %{state | middleware: new_middleware}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_time_travel, enabled}, _from, state) do
    # Time travel is enabled when max_history_size > 0
    new_max_size = if enabled, do: 50, else: 0
    new_state = %{state | max_history_size: new_max_size}

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:time_travel_back, steps}, _from, state) do
    {new_state, traveled_steps} = time_travel_backward(state, steps)
    {:reply, traveled_steps, new_state}
  end

  @impl GenServer
  def handle_call({:time_travel_forward, steps}, _from, state) do
    {new_state, traveled_steps} = time_travel_forward_impl(state, steps)
    {:reply, traveled_steps, new_state}
  end

  @impl GenServer
  def handle_call(:get_history, _from, state) do
    {:reply, state.history, state}
  end

  @impl GenServer
  def handle_call({:pause_updates, paused}, _from, state) do
    new_state = %{state | paused: paused}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:batch_update, actions}, _from, state) do
    if state.paused do
      {:reply, :ok, state}
    else
      new_state =
        Enum.reduce(actions, state, fn action, acc_state ->
          action_struct = Action.new(action, nil, %{source: :batch})
          apply_action(action_struct, acc_state)
        end)

      {:reply, :ok, new_state}
    end
  end

  ## Private Implementation

  defp apply_action(action, state) do
    # Store current state in history if time travel is enabled
    new_state =
      if state.max_history_size > 0 do
        add_to_history(state, action)
      else
        state
      end

    # Apply middleware chain
    final_data =
      apply_middleware_chain(
        action,
        new_state.data,
        new_state.middleware,
        new_state.reducers
      )

    updated_state = %{new_state | data: final_data}

    # Notify all relevant subscribers
    notify_all_subscribers(updated_state)

    updated_state
  end

  defp apply_middleware_chain(action, data, middleware, reducers) do
    # Create the final handler that applies reducers
    final_handler = fn action_inner, data_inner ->
      apply_reducers(action_inner, data_inner, reducers)
    end

    # Build middleware chain
    handler =
      Enum.reduce(middleware, final_handler, fn middleware_fn, next_handler ->
        fn action_inner, data_inner ->
          middleware_fn.(action_inner, data_inner, next_handler)
        end
      end)

    # Execute the chain
    handler.(action, data)
  end

  defp apply_reducers(action, data, reducers) do
    Enum.reduce(reducers, data, fn reducer_fn, acc_data ->
      try do
        reducer_fn.(action, acc_data)
      catch
        kind, reason ->
          Logger.error("Error in reducer: #{inspect(kind)}, #{inspect(reason)}")
          # Return unchanged data on error
          acc_data
      end
    end)
  end

  defp add_to_history(state, action) do
    # Add current state to history
    history_entry = %{
      state: state.data,
      action: action,
      timestamp: action.timestamp
    }

    new_history =
      [history_entry | state.history]
      |> Enum.take(state.max_history_size)

    # Clear future when new action is applied
    %{state | history: new_history, future: []}
  end

  defp time_travel_backward(state, steps) do
    available_steps = min(steps, length(state.history))

    if available_steps == 0 do
      {state, 0}
    else
      # Move states from history to future
      {history_to_move, remaining_history} =
        Enum.split(state.history, available_steps)

      # The target state is the last in the history we're moving
      target_state_data =
        case List.last(history_to_move) do
          %{state: state_data} -> state_data
          _ -> state.data
        end

      # Add current state to future
      current_entry = %{
        state: state.data,
        action: Action.new(:time_travel_back, available_steps),
        timestamp: System.monotonic_time(:millisecond)
      }

      new_future = [current_entry | history_to_move] ++ state.future

      new_state = %{
        state
        | data: target_state_data,
          history: remaining_history,
          future: new_future
      }

      # Notify subscribers of the state change
      notify_all_subscribers(new_state)

      {new_state, available_steps}
    end
  end

  defp time_travel_forward_impl(state, steps) do
    available_steps = min(steps, length(state.future))

    if available_steps == 0 do
      {state, 0}
    else
      # Move states from future to history
      {future_to_move, remaining_future} =
        Enum.split(state.future, available_steps)

      # The target state is the last in the future we're moving
      target_state_data =
        case List.last(future_to_move) do
          %{state: state_data} -> state_data
          _ -> state.data
        end

      # Add current state to history
      current_entry = %{
        state: state.data,
        action: Action.new(:time_travel_forward, available_steps),
        timestamp: System.monotonic_time(:millisecond)
      }

      new_history = [current_entry | future_to_move] ++ state.history

      new_state = %{
        state
        | data: target_state_data,
          history: new_history,
          future: remaining_future
      }

      # Notify subscribers of the state change
      notify_all_subscribers(new_state)

      {new_state, available_steps}
    end
  end

  defp notify_all_subscribers(state) do
    Enum.each(state.subscribers, fn {_id, subscription} ->
      notify_subscriber_if_relevant(subscription, state.data)
    end)
  end

  defp notify_subscribers(changed_path, new_value, state) do
    Enum.each(state.subscribers, fn {_id, subscription} ->
      if path_affects_subscription?(changed_path, subscription.path) do
        notify_subscriber(subscription, new_value)
      end
    end)
  end

  defp notify_subscriber_if_relevant(subscription, full_state) do
    current_value = get_in(full_state, subscription.path)
    notify_subscriber(subscription, current_value)
  end

  defp notify_subscriber(subscription, value) do
    # Apply debouncing if specified
    debounce_ms = Keyword.get(subscription.options, :debounce, 0)

    if debounce_ms > 0 do
      # Simple debouncing implementation
      timer_key = {:debounce, subscription.id}

      # Cancel existing timer
      case Process.get(timer_key) do
        nil -> :ok
        timer_ref -> Process.cancel_timer(timer_ref)
      end

      # Set new timer
      timer_ref =
        Process.send_after(
          self(),
          {:notify_subscriber, subscription, value},
          debounce_ms
        )

      Process.put(timer_key, timer_ref)
    else
      # Immediate notification
      execute_callback(subscription.callback, value)
    end
  end

  @impl GenServer
  def handle_info({:notify_subscriber, subscription, value}, state) do
    # Clean up timer reference
    timer_key = {:debounce, subscription.id}
    Process.delete(timer_key)

    # Execute callback
    execute_callback(subscription.callback, value)

    {:noreply, state}
  end

  defp execute_callback(callback, value) do
    try do
      callback.(value)
    catch
      kind, reason ->
        Logger.error(
          "Error in subscriber callback: #{inspect(kind)}, #{inspect(reason)}"
        )
    end
  end

  defp path_affects_subscription?(changed_path, subscription_path) do
    # Check if the changed path affects the subscription
    # This is true if either path is a prefix of the other
    starts_with_path?(changed_path, subscription_path) or
      starts_with_path?(subscription_path, changed_path)
  end

  defp starts_with_path?([], _), do: true
  defp starts_with_path?(_, []), do: true
  defp starts_with_path?([h | t1], [h | t2]), do: starts_with_path?(t1, t2)
  defp starts_with_path?(_, _), do: false

  defp delete_in(_data, []) do
    # Delete everything
    %{}
  end

  defp delete_in(data, [key]) when is_map(data) do
    Map.delete(data, key)
  end

  defp delete_in(data, [key | rest]) when is_map(data) do
    case Map.get(data, key) do
      nil -> data
      nested -> Map.put(data, key, delete_in(nested, rest))
    end
  end

  defp delete_in(data, _path) do
    # Can't delete from non-map
    data
  end
end
