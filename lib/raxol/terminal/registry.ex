defmodule Raxol.Terminal.Registry do
  @moduledoc """
  Terminal registry module.

  @deprecated "Use Raxol.Core.UnifiedRegistry with :sessions type instead"

  This module has been consolidated into the unified registry system.
  For new code, use:

      # Instead of Registry.register(id, state)
      UnifiedRegistry.register(:sessions, id, state)
      
      # Instead of Registry.lookup(id)
      UnifiedRegistry.lookup(:sessions, id)
  """
  use GenServer

  alias Raxol.Core.UnifiedRegistry
  # Define the @registry attribute to fix the compiler warning
  # @registry __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  @deprecated "Use UnifiedRegistry.register(:sessions, id, state) instead"
  def register(id, state) do
    UnifiedRegistry.register(:sessions, id, state)
  end

  @deprecated "Use UnifiedRegistry.unregister(:sessions, id) instead"
  def unregister(id) do
    UnifiedRegistry.unregister(:sessions, id)
  end

  @deprecated "Use UnifiedRegistry.lookup(:sessions, id) instead"
  def lookup(id) do
    case UnifiedRegistry.lookup(:sessions, id) do
      # Maintain legacy format
      {:ok, data} -> [{self(), data}]
      {:error, :not_found} -> []
    end
  end

  @deprecated "Use UnifiedRegistry.list(:sessions) instead"
  def list do
    UnifiedRegistry.list(:sessions) |> Enum.map(& &1.id)
  end

  @deprecated "Use UnifiedRegistry.count(:sessions) instead"
  def count do
    UnifiedRegistry.count(:sessions)
  end

  def match(pattern) do
    GenServer.call(__MODULE__, {:match, pattern})
  end

  def match_except(pattern) do
    GenServer.call(__MODULE__, {:match_except, pattern})
  end

  def filter_by_id(pattern) do
    GenServer.call(__MODULE__, {:filter_by_id, pattern})
  end

  def exclude_by_id(pattern) do
    GenServer.call(__MODULE__, {:exclude_by_id, pattern})
  end

  def handle_call({:register, id, state}, _from, sessions) do
    {:reply, :ok, Map.put(sessions, id, state)}
  end

  def handle_call({:unregister, id}, _from, sessions) do
    {:reply, :ok, Map.delete(sessions, id)}
  end

  def handle_call({:lookup, id}, _from, sessions) do
    case Map.get(sessions, id) do
      nil -> {:reply, [], sessions}
      state -> {:reply, [{self(), state}], sessions}
    end
  end

  def handle_call(:list, _from, sessions) do
    {:reply, Map.keys(sessions), sessions}
  end

  def handle_call(:count, _from, sessions) do
    {:reply, map_size(sessions), sessions}
  end

  def handle_call({:match, pattern}, _from, sessions) do
    matches =
      sessions
      |> Enum.filter(fn {id, _} -> String.match?(id, ~r/#{pattern}/) end)
      |> Enum.map(fn {_id, state} -> {self(), state} end)

    {:reply, matches, sessions}
  end

  def handle_call({:match_except, pattern}, _from, sessions) do
    matches =
      sessions
      |> Enum.filter(fn {id, _} -> not String.match?(id, ~r/#{pattern}/) end)
      |> Enum.map(fn {_id, state} -> {self(), state} end)

    {:reply, matches, sessions}
  end

  def handle_call({:filter_by_id, pattern}, _from, terminals) do
    filtered_terminals =
      terminals
      |> Enum.filter(fn {id, _} -> String.match?(id, ~r/#{pattern}/) end)

    {:reply, filtered_terminals, terminals}
  end

  def handle_call({:exclude_by_id, pattern}, _from, terminals) do
    filtered_terminals =
      terminals
      |> Enum.filter(fn {id, _} -> not String.match?(id, ~r/#{pattern}/) end)

    {:reply, filtered_terminals, terminals}
  end

  def handle_call({:list_by_tag, tag}, _from, state) do
    pattern = "^#{tag}:"

    results =
      state
      |> Enum.filter(fn {id, _} -> String.match?(id, ~r/#{pattern}/) end)
      |> Map.new()

    {:reply, {:ok, results}, state}
  end

  def handle_call(:list_all, _from, state) do
    {:reply, {:ok, state}, state}
  end
end
