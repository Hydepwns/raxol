defmodule Raxol.Core.StateManager.Default do
  @moduledoc """
  Default implementation of the StateManager behavior using a simple map-based state.

  This implementation can be used directly or as a base for more complex
  state managers throughout the system.
  """

  @behaviour Raxol.Core.Behaviours.StateManager

  @type t :: map()

  @impl true
  def init() do
    {:ok, %{}}
  end

  def init(opts) do
    initial_state = Keyword.get(opts, :initial_state, %{})
    {:ok, initial_state}
  end

  @impl true
  def get_state(state, key) when is_map(state) do
    case Map.get(state, key) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  @impl true
  def set_state(state, key, value) when is_map(state) do
    {:ok, Map.put(state, key, value)}
  end

  @impl true
  def update_state(state, key, func)
      when is_map(state) and is_function(func, 1) do
    case Map.get(state, key) do
      nil ->
        {:error, :not_found}

      value ->
        new_value = func.(value)
        {:ok, Map.put(state, key, new_value)}
    end
  end

  @impl true
  def delete_state(state, key) when is_map(state) do
    {:ok, Map.delete(state, key)}
  end

  @impl true
  def initialize_plugin_state(_plugin_module, config) do
    {:ok, config}
  end

  @impl true
  def update_plugin_state_legacy(_plugin_id, state, _config) do
    {:ok, state}
  end

  @impl true
  def cleanup(_state) do
    :ok
  end

  # Non-behaviour functions for additional functionality
  def put_state(_old_state, new_state) when is_map(new_state) do
    {:ok, new_state}
  end

  def get(state, key) when is_map(state) do
    Map.get(state, key)
  end

  def get(state, key, default) when is_map(state) do
    Map.get(state, key, default)
  end

  def put(state, key, value) when is_map(state) do
    {:ok, Map.put(state, key, value)}
  end

  def update(state, key, func) when is_map(state) and is_function(func, 1) do
    {:ok, Map.update(state, key, nil, func)}
  end

  def delete(state, key) when is_map(state) do
    {:ok, Map.delete(state, key)}
  end

  def clear(_state) do
    {:ok, %{}}
  end

  def validate(state) when is_map(state) do
    :ok
  end

  def validate(_state) do
    {:error, :invalid_state_type}
  end

  def merge(state1, state2) when is_map(state1) and is_map(state2) do
    {:ok, Map.merge(state1, state2)}
  end

  @doc """
  Convenience macro for using this default implementation in other modules.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Core.Behaviours.StateManager

      defdelegate init(), to: Raxol.Core.StateManager.Default
      defdelegate init(opts), to: Raxol.Core.StateManager.Default
      defdelegate get_state(state, key), to: Raxol.Core.StateManager.Default

      defdelegate set_state(state, key, value),
        to: Raxol.Core.StateManager.Default

      defdelegate update_state(state, key, func),
        to: Raxol.Core.StateManager.Default

      defdelegate delete_state(state, key), to: Raxol.Core.StateManager.Default

      defdelegate initialize_plugin_state(plugin_module, config),
        to: Raxol.Core.StateManager.Default

      defdelegate update_plugin_state_legacy(plugin_id, state, config),
        to: Raxol.Core.StateManager.Default

      defdelegate cleanup(state), to: Raxol.Core.StateManager.Default

      # Additional non-behaviour functions
      defdelegate put_state(old_state, new_state),
        to: Raxol.Core.StateManager.Default

      defdelegate get(state, key), to: Raxol.Core.StateManager.Default
      defdelegate get(state, key, default), to: Raxol.Core.StateManager.Default
      defdelegate put(state, key, value), to: Raxol.Core.StateManager.Default
      defdelegate update(state, key, func), to: Raxol.Core.StateManager.Default
      defdelegate delete(state, key), to: Raxol.Core.StateManager.Default
      defdelegate clear(state), to: Raxol.Core.StateManager.Default
      defdelegate validate(state), to: Raxol.Core.StateManager.Default
      defdelegate merge(state1, state2), to: Raxol.Core.StateManager.Default

      defoverridable init: 0,
                     init: 1,
                     get_state: 2,
                     set_state: 3,
                     update_state: 3,
                     delete_state: 2,
                     initialize_plugin_state: 2,
                     update_plugin_state_legacy: 3,
                     cleanup: 1
    end
  end
end
