defmodule Raxol.Terminal.Registry do
  @moduledoc """
  Terminal registry module.

  This module manages the registry of terminal sessions, including:
  - Session registration
  - Session lookup
  - Session cleanup
  """
  use GenServer
  # Define the @registry attribute to fix the compiler warning
  # @registry __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def register(id, state) do
    GenServer.call(__MODULE__, {:register, id, state})
  end

  def unregister(id) do
    GenServer.call(__MODULE__, {:unregister, id})
  end

  def lookup(id) do
    GenServer.call(__MODULE__, {:lookup, id})
  end

  def list do
    GenServer.call(__MODULE__, :list)
  end

  def count do
    GenServer.call(__MODULE__, :count)
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

  # Server callbacks

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
    # Return the entire state map
    {:reply, {:ok, state}, state}
  end
end
