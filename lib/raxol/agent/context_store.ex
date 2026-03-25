defmodule Raxol.Agent.ContextStore do
  @moduledoc """
  ETS-backed persistent context that survives agent restarts.

  Stores agent state snapshots keyed by agent_id. When an agent crashes
  and restarts, it can restore its context from here rather than starting
  from scratch.

  Table: `:raxol_agent_contexts`, named_table, public, set, read_concurrency.
  """

  @table :raxol_agent_contexts

  @doc """
  Initializes the ETS table. Safe to call multiple times.
  """
  @spec init() :: :ok
  def init do
    case :ets.whereis(@table) do
      :undefined ->
        _ =
          :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

        :ok

      _ref ->
        :ok
    end
  end

  @doc """
  Saves a context snapshot for an agent.
  """
  @spec save(atom(), map()) :: :ok
  def save(agent_id, context) when is_atom(agent_id) and is_map(context) do
    ensure_table()
    :ets.insert(@table, {agent_id, context, DateTime.utc_now()})
    :ok
  end

  @doc """
  Loads the most recent context snapshot for an agent.
  """
  @spec load(atom()) :: {:ok, map()} | {:error, :not_found}
  def load(agent_id) when is_atom(agent_id) do
    ensure_table()

    case :ets.lookup(@table, agent_id) do
      [{^agent_id, context, _saved_at}] -> {:ok, context}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Updates an agent's context by applying a transformation function.
  """
  @spec update(atom(), (map() -> map())) :: {:ok, map()} | {:error, :not_found}
  def update(agent_id, fun) when is_atom(agent_id) and is_function(fun, 1) do
    case load(agent_id) do
      {:ok, context} ->
        new_context = fun.(context)
        save(agent_id, new_context)
        {:ok, new_context}

      error ->
        error
    end
  end

  @doc """
  Deletes an agent's context.
  """
  @spec delete(atom()) :: :ok
  def delete(agent_id) when is_atom(agent_id) do
    ensure_table()
    :ets.delete(@table, agent_id)
    :ok
  end

  @doc """
  Lists all agent ids that have stored contexts.
  """
  @spec list() :: [atom()]
  def list do
    ensure_table()

    :ets.select(@table, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  defp ensure_table do
    if :ets.whereis(@table) == :undefined do
      init()
    end
  end
end
