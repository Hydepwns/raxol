defmodule Raxol.Terminal.Split.Manager do
  @moduledoc """
  Manages terminal split windows, handling creation, resizing, navigation, and synchronization
  of split terminal windows.
  """

  use GenServer
  require Logger

  # Client API

  # Helper function to get the process name
  defp process_name(pid_or_name \\ __MODULE__)
  defp process_name(pid) when is_pid(pid), do: pid
  defp process_name(name) when is_atom(name), do: name
  defp process_name(_), do: __MODULE__

  def start_link(opts \\ []) do
    Raxol.Terminal.Split.Common.start_link(__MODULE__, opts)
  end

  def create_split(opts \\ %{}, process \\ __MODULE__) do
    GenServer.call(process_name(process), {:create_split, opts})
  end

  def resize_split(split_id, dimensions, process \\ __MODULE__) do
    GenServer.call(process_name(process), {:resize_split, split_id, dimensions})
  end

  def navigate_to_split(split_id, process \\ __MODULE__) do
    GenServer.call(process_name(process), {:navigate_to_split, split_id})
  end

  def list_splits(process \\ __MODULE__) do
    GenServer.call(process_name(process), :list_splits)
  end

  # Server Callbacks

  def init(_opts) do
    state = %{
      splits: %{},
      active_split: nil,
      next_id: 1
    }

    {:ok, state}
  end

  def handle_call({:create_split, opts}, _from, state) do
    split_id = state.next_id

    split = %{
      id: split_id,
      dimensions: opts[:dimensions] || %{width: 80, height: 24},
      position: opts[:position] || %{x: 0, y: 0},
      content: %{},
      created_at: DateTime.utc_now()
    }

    new_state = %{
      state
      | splits: Map.put(state.splits, split_id, split),
        next_id: split_id + 1,
        active_split: split_id
    }

    {:reply, {:ok, split}, new_state}
  end

  def handle_call({:resize_split, split_id, dimensions}, _from, state) do
    case Map.get(state.splits, split_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      split ->
        updated_split = %{split | dimensions: dimensions}

        new_state = %{
          state
          | splits: Map.put(state.splits, split_id, updated_split)
        }

        {:reply, {:ok, updated_split}, new_state}
    end
  end

  def handle_call({:navigate_to_split, split_id}, _from, state) do
    case Map.get(state.splits, split_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      split ->
        new_state = %{state | active_split: split_id}
        {:reply, {:ok, split}, new_state}
    end
  end

  def handle_call(:list_splits, _from, state) do
    {:reply, Map.values(state.splits), state}
  end
end
