defmodule Raxol.Core.UserPreferences do
  @moduledoc """
  Manages user preferences for the Raxol application.

  This module provides functionality for:
  - Storing and retrieving user preferences
  - Managing preference persistence
  - Handling preference updates
  """

  use GenServer

  alias Raxol.Style.Colors.Persistence

  # Client API

  @doc """
  Starts the UserPreferences server.

  ## Returns

  - `{:ok, pid}` on success
  - `{:error, reason}` on failure
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Initializes user preferences.

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def init do
    # Load preferences from file
    case Persistence.load_user_preferences() do
      {:ok, preferences} ->
        {:ok, preferences}

      {:error, _} ->
        # Return default preferences if file doesn't exist
        {:ok, %{"theme" => "Default"}}
    end
  end

  @doc """
  Gets a user preference.

  ## Parameters

  - `key` - The preference key to get

  ## Returns

  - The preference value
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Sets a user preference.

  ## Parameters

  - `key` - The preference key to set
  - `value` - The preference value to set

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  @spec set(any(), any()) :: :ok
  def set(key, value) do
    GenServer.call(__MODULE__, {:set, key, value})
  end

  @doc """
  Saves user preferences to file.

  ## Returns

  - `:ok` on success
  - `{:error, reason}` on failure
  """
  def save do
    GenServer.call(__MODULE__, :save)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Load preferences from file
    case Persistence.load_user_preferences() do
      {:ok, preferences} ->
        {:ok, preferences}

      {:error, _} ->
        # Return default preferences if file doesn't exist
        {:ok, %{"theme" => "Default"}}
    end
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @impl true
  def handle_call({:set, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:save, _from, state) do
    case Persistence.save_user_preferences(state) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
end
