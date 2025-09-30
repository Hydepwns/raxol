defmodule Raxol.Core.Preferences do
  @moduledoc """
  Manages user preferences and settings for the Raxol terminal UI.
  """
  use Raxol.Core.Behaviours.BaseManager

  # BaseManager provides start_link/1 with proper option handling

  def get_preference(key, default \\ nil) do
    GenServer.call(__MODULE__, {:get_preference, key, default})
  end

  def set_preference(key, value) do
    GenServer.call(__MODULE__, {:set_preference, key, value})
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(_opts) do
    {:ok,
     %{
       reduced_motion: false,
       high_contrast: false,
       font_size: :normal
     }}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_preference, key, default}, _from, state) do
    value = Map.get(state, key, default)
    {:reply, value, state}
  end

  def handle_manager_call({:set_preference, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    {:reply, :ok, new_state}
  end
end
