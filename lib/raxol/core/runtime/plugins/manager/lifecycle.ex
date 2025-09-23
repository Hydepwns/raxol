defmodule Raxol.Core.Runtime.Plugins.PluginManager.Lifecycle do
  @moduledoc """
  Handles plugin lifecycle operations - initialization, loading, enabling, disabling, and unloading.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.LifecycleManager
  alias Raxol.Core.Runtime.Plugins.Discovery

  @type plugin_id :: String.t()
  @type state :: map()
  @type result :: {:ok, state()} | {:error, term()}

  @doc """
  Initializes the plugin manager with discovered plugins.
  """
  @spec initialize(state()) :: result()
  def initialize(state) do
    case Discovery.discover_plugins(state) do
      {:ok, updated_state} ->
        initialized_state = %{updated_state | initialized: true}
        {:ok, initialized_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Failed to initialize plugins",
          nil,
          nil,
          %{module: __MODULE__, reason: reason}
        )

        {:error, reason}
    end
  end

  @doc """
  Initializes the plugin manager with provided configuration.
  """
  @spec initialize_with_config(state(), map()) :: result()
  def initialize_with_config(state, config) do
    updated_state = %{state | plugin_config: config}
    initialize(updated_state)
  end

  @doc """
  Enables a plugin by its ID.
  """
  @spec enable_plugin(state(), plugin_id()) :: result()
  def enable_plugin(state, plugin_id) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, {:plugin_not_found, plugin_id}}

      _plugin ->
        case LifecycleManager.enable_plugin(plugin_id, state) do
          {:ok, updated_state} ->
            {:ok, updated_state}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Disables a plugin by its ID.
  """
  @spec disable_plugin(state(), plugin_id()) :: result()
  def disable_plugin(state, plugin_id) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, {:plugin_not_found, plugin_id}}

      _plugin ->
        case LifecycleManager.disable_plugin(plugin_id, state) do
          {:ok, updated_state} ->
            {:ok, updated_state}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Reloads a plugin by its ID.
  """
  @spec reload_plugin(state(), plugin_id()) :: result()
  def reload_plugin(state, plugin_id) do
    with {:ok, disabled_state} <- disable_plugin(state, plugin_id),
         {:ok, reloaded_state} <- load_plugin(disabled_state, plugin_id),
         {:ok, enabled_state} <- enable_plugin(reloaded_state, plugin_id) do
      {:ok, enabled_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Loads a plugin by module with optional configuration.
  """
  @spec load_plugin_by_module(state(), module(), map()) :: result()
  def load_plugin_by_module(state, module, config \\ %{}) do
    # Create a simple wrapper that provides default parameters for the complex function
    case load_plugin_by_module_wrapper(state, module, config) do
      {:ok, plugin} ->
        plugin_id = plugin.id
        updated_plugins = Map.put(state.plugins, plugin_id, plugin)
        updated_state = %{state | plugins: updated_plugins}
        {:ok, updated_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Loads a plugin by its ID.
  """
  @spec load_plugin(state(), plugin_id()) :: result()
  def load_plugin(state, plugin_id) do
    # For now, just proceed with loading since discovery happens elsewhere
    case load_plugin_wrapper(state, plugin_id) do
      {:ok, updated_state} ->
        {:ok, updated_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Unloads a plugin by its ID.
  """
  @spec unload_plugin(state(), plugin_id()) :: result()
  def unload_plugin(state, plugin_id) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, {:plugin_not_found, plugin_id}}

      _plugin ->
        case unload_plugin_wrapper(state, plugin_id) do
          {:ok, updated_state} ->
            {:ok, updated_state}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Initializes a specific plugin with configuration.
  """
  @spec initialize_plugin(state(), plugin_id(), map()) :: result()
  def initialize_plugin(state, plugin_name, _config) do
    case Map.get(state.plugins, plugin_name) do
      nil ->
        {:error, {:plugin_not_found, plugin_name}}

      _plugin ->
        case initialize_plugin_wrapper(state, plugin_name) do
          {:ok, updated_state} ->
            {:ok, updated_state}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Validates plugin configuration.
  """
  @spec validate_plugin_config(plugin_id(), map()) :: :ok | {:error, term()}
  def validate_plugin_config(plugin_name, config) do
    case validate_plugin_config_wrapper(config, plugin_name) do
      {:ok, _config} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Wrapper functions to provide simpler interfaces to complex LifecycleManager functions

  defp load_plugin_wrapper(state, plugin_id) do
    # For now, just return success - this would need proper implementation
    # based on the actual state structure and requirements
    case plugin_id do
      nil -> {:error, :invalid_plugin_id}
      _ -> {:ok, state}
    end
  end

  defp load_plugin_by_module_wrapper(_state, module, config) do
    # Actually initialize the plugin to test for init crashes
    with {:valid_module, true} <- {:valid_module, module != nil},
         {:ok, plugin_result} <-
           Raxol.Core.ErrorHandling.safe_call(fn -> module.init(config) end) do
      case plugin_result do
        {:ok, plugin_state} ->
          plugin = %{
            id: inspect(module),
            module: module,
            config: config,
            state: plugin_state,
            status: :loaded
          }

          {:ok, plugin}

        {:error, reason} ->
          {:error, reason}

        _ ->
          {:error, :invalid_init_response}
      end
    else
      {:valid_module, false} ->
        {:error, :invalid_module}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp unload_plugin_wrapper(state, plugin_id) do
    case plugin_id do
      nil -> {:error, :invalid_plugin_id}
      _ -> {:ok, state}
    end
  end

  defp initialize_plugin_wrapper(state, plugin_id) do
    case plugin_id do
      nil -> {:error, :invalid_plugin_id}
      _ -> {:ok, state}
    end
  end

  defp validate_plugin_config_wrapper(config, _schema) do
    # Simple validation - just return ok for now
    case config do
      nil -> {:error, :invalid_config}
      _ -> {:ok, config}
    end
  end
end
