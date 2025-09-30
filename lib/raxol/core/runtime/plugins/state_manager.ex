defmodule StateManager do
  @moduledoc """
  Plugin state management utilities with full functionality.

  Provides state management for the plugin system, including initialization,
  updates, persistence, and cleanup. Integrates with the unified state manager
  for consistency and performance.
  """

  alias Raxol.Core.StateManager, as: UnifiedStateManager
  alias Raxol.Core.Runtime.Log
  @type plugin_id :: String.t()
  @type plugin_module :: module()
  @type plugin_config :: map()
  @type plugin_state :: term()

  @doc """
  Initializes plugin state for a given plugin module.

  Creates initial state based on the plugin's configuration and stores it
  in the unified state management system under the plugins namespace.
  """
  @spec initialize_plugin_state(plugin_module(), plugin_config()) ::
          {:ok, plugin_state()}
  def initialize_plugin_state(plugin_module, config) do
    try do
      # Generate plugin ID from module name
      plugin_id = generate_plugin_id(plugin_module)

      # Initialize state based on plugin type and config
      initial_state =
        case {has_init_callback?(plugin_module), config} do
          {true, _} ->
            # Plugin has custom initialization
            apply(plugin_module, :init_state, [config])

          {false, config} when map_size(config) > 0 ->
            # Use config as initial state
            config

          _ ->
            # Default empty state
            %{}
        end

      # Store in unified state manager
      state_key = [:plugins, :states, plugin_id]
      UnifiedStateManager.set_state(state_key, initial_state)

      # Track plugin metadata
      metadata_key = [:plugins, :metadata, plugin_id]

      metadata = %{
        module: plugin_module,
        initialized_at: :os.system_time(:millisecond),
        config: config,
        status: :initialized
      }

      UnifiedStateManager.set_state(metadata_key, metadata)

      Log.module_info(
        "Initialized state for plugin #{plugin_id} (#{plugin_module})"
      )

      {:ok, initial_state}
    rescue
      error ->
        Log.module_error(
          "Failed to initialize plugin state for #{plugin_module}: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  @doc """
  Updates plugin state using legacy interface for backward compatibility.

  Maintains state in the unified state manager and supports both
  functional and imperative update patterns.
  """
  @spec update_plugin_state_legacy(plugin_id(), plugin_state(), plugin_config()) ::
          {:ok, plugin_state()}
  def update_plugin_state_legacy(plugin_id, state, config) do
    try do
      # Update state in unified state manager
      state_key = [:plugins, :states, plugin_id]

      # Merge new state with existing state
      updated_state =
        case UnifiedStateManager.get_state(state_key) do
          nil ->
            state

          existing_state when is_map(existing_state) and is_map(state) ->
            Map.merge(existing_state, state)

          _existing_state ->
            # Replace entirely if types don't match
            state
        end

      UnifiedStateManager.set_state(state_key, updated_state)

      # Update metadata
      metadata_key = [:plugins, :metadata, plugin_id]

      UnifiedStateManager.update_state(metadata_key, fn metadata ->
        case metadata do
          nil ->
            %{updated_at: :os.system_time(:millisecond), config: config}

          existing ->
            Map.merge(existing, %{
              updated_at: :os.system_time(:millisecond),
              config: config,
              status: :updated
            })
        end
      end)

      Log.module_debug("Updated legacy state for plugin #{plugin_id}")
      {:ok, updated_state}
    rescue
      error ->
        Log.module_error(
          "Failed to update legacy plugin state for #{plugin_id}: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  @doc """
  Gets plugin state by plugin ID.
  """
  @spec get_plugin_state(plugin_id()) ::
          {:ok, plugin_state()} | {:error, :not_found}
  def get_plugin_state(plugin_id) do
    state_key = [:plugins, :states, plugin_id]

    case UnifiedStateManager.get_state(state_key) do
      nil -> {:error, :not_found}
      state -> {:ok, state}
    end
  end

  @doc """
  Sets plugin state directly.
  """
  @spec set_plugin_state(plugin_id(), plugin_state()) :: :ok
  def set_plugin_state(plugin_id, state) do
    state_key = [:plugins, :states, plugin_id]
    UnifiedStateManager.set_state(state_key, state)
  end

  @doc """
  Updates plugin state using an update function.
  """
  @spec update_plugin_state(plugin_id(), (plugin_state() -> plugin_state())) ::
          {:ok, plugin_state()}
  def update_plugin_state(plugin_id, update_fn) do
    state_key = [:plugins, :states, plugin_id]

    try do
      UnifiedStateManager.update_state(state_key, fn current_state ->
        update_fn.(current_state || %{})
      end)

      # Update metadata timestamp
      metadata_key = [:plugins, :metadata, plugin_id]

      UnifiedStateManager.update_state(metadata_key, fn metadata ->
        case metadata do
          nil ->
            %{updated_at: :os.system_time(:millisecond)}

          existing ->
            Map.put(existing, :updated_at, :os.system_time(:millisecond))
        end
      end)

      {:ok, UnifiedStateManager.get_state(state_key)}
    rescue
      error ->
        Log.module_error(
          "Failed to update plugin state for #{plugin_id}: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  @doc """
  Lists all plugin states.
  """
  @spec list_plugin_states() :: [{plugin_id(), plugin_state()}]
  def list_plugin_states do
    case UnifiedStateManager.get_state([:plugins, :states]) do
      nil -> []
      states when is_map(states) -> Map.to_list(states)
      _ -> []
    end
  end

  @doc """
  Gets plugin metadata.
  """
  @spec get_plugin_metadata(plugin_id()) :: {:ok, map()} | {:error, :not_found}
  def get_plugin_metadata(plugin_id) do
    metadata_key = [:plugins, :metadata, plugin_id]

    case UnifiedStateManager.get_state(metadata_key) do
      nil -> {:error, :not_found}
      metadata -> {:ok, metadata}
    end
  end

  @doc """
  Removes plugin state and metadata.
  """
  @spec remove_plugin(plugin_id()) :: :ok
  def remove_plugin(plugin_id) do
    UnifiedStateManager.delete_state([:plugins, :states, plugin_id])
    UnifiedStateManager.delete_state([:plugins, :metadata, plugin_id])
    Log.module_info("Removed state for plugin #{plugin_id}")
    :ok
  end

  @doc """
  Initializes the plugin state manager subsystem.
  """
  @spec initialize(term()) :: {:ok, term()}
  def initialize(state) do
    # Ensure plugins namespace exists in unified state
    UnifiedStateManager.set_state([:plugins], %{
      states: %{},
      metadata: %{},
      initialized_at: :os.system_time(:millisecond)
    })

    Log.module_info("Plugin state manager initialized")
    {:ok, state}
  end

  @doc """
  Cleans up all plugin states.
  """
  @spec cleanup() :: :ok
  def cleanup do
    UnifiedStateManager.delete_state([:plugins])
    Log.module_info("Plugin state manager cleaned up")
    :ok
  end

  # Private Implementation

  @spec generate_plugin_id(module()) :: any()
  defp generate_plugin_id(plugin_module) do
    plugin_module
    |> to_string()
    |> String.replace("Elixir.", "")
    |> String.downcase()
    |> String.replace(".", "_")
  end

  @spec has_init_callback?(module()) :: boolean()
  defp has_init_callback?(plugin_module) do
    try do
      plugin_module.module_info(:exports)
      |> Keyword.has_key?(:init_state)
    rescue
      _ -> false
    end
  end
end

# Also create the namespaced version for compatibility
defmodule Raxol.Core.Runtime.Plugins.StateManager do
  @moduledoc """
  Namespaced alias for StateManager.

  Provides the same functionality as StateManager but under the proper namespace
  for consistency with the existing codebase structure.
  """

  # Delegate all functions to the main StateManager
  defdelegate initialize_plugin_state(plugin_module, config), to: StateManager

  defdelegate update_plugin_state_legacy(plugin_id, state, config),
    to: StateManager

  defdelegate get_plugin_state(plugin_id), to: StateManager
  defdelegate set_plugin_state(plugin_id, state), to: StateManager
  defdelegate update_plugin_state(plugin_id, update_fn), to: StateManager
  defdelegate list_plugin_states(), to: StateManager
  defdelegate get_plugin_metadata(plugin_id), to: StateManager
  defdelegate remove_plugin(plugin_id), to: StateManager
  defdelegate initialize(state), to: StateManager
  defdelegate cleanup(), to: StateManager

  @doc """
  Gets plugin state with both plugin_id and state parameters for compatibility.
  """
  @spec get_plugin_state(String.t(), term()) :: {:ok, term()}
  def get_plugin_state(plugin_id, _state) do
    StateManager.get_plugin_state(plugin_id)
  end

  @doc """
  Sets plugin state with plugin_id and state parameters for compatibility.
  """
  @spec set_plugin_state(String.t(), term(), term()) :: {:ok, term()}
  def set_plugin_state(plugin_id, state, _current_state) do
    StateManager.set_plugin_state(plugin_id, state)
    {:ok, state}
  end

  @doc """
  Updates plugin state with additional state parameter for compatibility.
  """
  @spec update_plugin_state(String.t(), term(), (term() -> term())) ::
          {:ok, term()}
  def update_plugin_state(plugin_id, _state, update_fn) do
    StateManager.update_plugin_state(plugin_id, update_fn)
  end
end
