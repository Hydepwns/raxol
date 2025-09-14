defmodule Raxol.Core.StateManager do
  @moduledoc """
  Consolidated state management module providing both functional and process-based state handling.

  This module serves as the primary entry point for state management in Raxol,
  delegating to the appropriate implementation based on usage patterns:
  - For simple functional transformations: uses Default implementation
  - For supervised process state: uses Unified managed state
  - For domain-specific operations: delegates to appropriate domain managers

  ## Migration Guide
  - `start_link/2` -> Use `Unified.start_managed_state/3` for new supervised state
  - `get/2`, `update/2` -> Continue using for functional operations
  - `with_state/2` -> Deprecated, migrate to `Unified.update_managed/2`

  ## Examples

      # Functional state (no processes)
      state = %{count: 0}
      {:ok, new_state} = StateManager.put(state, :count, 1)

      # Managed state (supervised processes)  
      {:ok, state_id} = StateManager.start_managed(:app_state, %{count: 0})
      StateManager.update_managed(:app_state, fn s -> %{s | count: s.count + 1} end)
  """

  alias Raxol.Core.StateManager.{Default, Unified}

  # Delegate common behaviour operations to Default implementation
  defdelegate get(state, key), to: Default
  defdelegate get(state, key, default), to: Default
  defdelegate put(state, key, value), to: Default
  defdelegate update(state, key, func), to: Default
  defdelegate delete(state, key), to: Default
  defdelegate clear(state), to: Default
  defdelegate merge(state1, state2), to: Default
  defdelegate validate(state), to: Default

  # Managed state operations (process-based with supervision)
  defdelegate start_managed(state_id, initial_state, opts \\ []),
    to: Unified,
    as: :start_managed_state

  defdelegate update_managed(state_id, update_fun), to: Unified
  defdelegate get_managed(state_id), to: Unified

  # Domain delegation
  defdelegate delegate_to_domain(domain, function, args), to: Unified
  defdelegate list_domains(), to: Unified

  @doc """
  Starts a new state agent with the given initial state.

  @deprecated "Use start_managed/3 for supervised state or functional operations for simple transformations"
  """
  @spec start_link(any(), keyword()) :: Agent.on_start()
  def start_link(initial_state \\ %{}, opts \\ []) do
    Agent.start_link(fn -> initial_state end, opts)
  end

  # Removed deprecated get/2 that conflicted with delegated get/2
  # Removed deprecated update/2 that conflicted with delegated update/3

  @spec get_and_update(Agent.agent(), (any() -> {any(), any()})) :: any()
  def get_and_update(agent, fun) do
    Agent.get_and_update(agent, fun)
  end

  @doc """
  Legacy support for existing code using Process dictionary.
  This should be refactored to use the Agent-based approach.

  @deprecated "Use start_link/1 and update/2 instead"
  """
  def with_state(state_key, fun) do
    state = get_state(state_key) || %{}

    case fun.(state) do
      {new_state, result} ->
        set_state(state_key, new_state)
        result

      new_state ->
        set_state(state_key, new_state)
        nil
    end
  end

  def get_state(state_key) do
    case Agent.start_link(fn -> %{} end,
           name: {:global, {:state_manager, state_key}}
         ) do
      {:ok, _pid} ->
        %{}

      {:error, {:already_started, _pid}} ->
        Agent.get({:global, {:state_manager, state_key}}, & &1)
    end
  end

  def set_state(state_key, state) do
    case Agent.start_link(fn -> state end,
           name: {:global, {:state_manager, state_key}}
         ) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        Agent.update({:global, {:state_manager, state_key}}, fn _ -> state end)
    end
  end

  @doc """
  Creates a supervised state manager as part of a supervision tree.

  // ## Examples

      children = [
        {StateManager, name: MyApp.StateManager, initial_state: %{}}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)
  """
  def child_spec(opts) do
    id = Keyword.get(opts, :id, __MODULE__)
    name = Keyword.get(opts, :name)
    initial_state = Keyword.get(opts, :initial_state, %{})

    %{
      id: id,
      start: {__MODULE__, :start_link, [initial_state, [name: name]]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
