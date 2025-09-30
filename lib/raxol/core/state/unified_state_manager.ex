defmodule Raxol.Core.State.UnifiedStateManager do
  @moduledoc """
  Unified state management system for the Raxol application.
  Consolidates multiple state managers into a single, coherent interface.
  """

  use Raxol.Core.Behaviours.BaseManager

  require Logger

  @type state_key :: atom() | String.t()
  @type state_value :: any()
  @type namespace :: atom()

  defstruct [
    # %{namespace => %{key => value}}
    :states,
    # %{namespace => [pid()]}
    :subscribers,
    # persistence configuration
    :persistence,
    # %{namespace => validation_function}
    :validators,
    # %{namespace => transformation_function}
    :transformers
  ]

  ## Client API

  @doc """
  Gets a value from the specified namespace and key.
  """
  @spec get(GenServer.server(), namespace(), state_key()) ::
          {:ok, state_value()} | {:error, :not_found}
  def get(server \\ __MODULE__, namespace, key) do
    GenServer.call(server, {:get, namespace, key})
  end

  @doc """
  Sets a value in the specified namespace and key.
  """
  @spec set(GenServer.server(), namespace(), state_key(), state_value()) ::
          :ok | {:error, any()}
  def set(server \\ __MODULE__, namespace, key, value) do
    GenServer.call(server, {:set, namespace, key, value})
  end

  @doc """
  Gets all state for a namespace.
  """
  @spec get_namespace(GenServer.server(), namespace()) ::
          {:ok, map()} | {:error, :not_found}
  def get_namespace(server \\ __MODULE__, namespace) do
    GenServer.call(server, {:get_namespace, namespace})
  end

  @doc """
  Sets all state for a namespace.
  """
  @spec set_namespace(GenServer.server(), namespace(), map()) ::
          :ok | {:error, any()}
  def set_namespace(server \\ __MODULE__, namespace, state) do
    GenServer.call(server, {:set_namespace, namespace, state})
  end

  @doc """
  Subscribes to state changes in a namespace.
  """
  @spec subscribe(GenServer.server(), namespace()) :: :ok
  def subscribe(server \\ __MODULE__, namespace) do
    GenServer.call(server, {:subscribe, namespace})
  end

  @doc """
  Unsubscribes from state changes in a namespace.
  """
  @spec unsubscribe(GenServer.server(), namespace()) :: :ok
  def unsubscribe(server \\ __MODULE__, namespace) do
    GenServer.call(server, {:unsubscribe, namespace})
  end

  @doc """
  Registers a validator function for a namespace.
  """
  @spec register_validator(GenServer.server(), namespace(), function()) :: :ok
  def register_validator(server \\ __MODULE__, namespace, validator_fn) do
    GenServer.call(server, {:register_validator, namespace, validator_fn})
  end

  @doc """
  Registers a transformer function for a namespace.
  """
  @spec register_transformer(GenServer.server(), namespace(), function()) :: :ok
  def register_transformer(server \\ __MODULE__, namespace, transformer_fn) do
    GenServer.call(server, {:register_transformer, namespace, transformer_fn})
  end

  @doc """
  Persists all state to storage.
  """
  @spec persist(GenServer.server()) :: :ok | {:error, any()}
  def persist(server \\ __MODULE__) do
    GenServer.call(server, :persist)
  end

  @doc """
  Loads state from storage.
  """
  @spec load(GenServer.server()) :: :ok | {:error, any()}
  def load(server \\ __MODULE__) do
    GenServer.call(server, :load)
  end

  ## BaseManager Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    state = %__MODULE__{
      states: %{},
      subscribers: %{},
      persistence: Keyword.get(opts, :persistence, %{}),
      validators: %{},
      transformers: %{}
    }

    {:ok, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get, namespace, key}, _from, state) do
    case get_in(state.states, [namespace, key]) do
      nil -> {:reply, {:error, :not_found}, state}
      value -> {:reply, {:ok, value}, state}
    end
  end

  def handle_manager_call({:set, namespace, key, value}, _from, state) do
    case validate_value(state, namespace, value) do
      :ok ->
        transformed_value = transform_value(state, namespace, value)
        new_states = put_in(state.states, [namespace, key], transformed_value)
        new_state = %{state | states: new_states}

        notify_subscribers(state, namespace, key, transformed_value)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call({:get_namespace, namespace}, _from, state) do
    case Map.get(state.states, namespace) do
      nil -> {:reply, {:error, :not_found}, state}
      namespace_state -> {:reply, {:ok, namespace_state}, state}
    end
  end

  def handle_manager_call(
        {:set_namespace, namespace, new_namespace_state},
        _from,
        state
      ) do
    case validate_namespace_state(state, namespace, new_namespace_state) do
      :ok ->
        transformed_state =
          transform_namespace_state(state, namespace, new_namespace_state)

        new_states = Map.put(state.states, namespace, transformed_state)
        new_state = %{state | states: new_states}

        notify_namespace_subscribers(state, namespace, transformed_state)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call({:subscribe, namespace}, {pid, _ref}, state) do
    new_subscribers =
      Map.update(state.subscribers, namespace, [pid], &[pid | &1])

    Process.monitor(pid)
    new_state = %{state | subscribers: new_subscribers}
    {:reply, :ok, new_state}
  end

  def handle_manager_call({:unsubscribe, namespace}, {pid, _ref}, state) do
    new_subscribers =
      Map.update(state.subscribers, namespace, [], &List.delete(&1, pid))

    new_state = %{state | subscribers: new_subscribers}
    {:reply, :ok, new_state}
  end

  def handle_manager_call(
        {:register_validator, namespace, validator_fn},
        _from,
        state
      ) do
    new_validators = Map.put(state.validators, namespace, validator_fn)
    new_state = %{state | validators: new_validators}
    {:reply, :ok, new_state}
  end

  def handle_manager_call(
        {:register_transformer, namespace, transformer_fn},
        _from,
        state
      ) do
    new_transformers = Map.put(state.transformers, namespace, transformer_fn)
    new_state = %{state | transformers: new_transformers}
    {:reply, :ok, new_state}
  end

  def handle_manager_call(:persist, _from, state) do
    case persist_state(state) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(:load, _from, state) do
    case load_state(state) do
      {:ok, new_states} ->
        new_state = %{state | states: new_states}
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove dead subscriber from all namespaces
    new_subscribers =
      Enum.reduce(state.subscribers, %{}, fn {namespace, pids}, acc ->
        Map.put(acc, namespace, List.delete(pids, pid))
      end)

    new_state = %{state | subscribers: new_subscribers}
    {:noreply, new_state}
  end

  ## Private Functions

  defp validate_value(state, namespace, value) do
    case Map.get(state.validators, namespace) do
      nil -> :ok
      validator_fn -> validator_fn.(value)
    end
  end

  defp validate_namespace_state(state, namespace, namespace_state) do
    case Map.get(state.validators, namespace) do
      nil ->
        :ok

      validator_fn ->
        Enum.reduce_while(namespace_state, :ok, fn {_key, value}, _acc ->
          case validator_fn.(value) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
    end
  end

  defp transform_value(state, namespace, value) do
    case Map.get(state.transformers, namespace) do
      nil -> value
      transformer_fn -> transformer_fn.(value)
    end
  end

  defp transform_namespace_state(state, namespace, namespace_state) do
    case Map.get(state.transformers, namespace) do
      nil ->
        namespace_state

      transformer_fn ->
        Enum.reduce(namespace_state, %{}, fn {key, value}, acc ->
          Map.put(acc, key, transformer_fn.(value))
        end)
    end
  end

  defp notify_subscribers(state, namespace, key, value) do
    case Map.get(state.subscribers, namespace) do
      nil ->
        :ok

      subscribers ->
        Enum.each(subscribers, fn pid ->
          send(pid, {:state_change, namespace, key, value})
        end)
    end
  end

  defp notify_namespace_subscribers(state, namespace, namespace_state) do
    case Map.get(state.subscribers, namespace) do
      nil ->
        :ok

      subscribers ->
        Enum.each(subscribers, fn pid ->
          send(pid, {:namespace_change, namespace, namespace_state})
        end)
    end
  end

  defp persist_state(state) do
    case state.persistence do
      %{module: module, function: function}
      when is_atom(module) and is_atom(function) ->
        apply(module, function, [state.states])

      _ ->
        Logger.warning("No persistence configuration found")
        :ok
    end
  end

  defp load_state(state) do
    case state.persistence do
      %{module: module, function: load_function}
      when is_atom(module) and is_atom(load_function) ->
        apply(module, load_function, [])

      _ ->
        Logger.warning("No persistence configuration found")
        {:ok, %{}}
    end
  end
end
