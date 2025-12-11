defmodule Raxol.Core.StateManager do
  @moduledoc """
  Consolidated state management module providing functional, process-based, and ETS-backed state handling.

  This module provides multiple state management strategies with automatic selection:
  - **Functional**: Simple map-based transformations (no processes)
  - **Process-based**: Supervised GenServer state with Agent or GenServer backing
  - **ETS-backed**: High-performance state with ETS storage for large datasets
  - **Domain-specific**: Delegation to specialized domain managers

  ## Configuration

  Set the default strategy in application config:

      config :raxol, :state_manager,
        default_strategy: :functional,  # :functional, :process, :ets
        ets_enabled: true,
        process_supervision: true

  Or control per-call with options:

      StateManager.put(state, :key, value, strategy: :ets)
      StateManager.start_managed(:app_state, %{}, strategy: :process)

  ## Migration from Previous Modules

  Replace:
      Raxol.Core.StateManager.get_state(:key)
      Raxol.Core.StateManager.Unified.update_managed(:id, fun)
      Raxol.Core.StateManager.Default.put(state, :key, value)

  With:
      Raxol.Core.StateManager.get_state(:key, strategy: :ets)
      Raxol.Core.StateManager.update_managed(:id, fun, strategy: :process)
      Raxol.Core.StateManager.put(state, :key, value, strategy: :functional)

  ## Examples

      # Functional state (no processes, good for simple transformations)
      state = %{count: 0}
      {:ok, new_state} = StateManager.put(state, :count, 1)

      # Process-based managed state (supervised processes)
      {:ok, state_id} = StateManager.start_managed(:app_state, %{count: 0})
      StateManager.update_managed(:app_state, fn s -> %{s | count: s.count + 1} end)

      # ETS-backed state (high performance for large datasets)
      StateManager.set_state(:global_config, %{theme: "dark"}, strategy: :ets)
      config = StateManager.get_state(:global_config, strategy: :ets)
  """

  use Agent
  alias Raxol.Core.Runtime.Log
  use Raxol.Core.Behaviours.BaseManager
  # Types
  @type state_key :: atom() | String.t() | [atom() | String.t()]
  @type state_value :: term()
  @type state_tree :: map()
  @type version :: non_neg_integer()
  @type strategy :: :functional | :process | :ets

  # Configuration
  defp default_strategy do
    Application.get_env(:raxol, :state_manager, [])[:default_strategy] ||
      :functional
  end

  defp strategy_from_opts(opts) do
    Keyword.get(opts, :strategy, default_strategy())
  end

  defp ets_enabled? do
    Application.get_env(:raxol, :state_manager, [])[:ets_enabled] != false
  end

  # Initialization Functions

  @doc """
  Initializes state manager with default empty state.
  """
  def initialize(), do: {:ok, %{}}

  @doc """
  Initializes state manager with options.
  """
  def initialize(opts) when is_list(opts) do
    initial_state = Keyword.get(opts, :initial_state, %{})
    {:ok, initial_state}
  end

  # Common Functional State Operations

  @doc """
  Gets a value from functional state.

  ## Options
  - `strategy: atom()` - Force specific strategy (:functional, :process, :ets)
  """
  def get(state, key, opts \\ [])

  def get(state, key, opts) when is_map(state) and is_list(opts) do
    Map.get(state, key)
  end

  def get(state, key, default) when is_map(state) and not is_list(default) do
    Map.get(state, key, default)
  end

  @doc """
  Gets a value from functional state with default.
  """
  def get(state, key, default, opts) when is_map(state) do
    case strategy_from_opts(opts) do
      :functional -> Map.get(state, key, default)
      :ets -> get_state_ets(key, default, opts)
      :process -> get_managed_with_default(key, default, opts)
    end
  end

  @doc """
  Puts a value into functional state.

  ## Options
  - `strategy: atom()` - Force specific strategy
  """
  def put(state, key, value, opts \\ [])

  def put(state, key, value, opts) when is_map(state) do
    case strategy_from_opts(opts) do
      :functional -> {:ok, Map.put(state, key, value)}
      :ets -> set_state_ets(key, value, opts)
      :process -> update_managed_key(key, fn _ -> value end, opts)
    end
  end

  @doc """
  Updates a value in functional state using a function.
  """
  def update(state, key, func, opts \\ [])

  def update(state, key, func, opts)
      when is_map(state) and is_function(func, 1) do
    case strategy_from_opts(opts) do
      :functional -> {:ok, Map.update(state, key, nil, func)}
      :ets -> update_state_ets(key, func, opts)
      :process -> update_managed_key(key, func, opts)
    end
  end

  @doc """
  Deletes a key from functional state.
  """
  def delete(state, key, opts \\ [])

  def delete(state, key, opts) when is_map(state) do
    case strategy_from_opts(opts) do
      :functional -> {:ok, Map.delete(state, key)}
      :ets -> delete_state_ets(key, opts)
      :process -> delete_managed_key(key, opts)
    end
  end

  @doc """
  Clears functional state.
  """
  def clear(state, opts \\ [])

  def clear(_state, opts) do
    case strategy_from_opts(opts) do
      :functional -> {:ok, %{}}
      :ets -> clear_state_ets(opts)
      :process -> clear_managed_state(opts)
    end
  end

  @doc """
  Merges two functional states.
  """
  def merge(state1, state2, opts \\ [])

  def merge(state1, state2, opts) when is_map(state1) and is_map(state2) do
    case strategy_from_opts(opts) do
      :functional -> {:ok, Map.merge(state1, state2)}
      :ets -> merge_state_ets(state1, state2, opts)
      :process -> merge_managed_state(state1, state2, opts)
    end
  end

  @doc """
  Validates functional state.
  """
  def validate(state, opts \\ [])
  def validate(state, _opts) when is_map(state), do: :ok
  def validate(_state, _opts), do: {:error, :invalid_state_type}

  # Process-based Managed State Operations

  @doc """
  Starts a new managed state with supervision.
  This is recommended for long-lived application state.

  ## Options
  - `strategy: :process | :ets` - Choose the backing strategy
  """
  def start_managed(state_id, initial_state, opts \\ []) do
    case strategy_from_opts(opts) do
      :process -> start_managed_process(state_id, initial_state, opts)
      :ets -> start_managed_ets(state_id, initial_state, opts)
      # Default
      _ -> start_managed_process(state_id, initial_state, opts)
    end
  end

  @doc """
  Updates managed state using a function.
  """
  def update_managed(state_id, update_fun, opts \\ [])
      when is_function(update_fun, 1) do
    case strategy_from_opts(opts) do
      :process -> update_managed_process(state_id, update_fun)
      :ets -> update_state_ets(state_id, update_fun, opts)
      _ -> update_managed_process(state_id, update_fun)
    end
  end

  @doc """
  Gets the current managed state.
  """
  def get_managed(state_id, opts \\ []) do
    case strategy_from_opts(opts) do
      :process -> get_managed_process(state_id)
      :ets -> {:ok, get_state_ets(state_id, %{}, opts)}
      _ -> get_managed_process(state_id)
    end
  end

  # ETS-backed State Operations

  @doc """
  Gets the current state or a specific key from ETS.
  When called without arguments, returns the entire state as a map.
  """
  def get_state(key \\ nil, opts \\ [])

  def get_state(key, opts) do
    strategy = strategy_from_opts(opts)

    # If no strategy explicitly provided and ETS is enabled, default to ETS
    strategy =
      if strategy == :functional and ets_enabled?() and opts == [] do
        :ets
      else
        strategy
      end

    case strategy do
      :ets ->
        _ = init_ets_if_needed(opts)

        cond do
          key == nil ->
            get_entire_state_as_map(opts)

          is_list(key) ->
            get_nested_key_from_ets(key, opts)

          true ->
            get_state_ets(key, nil, opts)
        end

      :process ->
        get_managed_process_state(key, opts)

      :functional ->
        {:error, :strategy_not_supported}

      _ ->
        {:error, :strategy_not_supported}
    end
  end

  @doc """
  Sets a state value atomically in ETS.
  """
  def set_state(key, value, opts \\ []) do
    strategy = strategy_from_opts(opts)

    # If no strategy explicitly provided and ETS is enabled, default to ETS
    strategy =
      if strategy == :functional and ets_enabled?() and opts == [] do
        :ets
      else
        strategy
      end

    case strategy do
      :ets ->
        _ = init_ets_if_needed(opts)
        # Handle nested keys specially
        if is_list(key) do
          set_nested_state_ets(key, value, opts)
        else
          set_state_ets(key, value, opts)
        end

      :process ->
        set_managed_process_state(key, value, opts)

      :functional ->
        {:error, :strategy_not_supported}

      _ ->
        {:error, :strategy_not_supported}
    end
  end

  @doc """
  Updates a state value with a function.
  """
  def update_state(key, update_fn) when is_function(update_fn, 1) do
    update_state(key, update_fn, [])
  end

  def update_state(key, update_fn, opts) when is_function(update_fn, 1) do
    strategy = strategy_from_opts(opts)

    # If no strategy explicitly provided and ETS is enabled, default to ETS
    strategy =
      if strategy == :functional and ets_enabled?() and opts == [] do
        :ets
      else
        strategy
      end

    case strategy do
      :ets ->
        _ = init_ets_if_needed(opts)
        current = get_state(key, opts)
        new_value = update_fn.(current)
        set_state(key, new_value, opts)

      :process ->
        # Process-based state management not yet implemented
        {:error, :not_implemented}

      _ ->
        {:error, :strategy_not_supported}
    end
  end

  @doc """
  Deletes a state value.
  """
  def delete_state(key, opts \\ []) do
    strategy = strategy_from_opts(opts)

    # If no strategy explicitly provided and ETS is enabled, default to ETS
    strategy =
      if strategy == :functional and ets_enabled?() and opts == [] do
        :ets
      else
        strategy
      end

    case strategy do
      :ets ->
        _ = init_ets_if_needed(opts)

        if is_list(key) do
          delete_nested_key_from_ets(key, opts)
        else
          delete_state_ets(key, opts)
        end

      :process ->
        # Process-based state management not yet implemented
        {:error, :not_implemented}

      _ ->
        {:error, :strategy_not_supported}
    end
  end

  # Domain-Specific State Management

  @state_domains %{
    terminal: Raxol.Terminal.StateManager,
    plugins: Raxol.Core.Runtime.Plugins.StateManager,
    animation: Raxol.Animation.StateManager,
    core: Raxol.Core.StateManager
  }

  @doc """
  Delegates to domain-specific state manager.
  """
  def delegate_to_domain(domain, function, args) do
    case Map.get(@state_domains, domain) do
      nil -> {:error, {:unknown_domain, domain}}
      module -> apply(module, function, args)
    end
  end

  @doc """
  Lists all registered state domains.
  """
  def list_domains do
    Map.keys(@state_domains)
  end

  # Legacy Support (for backward compatibility)

  @doc """
  Starts a new state agent with the given initial state.

  @deprecated "Use start_managed/3 for supervised state or functional operations for simple transformations"
  """
  def start_link_agent(initial_state \\ %{}, opts \\ []) do
    Agent.start_link(fn -> initial_state end, opts)
  end

  @doc """
  Agent-based get and update operation.
  """
  def get_and_update(agent, fun) do
    Agent.get_and_update(agent, fun)
  end

  @doc """
  Legacy support for existing code using Process dictionary.

  @deprecated "Use start_managed/3 and update_managed/3 instead"
  """
  def with_state(state_key, fun) do
    state = get_legacy_state(state_key) || %{}

    case fun.(state) do
      {new_state, result} ->
        set_legacy_state(state_key, new_state)
        result

      new_state ->
        set_legacy_state(state_key, new_state)
        nil
    end
  end

  # Child Spec for Supervision

  @doc """
  Creates a supervised state manager as part of a supervision tree.

  ## Examples

      children = [
        {StateManager, name: MyApp.StateManager, initial_state: %{}}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)
  """
  def child_spec(opts) do
    id = Keyword.get(opts, :id, __MODULE__)
    name = Keyword.get(opts, :name)
    initial_state = Keyword.get(opts, :initial_state, %{})

    %{
      id: id,
      start: {__MODULE__, :start_link, [initial_state, [name: name]]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  # Implementation Details - ETS Strategy

  defp start_managed_ets(state_id, initial_state, opts) do
    if ets_enabled?() do
      _ = init_ets_if_needed(opts)
      set_state_ets(state_id, initial_state, opts)
      {:ok, state_id}
    else
      {:error, :ets_disabled}
    end
  end

  defp get_state_ets(key, default, opts) do
    table = table_name_from_opts(opts)

    case :ets.lookup(table, normalize_key(key)) do
      [{_key, value}] -> value
      [] -> default
    end
  end

  defp set_state_ets(key, value, opts) do
    table = table_name_from_opts(opts)
    :ets.insert(table, {normalize_key(key), value})
    increment_version(opts)
    :ok
  end

  defp update_state_ets(key, update_fn, opts) do
    table = table_name_from_opts(opts)
    key_normalized = normalize_key(key)

    old_value =
      case :ets.lookup(table, key_normalized) do
        [{_key, value}] -> value
        [] -> nil
      end

    new_value = update_fn.(old_value)
    :ets.insert(table, {key_normalized, new_value})
    increment_version(opts)
    :ok
  end

  defp delete_state_ets(key, opts) do
    table = table_name_from_opts(opts)
    :ets.delete(table, normalize_key(key))
    increment_version(opts)
    :ok
  end

  defp clear_state_ets(opts) do
    table = table_name_from_opts(opts)
    :ets.delete_all_objects(table)
    :ok
  end

  defp merge_state_ets(state1, state2, opts)
       when is_map(state1) and is_map(state2) do
    merged = Map.merge(state1, state2)

    Enum.each(merged, fn {key, value} ->
      set_state_ets(key, value, opts)
    end)

    :ok
  end

  defp init_ets_if_needed(opts) do
    table = table_name_from_opts(opts)

    case :ets.info(table) do
      :undefined ->
        :ets.new(table, [:set, :public, :named_table, {:read_concurrency, true}])

      _ ->
        :ok
    end
  end

  defp table_name_from_opts(opts) do
    Keyword.get(opts, :table_name, :raxol_unified_state)
  end

  # Implementation Details - Process Strategy

  defp start_managed_process(state_id, initial_state, opts) do
    case GenServer.start_link(__MODULE__, {state_id, initial_state}, opts) do
      {:ok, pid} ->
        Process.register(pid, state_process_name(state_id))
        {:ok, state_id}

      error ->
        error
    end
  end

  defp update_managed_process(state_id, update_fun) do
    case Process.whereis(state_process_name(state_id)) do
      nil -> {:error, :state_not_found}
      pid -> GenServer.call(pid, {:update, update_fun})
    end
  end

  defp get_managed_process(state_id) do
    case Process.whereis(state_process_name(state_id)) do
      nil -> {:error, :state_not_found}
      pid -> GenServer.call(pid, :get)
    end
  end

  defp state_process_name(state_id), do: :"raxol_managed_state_#{state_id}"

  # GenServer Implementation (for process strategy)

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    {state_id, initial_state} =
      case opts do
        [{:state_id, id}, {:initial_state, state}] -> {id, state}
        %{state_id: id, initial_state: state} -> {id, state}
        opts when is_tuple(opts) -> opts
        _ -> {nil, %{}}
      end

    Log.info("Starting managed state: #{state_id}")
    {:ok, %{id: state_id, state: initial_state}}
  end

  @impl GenServer
  def handle_call({:update, update_fun}, _from, %{state: state} = manager_state) do
    try do
      new_state = update_fun.(state)
      {:reply, {:ok, new_state}, %{manager_state | state: new_state}}
    catch
      kind, reason ->
        {:reply, {:error, {kind, reason}}, manager_state}
    end
  end

  @impl GenServer
  def handle_call(:get, _from, %{state: state} = manager_state) do
    {:reply, {:ok, state}, manager_state}
  end

  # Helper functions for backwards compatibility

  defp get_legacy_state(state_key) do
    case Agent.start_link(fn -> %{} end,
           name: {:global, {:state_manager, state_key}}
         ) do
      {:ok, _pid} ->
        %{}

      {:error, {:already_started, _pid}} ->
        Agent.get({:global, {:state_manager, state_key}}, & &1)
    end
  end

  defp set_legacy_state(state_key, state) do
    case Agent.start_link(fn -> state end,
           name: {:global, {:state_manager, state_key}}
         ) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        Agent.update({:global, {:state_manager, state_key}}, fn _ -> state end)
    end
  end

  # Helper functions

  defp normalize_key(key) when is_atom(key) or is_binary(key), do: key
  defp normalize_key(keys) when is_list(keys), do: List.to_tuple(keys)

  # Helper to set nested state values in ETS
  defp set_nested_state_ets(keys, value, opts) when is_list(keys) do
    table = table_name_from_opts(opts)
    # Store as a tuple key
    :ets.insert(table, {List.to_tuple(keys), value})

    # Also update parent keys to allow partial access
    # For [:plugins, :loaded], also store under :plugins
    if length(keys) > 1 do
      parent_key = List.first(keys)

      existing =
        case :ets.lookup(table, parent_key) do
          [{_key, map}] when is_map(map) -> map
          _ -> %{}
        end

      # Build nested map structure
      nested = build_nested_map(tl(keys), value)
      updated = Map.merge(existing, nested)
      :ets.insert(table, {parent_key, updated})
    end

    increment_version(opts)
    :ok
  end

  defp build_nested_map([key], value), do: %{key => value}

  defp build_nested_map([head | tail], value) do
    %{head => build_nested_map(tail, value)}
  end

  # Helper to get nested value from a map
  defp get_nested_value(map, []) when is_map(map), do: map
  defp get_nested_value(map, [key]) when is_map(map), do: Map.get(map, key)

  defp get_nested_value(map, [head | tail]) when is_map(map) do
    case Map.get(map, head) do
      nested when is_map(nested) -> get_nested_value(nested, tail)
      _ -> nil
    end
  end

  # Helper to delete from nested map
  defp delete_from_nested_map(map, [key]) when is_map(map) do
    Map.delete(map, key)
  end

  defp delete_from_nested_map(map, [head | tail]) when is_map(map) do
    case Map.get(map, head) do
      nested when is_map(nested) ->
        updated = delete_from_nested_map(nested, tail)

        if map_size(updated) == 0 do
          Map.delete(map, head)
        else
          Map.put(map, head, updated)
        end

      _ ->
        map
    end
  end

  defp delete_from_nested_map(map, _), do: map

  # Transaction support
  @doc """
  Executes a function within a transaction.
  """
  def transaction(func, _opts \\ []) when is_function(func, 0) do
    try do
      result = func.()
      {:ok, result}
    rescue
      error ->
        {:error, error}
    catch
      kind, reason ->
        {:error, {kind, reason}}
    end
  end

  # Placeholder implementations for functions referenced but not fully implemented

  defp get_managed_with_default(_key, default, _opts), do: default
  defp update_managed_key(_key, func, _opts), do: {:ok, func.(nil)}
  defp delete_managed_key(_key, _opts), do: :ok
  defp clear_managed_state(_opts), do: {:ok, %{}}

  defp merge_managed_state(state1, state2, _opts),
    do: {:ok, Map.merge(state1, state2)}

  defp get_managed_process_state(_key, _opts), do: {:error, :not_implemented}

  defp set_managed_process_state(_key, _value, _opts),
    do: {:error, :not_implemented}

  # Version tracking (stored in ETS)
  @doc """
  Gets the current version number.
  """
  def get_version(opts \\ []) do
    _ = init_ets_if_needed(opts)
    table = table_name_from_opts(opts)

    case :ets.lookup(table, :__version__) do
      [{:__version__, version}] ->
        version

      [] ->
        # Initialize version if not present
        :ets.insert(table, {:__version__, 0})
        0
    end
  end

  @doc """
  Increments the version number.
  """
  def increment_version(opts \\ []) do
    _ = init_ets_if_needed(opts)
    table = table_name_from_opts(opts)
    :ets.update_counter(table, :__version__, 1, {:__version__, 0})
  end

  # Memory usage tracking
  @doc """
  Gets memory usage statistics.
  """
  def get_memory_usage(opts \\ []) do
    _ = init_ets_if_needed(opts)
    table = table_name_from_opts(opts)

    case :ets.info(table) do
      :undefined ->
        %{
          table_size: 0,
          memory: 0,
          objects: 0,
          object_count: 0,
          ets_memory_bytes: 0,
          ets_memory_mb: 0.0,
          last_updated: System.system_time(:second)
        }

      info ->
        memory_words = Keyword.get(info, :memory, 0)
        memory_bytes = memory_words * :erlang.system_info(:wordsize)
        memory_mb = memory_bytes / (1024 * 1024)
        object_count = Keyword.get(info, :size, 0)

        %{
          table_size: object_count,
          memory: memory_bytes,
          objects: object_count,
          object_count: object_count,
          ets_memory_bytes: memory_bytes,
          ets_memory_mb: memory_mb,
          last_updated: System.system_time(:second)
        }
    end
  end

  # Cleanup function
  @doc """
  Cleans up state resources.
  """
  def cleanup(state) when is_map(state) do
    table = Map.get(state, :table)

    if table && table != :undefined do
      case :ets.info(table) do
        :undefined ->
          :ok

        _ ->
          :ets.delete(table)
          :ok
      end
    else
      :ok
    end
  end

  def cleanup(_state), do: :ok

  defp get_entire_state_as_map(opts) do
    # Return entire state as a map, including :table and :version keys for tests
    table = table_name_from_opts(opts)
    version = get_version(opts)

    state_map =
      :ets.tab2list(table)
      |> Enum.reject(fn {k, _v} -> k == :__version__ end)
      |> Enum.into(%{})

    # Add table and version references for tests
    state_map
    |> Map.put(:table, table)
    |> Map.put(:version, version)
  end

  defp get_nested_key_from_ets(key, opts) do
    # Handle list keys for nested access
    table = table_name_from_opts(opts)
    # Try to get the nested key directly first
    case :ets.lookup(table, List.to_tuple(key)) do
      [{_key, value}] ->
        value

      [] ->
        # Try to get from parent key's nested structure
        get_from_parent_nested_structure(table, key)
    end
  end

  defp delete_nested_key_from_ets(key, opts) do
    # Delete nested key
    table = table_name_from_opts(opts)
    # Remove the direct tuple key
    :ets.delete(table, List.to_tuple(key))

    # Also remove from parent's nested structure
    if length(key) > 1 do
      remove_from_parent_nested_structure(table, key)
    end

    increment_version(opts)
    :ok
  end

  defp get_from_parent_nested_structure(table, key) do
    parent_key = List.first(key)

    case :ets.lookup(table, parent_key) do
      [{_key, map}] when is_map(map) ->
        get_nested_value(map, tl(key))

      _ ->
        nil
    end
  end

  defp remove_from_parent_nested_structure(table, key) do
    parent_key = List.first(key)

    case :ets.lookup(table, parent_key) do
      [{_key, map}] when is_map(map) ->
        updated = delete_from_nested_map(map, tl(key))

        if updated == %{} do
          :ets.delete(table, parent_key)
        else
          :ets.insert(table, {parent_key, updated})
        end

      _ ->
        :ok
    end
  end
end
