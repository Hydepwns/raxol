defmodule Raxol.Core.Preferences do
  @moduledoc """
  Manages user preferences and settings for the Raxol terminal UI.
  """
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_preference(key, default \\ nil) do
    GenServer.call(__MODULE__, {:get_preference, key, default})
  end

  def set_preference(key, value) do
    GenServer.call(__MODULE__, {:set_preference, key, value})
  end

  @impl true
  def init(_opts) do
    {:ok,
     %{
       reduced_motion: false,
       high_contrast: false,
       font_size: :normal
     }}
  end

  @impl true
  def handle_call({:get_preference, key, default}, _from, state) do
    value = Map.get(state, key, default)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:set_preference, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    {:reply, :ok, new_state}
  end
end
