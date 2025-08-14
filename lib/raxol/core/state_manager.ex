defmodule Raxol.Core.StateManager do
  @moduledoc """
  A functional state management module using Elixir's Agent for immutable state.

  This module provides a clean, functional interface for managing process-local
  state without directly manipulating the process dictionary. It uses Agents
  to maintain state in a supervised, fault-tolerant manner.
  """

  @doc """
  Starts a new state agent with the given initial state.

  // ## Examples

      iex> {:ok, agent} = StateManager.start_link(%{count: 0})
      iex> StateManager.get(agent, & &1.count)
      0
  """
  @spec start_link(any(), keyword()) :: Agent.on_start()
  def start_link(initial_state \\ %{}, opts \\ []) do
    Agent.start_link(fn -> initial_state end, opts)
  end

  @doc """
  Gets the current state or a value derived from it.

  // ## Examples

      iex> StateManager.get(agent, & &1)
      %{count: 0}

      iex> StateManager.get(agent, & &1.count)
      0
  """
  @spec get(Agent.agent(), (any() -> any())) :: any()
  def get(agent, fun) do
    Agent.get(agent, fun)
  end

  @doc """
  Updates the state and optionally returns a value.

  // ## Examples

      iex> StateManager.update(agent, fn state ->
      ...>   %{state | count: state.count + 1}
      ...> end)
      :ok

      iex> StateManager.get_and_update(agent, fn state ->
      ...>   {state.count, %{state | count: state.count + 1}}
      ...> end)
      0
  """
  @spec update(Agent.agent(), (any() -> any())) :: :ok
  def update(agent, fun) do
    Agent.update(agent, fun)
  end

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
