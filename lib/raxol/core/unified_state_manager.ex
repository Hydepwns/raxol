defmodule Raxol.Core.UnifiedStateManager do
  @moduledoc """
  Unified state management system with ETS backing for high-performance state operations.
  Provides atomic operations, versioning, and nested state management.
  """

  use Raxol.Core.Behaviours.BaseManager

  require Logger

  # Default table name for application-wide state
  @default_table :unified_state

  # Client API

  @doc """
  Gets the entire state or a specific key/nested path.
  """
  def get_state(key \\ nil)

  def get_state(nil) do
    case get_manager_pid() do
      {:ok, pid} -> GenServer.call(pid, :get_full_state)
      {:error, _} -> %{version: 0, table: @default_table, metadata: %{}}
    end
  end

  def get_state(key) when is_atom(key) or is_binary(key) do
    case get_manager_pid() do
      {:ok, pid} -> GenServer.call(pid, {:get_state, key})
      {:error, _} -> nil
    end
  end

  def get_state(path) when is_list(path) do
    case get_manager_pid() do
      {:ok, pid} -> GenServer.call(pid, {:get_nested_state, path})
      {:error, _} -> nil
    end
  end

  @doc """
  Sets a state value for a key or nested path.
  """
  def set_state(key, value) do
    case get_manager_pid() do
      {:ok, pid} -> GenServer.call(pid, {:set_state, key, value})
      {:error, _} -> :ok
    end
  end

  @doc """
  Updates a state value using a function.
  """
  def update_state(key, update_fn) when is_function(update_fn, 1) do
    case get_manager_pid() do
      {:ok, pid} -> GenServer.call(pid, {:update_state, key, update_fn})
      {:error, _} -> :ok
    end
  end

  @doc """
  Deletes a state key or nested path.
  """
  def delete_state(key) do
    case get_manager_pid() do
      {:ok, pid} -> GenServer.call(pid, {:delete_state, key})
      {:error, _} -> :ok
    end
  end

  @doc """
  Gets the current state version.
  """
  def get_version do
    case get_manager_pid() do
      {:ok, pid} -> GenServer.call(pid, :get_version)
      {:error, _} -> 0
    end
  end

  @doc """
  Executes a function in a transaction context.
  """
  def transaction(fun) when is_function(fun, 0) do
    try do
      result = fun.()
      {:ok, result}
    rescue
      error -> {:error, error}
    catch
      :exit, reason -> {:error, {:exit, reason}}
      :throw, value -> {:error, {:throw, value}}
    end
  end

  @doc """
  Gets memory usage statistics for the ETS table.
  """
  def get_memory_usage do
    case get_manager_pid() do
      {:ok, pid} -> GenServer.call(pid, :get_memory_usage)
      {:error, _} -> %{ets_memory_bytes: 0, ets_memory_mb: 0.0, object_count: 0, last_updated: 0}
    end
  end

  @doc """
  Cleans up resources (primarily ETS table).
  """
  def cleanup(state) do
    case state do
      %{table: table_name} ->
        case :ets.info(table_name) do
          :undefined -> :ok
          _ ->
            :ets.delete(table_name)
            :ok
        end
      _ -> :ok
    end
  end

  # GenServer implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    table_name = Keyword.get(opts, :table_name, @default_table)

    # Create or ensure ETS table exists
    case :ets.info(table_name) do
      :undefined ->
        :ets.new(table_name, [:set, :public, :named_table])
      _ ->
        # Table already exists, continue
        :ok
    end

    # Initialize state structure
    initial_state = %{
      table: table_name,
      version: 0,
      metadata: %{
        created_at: :os.system_time(:millisecond),
        last_updated: :os.system_time(:millisecond)
      }
    }

    # Store initial state in ETS
    :ets.insert(table_name, {:state_root, %{}})
    :ets.insert(table_name, {:version, 0})

    # Store reference for application
    Application.put_env(:raxol, :unified_state_manager, self())

    {:ok, initial_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_full_state, _from, state) do
    full_state = Map.put(state, :state_data, get_state_root(state.table))
    {:reply, full_state, state}
  end

  def handle_manager_call({:get_state, key}, _from, state) do
    state_root = get_state_root(state.table)
    value = Map.get(state_root, normalize_key(key))
    {:reply, value, state}
  end

  def handle_manager_call({:get_nested_state, path}, _from, state) do
    state_root = get_state_root(state.table)
    value = get_nested_value(state_root, path)
    {:reply, value, state}
  end

  def handle_manager_call({:set_state, key, value}, _from, state) do
    new_state = set_state_value(state, key, value)
    {:reply, :ok, new_state}
  end

  def handle_manager_call({:update_state, key, update_fn}, _from, state) do
    state_root = get_state_root(state.table)

    current_value = case key do
      key when is_list(key) -> get_nested_value(state_root, key)
      key -> Map.get(state_root, normalize_key(key))
    end

    try do
      new_value = update_fn.(current_value)
      new_state = set_state_value(state, key, new_value)
      {:reply, :ok, new_state}
    rescue
      error ->
        Logger.error("Update function failed: #{inspect(error)}")
        {:reply, {:error, error}, state}
    end
  end

  def handle_manager_call({:delete_state, key}, _from, state) do
    new_state = delete_state_value(state, key)
    {:reply, :ok, new_state}
  end

  def handle_manager_call(:get_version, _from, state) do
    {:reply, state.version, state}
  end

  def handle_manager_call(:get_memory_usage, _from, %{table: table_name} = state) do
    stats = calculate_memory_stats(table_name)
    {:reply, stats, state}
  end

  # Private functions


  defp get_manager_pid do
    case Application.get_env(:raxol, :unified_state_manager) do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          {:error, :process_dead}
        end
      _ ->
        case GenServer.whereis(__MODULE__) do
          nil -> {:error, :not_started}
          pid -> {:ok, pid}
        end
    end
  end



  defp get_state_root(table_name) do
    case :ets.lookup(table_name, :state_root) do
      [{:state_root, state}] -> state
      [] -> %{}
    end
  end

  defp set_state_value(state, key, value) when is_list(key) do
    state_root = get_state_root(state.table)
    new_state_root = put_nested_value(state_root, key, value)
    update_state_in_ets(state, new_state_root)
  end

  defp set_state_value(state, key, value) do
    state_root = get_state_root(state.table)
    normalized_key = normalize_key(key)
    new_state_root = Map.put(state_root, normalized_key, value)
    update_state_in_ets(state, new_state_root)
  end

  defp delete_state_value(state, key) when is_list(key) do
    state_root = get_state_root(state.table)
    new_state_root = delete_nested_value(state_root, key)
    update_state_in_ets(state, new_state_root)
  end

  defp delete_state_value(state, key) do
    state_root = get_state_root(state.table)
    normalized_key = normalize_key(key)
    new_state_root = Map.delete(state_root, normalized_key)
    update_state_in_ets(state, new_state_root)
  end

  defp update_state_in_ets(state, new_state_root) do
    new_version = state.version + 1
    :ets.insert(state.table, {:state_root, new_state_root})
    :ets.insert(state.table, {:version, new_version})

    %{state |
      version: new_version,
      metadata: Map.put(state.metadata, :last_updated, :os.system_time(:millisecond))
    }
  end

  defp get_nested_value(map, []), do: map
  defp get_nested_value(nil, _), do: nil
  defp get_nested_value(map, [key | rest]) when is_map(map) do
    normalized_key = normalize_key(key)
    case Map.get(map, normalized_key) do
      nil -> nil
      value -> get_nested_value(value, rest)
    end
  end
  defp get_nested_value(_, _), do: nil

  defp put_nested_value(map, [key], value) when is_map(map) do
    normalized_key = normalize_key(key)
    Map.put(map, normalized_key, value)
  end
  defp put_nested_value(map, [key | rest], value) when is_map(map) do
    normalized_key = normalize_key(key)
    nested_map = Map.get(map, normalized_key, %{})
    updated_nested = put_nested_value(nested_map, rest, value)
    Map.put(map, normalized_key, updated_nested)
  end
  defp put_nested_value(%{}, path, value) do
    put_nested_value(%{}, path, value)
  end

  defp delete_nested_value(map, [key]) when is_map(map) do
    normalized_key = normalize_key(key)
    Map.delete(map, normalized_key)
  end
  defp delete_nested_value(map, [key | rest]) when is_map(map) do
    normalized_key = normalize_key(key)
    case Map.get(map, normalized_key) do
      nested_map when is_map(nested_map) ->
        updated_nested = delete_nested_value(nested_map, rest)
        Map.put(map, normalized_key, updated_nested)
      _ -> map
    end
  end
  defp delete_nested_value(map, _), do: map

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key), do: key

  defp calculate_memory_stats(table_name) do
    case :ets.info(table_name) do
      :undefined ->
        %{
          ets_memory_bytes: 0,
          ets_memory_mb: 0.0,
          object_count: 0,
          last_updated: :os.system_time(:millisecond)
        }
      info ->
        words = Keyword.get(info, :memory, 0)
        wordsize = :erlang.system_info(:wordsize)
        bytes = words * wordsize
        mb = bytes / (1024 * 1024)
        count = Keyword.get(info, :size, 0)

        %{
          ets_memory_bytes: bytes,
          ets_memory_mb: mb,
          object_count: count,
          last_updated: :os.system_time(:millisecond)
        }
    end
  end
end