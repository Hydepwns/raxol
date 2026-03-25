defmodule Raxol.Terminal.Split.SplitManager do
  @moduledoc """
  Manages terminal split windows and panes.

  Each split can optionally be bound to a `ConcurrentBuffer` pid and a
  `TerminalProcess` pid, enabling the cockpit to map panes to live
  terminal buffers.
  """

  use Raxol.Core.Behaviours.BaseManager

  @default_dimensions %{width: 80, height: 24}
  @default_position %{x: 0, y: 0}

  defstruct [
    :id,
    :dimensions,
    :position,
    :content,
    :created_at,
    :buffer_pid,
    :terminal_pid,
    :label
  ]

  @type t :: %__MODULE__{
          id: integer(),
          dimensions: %{width: integer(), height: integer()},
          position: %{x: integer(), y: integer()},
          content: map(),
          created_at: DateTime.t(),
          buffer_pid: pid() | nil,
          terminal_pid: pid() | nil,
          label: String.t() | nil
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

  @doc """
  Binds a ConcurrentBuffer and optional TerminalProcess to a split.
  """
  @spec bind_buffer(integer(), pid(), pid(), pid() | nil) ::
          {:ok, t()} | {:error, :not_found}
  def bind_buffer(split_id, manager_pid, buffer_pid, terminal_pid \\ nil) do
    GenServer.call(
      manager_pid,
      {:bind_buffer, split_id, buffer_pid, terminal_pid}
    )
  end

  @doc """
  Unbinds the buffer from a split.
  """
  @spec unbind_buffer(integer(), pid()) :: {:ok, t()} | {:error, :not_found}
  def unbind_buffer(split_id, manager_pid) do
    GenServer.call(manager_pid, {:unbind_buffer, split_id})
  end

  @doc """
  Gets the buffer pid bound to a split.
  """
  @spec get_split_buffer(integer(), pid()) ::
          {:ok, pid()} | {:error, :not_found | :no_buffer}
  def get_split_buffer(split_id, manager_pid) do
    GenServer.call(manager_pid, {:get_split_buffer, split_id})
  end

  @doc """
  Sets a label on a split (for display in pane headers).
  """
  @spec set_label(integer(), String.t(), pid()) ::
          {:ok, t()} | {:error, :not_found}
  def set_label(split_id, label, manager_pid) do
    GenServer.call(manager_pid, {:set_label, split_id, label})
  end

  @doc """
  Removes a split by id.
  """
  @spec remove_split(integer(), pid()) :: :ok | {:error, :not_found}
  def remove_split(split_id, manager_pid) do
    GenServer.call(manager_pid, {:remove_split, split_id})
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
      created_at: DateTime.utc_now(),
      buffer_pid: opts[:buffer_pid],
      terminal_pid: opts[:terminal_pid],
      label: opts[:label]
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

  @impl true
  def handle_manager_call(
        {:bind_buffer, split_id, buffer_pid, terminal_pid},
        _from,
        state
      ) do
    case Map.get(state.splits, split_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      split ->
        updated = %{split | buffer_pid: buffer_pid, terminal_pid: terminal_pid}
        new_state = %{state | splits: Map.put(state.splits, split_id, updated)}
        {:reply, {:ok, updated}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:unbind_buffer, split_id}, _from, state) do
    case Map.get(state.splits, split_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      split ->
        updated = %{split | buffer_pid: nil, terminal_pid: nil}
        new_state = %{state | splits: Map.put(state.splits, split_id, updated)}
        {:reply, {:ok, updated}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:get_split_buffer, split_id}, _from, state) do
    case Map.get(state.splits, split_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{buffer_pid: nil} ->
        {:reply, {:error, :no_buffer}, state}

      %{buffer_pid: pid} ->
        {:reply, {:ok, pid}, state}
    end
  end

  @impl true
  def handle_manager_call({:set_label, split_id, label}, _from, state) do
    case Map.get(state.splits, split_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      split ->
        updated = %{split | label: label}
        new_state = %{state | splits: Map.put(state.splits, split_id, updated)}
        {:reply, {:ok, updated}, new_state}
    end
  end

  @impl true
  def handle_manager_call({:remove_split, split_id}, _from, state) do
    case Map.get(state.splits, split_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _split ->
        new_state = %{state | splits: Map.delete(state.splits, split_id)}
        {:reply, :ok, new_state}
    end
  end
end
