defmodule Raxol.Terminal.Split.SplitManager do
  @moduledoc """
  Manages terminal split windows and panes.
  """

  use Raxol.Core.Behaviours.BaseManager

  @default_dimensions %{width: 80, height: 24}
  @default_position %{x: 0, y: 0}

  defstruct [
    :id,
    :dimensions,
    :position,
    :content,
    :created_at
  ]

  @type t :: %__MODULE__{
          id: integer(),
          dimensions: %{width: integer(), height: integer()},
          position: %{x: integer(), y: integer()},
          content: map(),
          created_at: DateTime.t()
        }

  # Client API

  # BaseManager provides start_link

  @doc """
  Creates a new split with the given options.
  """
  @spec create_split(map(), pid()) :: {:ok, t()} | {:error, term()}
  def create_split(opts \\ %{}, pid) do
    GenServer.call(pid, {:create_split, opts})
  end

  @doc """
  Resizes an existing split.
  """
  @spec resize_split(integer(), %{width: integer(), height: integer()}, pid()) ::
          {:ok, t()} | {:error, :not_found}
  def resize_split(split_id, new_dimensions, pid) do
    GenServer.call(pid, {:resize_split, split_id, new_dimensions})
  end

  @doc """
  Navigates to an existing split.
  """
  @spec navigate_to_split(integer(), pid()) :: {:ok, t()} | {:error, :not_found}
  def navigate_to_split(split_id, pid) do
    GenServer.call(pid, {:navigate_to_split, split_id})
  end

  @doc """
  Lists all splits.
  """
  @spec list_splits(pid()) :: [t()]
  def list_splits(pid) do
    GenServer.call(pid, :list_splits)
  end

  # Server callbacks

  @impl true
  def init_manager(state) when is_list(state) do
    # Convert list to map for keyword list options
    init_manager(Map.new(state))
  end

  def init_manager(state) when is_map(state) do
    # Ensure state has required fields
    initial_state = %{
      splits: Map.get(state, :splits, %{}),
      next_id: Map.get(state, :next_id, 1)
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_manager_call({:create_split, opts}, _from, state) do
    split_id = state.next_id
    dimensions = opts[:dimensions] || @default_dimensions
    position = opts[:position] || @default_position

    split = %__MODULE__{
      id: split_id,
      dimensions: dimensions,
      position: position,
      content: %{},
      created_at: DateTime.utc_now()
    }

    new_state = %{
      state
      | splits: Map.put(state.splits, split_id, split),
        next_id: split_id + 1
    }

    {:reply, {:ok, split}, new_state}
  end

  @impl true
  def handle_manager_call(
        {:resize_split, split_id, new_dimensions},
        _from,
        state
      ) do
    case Map.get(state.splits, split_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      split ->
        updated_split = %{split | dimensions: new_dimensions}

        new_state = %{
          state
          | splits: Map.put(state.splits, split_id, updated_split)
        }

        {:reply, {:ok, updated_split}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:navigate_to_split, split_id}, _from, state) do
    case Map.get(state.splits, split_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      split ->
        {:reply, {:ok, split}, state}
    end
  end

  @impl true
  def handle_manager_call(:list_splits, _from, state) do
    splits = Map.values(state.splits)
    {:reply, splits, state}
  end
end
