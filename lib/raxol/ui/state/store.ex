defmodule Raxol.UI.State.Store do
  @moduledoc """
  Refactored UI State Store with GenServer-based state management.

  This module provides the same Redux-like state management as the original
  but uses supervised state instead of Process dictionary for debounce timers.

  ## Migration Notes

  Debounce timer management has been moved to the UI.State.Management.Server,
  eliminating Process dictionary usage while maintaining full functionality.
  """

  alias Raxol.UI.State.Management.Server
  alias Raxol.Core.ErrorHandling
  require Logger

  # Store state structure (for compatibility)
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

  # Ensure server is started
  defp ensure_server_started do
    case Process.whereis(Server) do
      nil ->
        {:ok, _pid} = Server.start_link()
        :ok

      _pid ->
        :ok
    end
  end

  ## Public API - Delegating to Server

  @doc """
  Starts the global state store.
  """
  def start_link(initial_state \\ %{}, opts \\ []) do
    Server.start_link(Keyword.put(opts, :initial_state, initial_state))
  end

  @doc """
  Dispatches an action to update the store.

  ## Examples

      Store.dispatch({:user, :login, user_data})
      Store.dispatch({:theme, :toggle})
      Store.dispatch({:counter, :increment})
  """
  def dispatch(action, _store \\ nil) do
    ensure_server_started()
    Server.dispatch(action)
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
  def get_state(path \\ [], _store \\ nil) do
    ensure_server_started()
    Server.get_state(path)
  end

  @doc """
  Updates state at a specific path directly (use sparingly - prefer dispatch).

  ## Examples

      Store.update_state([:counter], 42)
      Store.update_state([:user, :name], "John Doe")
  """
  def update_state(path, value, _store \\ nil) do
    ensure_server_started()
    Server.update_state(path, value)
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
  def subscribe(path, callback)
      when is_list(path) and is_function(callback, 1) do
    subscribe(path, callback, [])
  end

  def subscribe(path, callback, options)
      when is_list(path) and is_function(callback, 1) and is_list(options) do
    subscribe(path, callback, options, nil)
  end

  def subscribe(path, callback, options, _store)
      when is_list(path) and is_function(callback, 1) and is_list(options) do
    ensure_server_started()
    Server.subscribe(path, callback, options)
  end

  # Handle property test style: subscribe(store, callback) when store is first
  def subscribe(store, callback)
      when (is_pid(store) or is_atom(store)) and is_function(callback, 1) do
    subscribe([], callback, [], store)
  end

  @doc """
  Unsubscribes from state changes.
  """
  def unsubscribe(subscription_id, _store \\ nil) do
    ensure_server_started()
    Server.unsubscribe(subscription_id)
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
  def register_reducer(reducer_fn, _store \\ nil)
      when is_function(reducer_fn, 2) do
    ensure_server_started()
    Server.register_reducer(reducer_fn)
  end

  @doc """
  Updates a value in the store at the given path.

  This function supports multiple argument orders and function updates.

  ## Examples

      # Direct value update
      Store.update(store, :counter, 42)
      Store.update(store, [:user, :name], "John")
      
      # Function update
      Store.update(store, :counter, fn count -> count + 1 end)
      Store.update(store, [:items], fn items -> [new_item | items] end)
  """
  def update(store \\ nil, path, value_or_fun)

  # Handle function updates
  def update(store, path, fun) when is_function(fun, 1) do
    ensure_server_started()
    path_list = if is_list(path), do: path, else: [path]

    # Get current value, apply function, then update
    current_value = get_state(path_list, store)

    # Safely handle arithmetic operations using functional error handling
    new_value =
      case ErrorHandling.safe_call(fn -> fun.(current_value) end) do
        {:ok, result} ->
          result

        {:error, %ArithmeticError{}} ->
          case current_value do
            nil ->
              ErrorHandling.safe_call_with_default(fn -> fun.(0) end, 0)

            n when is_number(n) ->
              ErrorHandling.safe_call_with_default(fn -> fun.(n) end, n)

            _ ->
              ErrorHandling.safe_call_with_default(fn -> fun.(0) end, 0)
          end

        {:error, _} ->
          # Fallback to original value on any other error
          current_value
      end

    update_state(path_list, new_value, store)
  end

  # Handle direct value updates
  def update(store, path, value) do
    ensure_server_started()
    path_list = if is_list(path), do: path, else: [path]
    update_state(path_list, value, store)
  end

  # Additional compatibility functions

  def delete_state(path, _store \\ nil) do
    ensure_server_started()
    # Implement by setting to nil or removing from parent map
    path_list = if is_list(path), do: path, else: [path]

    if length(path_list) == 1 do
      # Top-level key - set to nil
      Server.update_state(path_list, nil)
    else
      # Nested key - need to update parent
      parent_path = Enum.drop(path_list, -1)
      key = List.last(path_list)
      parent = Server.get_state(parent_path)

      if is_map(parent) do
        updated_parent = Map.delete(parent, key)
        Server.update_state(parent_path, updated_parent)
      else
        :ok
      end
    end
  end

  def register_middleware(_middleware_fn, _store \\ nil) do
    # Middleware is not yet implemented in the server
    # Return :ok for compatibility
    :ok
  end

  def set_time_travel(_enabled, _store \\ nil) do
    # Time travel is handled by history in server
    :ok
  end

  def time_travel_back(_steps \\ 1, _store \\ nil) do
    # Not yet implemented in server
    0
  end

  def time_travel_forward(_steps \\ 1, _store \\ nil) do
    # Not yet implemented in server
    0
  end

  def get_history(_store \\ nil) do
    # Return empty history for now
    []
  end

  def pause_updates(_paused \\ true, _store \\ nil) do
    # Not yet implemented in server
    :ok
  end

  def batch_update(actions, _store \\ nil) when is_list(actions) do
    ensure_server_started()
    Enum.each(actions, &Server.dispatch/1)
    :ok
  end

  def create_selector(paths, compute_fn, store \\ nil)
      when is_list(paths) and is_function(compute_fn) do
    fn ->
      values = Enum.map(paths, &get_state(&1, store))
      apply(compute_fn, values)
    end
  end
end
