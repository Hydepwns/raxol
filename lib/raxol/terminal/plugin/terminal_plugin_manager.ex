defmodule Raxol.Terminal.Plugin.Manager do
  @moduledoc """
  Manages terminal plugins with advanced features:
  - Plugin loading and unloading
  - Plugin lifecycle management
  - Plugin API and hooks
  - Plugin configuration and state management
  """

  @type plugin :: %{
          name: String.t(),
          version: String.t(),
          description: String.t(),
          author: String.t(),
          hooks: [String.t()],
          config: map(),
          state: map()
        }

  @type hook :: %{
          name: String.t(),
          callback: function(),
          priority: integer()
        }

  @type t :: %__MODULE__{
          plugins: %{String.t() => plugin()},
          hooks: %{String.t() => [hook()]},
          config: map(),
          metrics: %{
            plugin_loads: integer(),
            plugin_unloads: integer(),
            hook_calls: integer(),
            config_updates: integer()
          }
        }

  defstruct [
    :plugins,
    :hooks,
    :config,
    :metrics
  ]

  @doc """
  Creates a new plugin manager with the given options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      plugins: %{},
      hooks: %{},
      config: Map.new(opts),
      metrics: %{
        plugin_loads: 0,
        plugin_unloads: 0,
        hook_calls: 0,
        config_updates: 0
      }
    }
  end

  @doc """
  Loads a plugin into the manager.
  """
  @spec load_plugin(t(), plugin()) :: {:ok, t()} | {:error, term()}
  def load_plugin(manager, plugin) do
    with :ok <- validate_plugin(plugin),
         :ok <- check_plugin_conflicts(manager, plugin) do
      updated_plugins = Map.put(manager.plugins, plugin.name, plugin)
      updated_hooks = register_plugin_hooks(manager.hooks, plugin)

      updated_manager = %{
        manager
        | plugins: updated_plugins,
          hooks: updated_hooks,
          metrics: update_metrics(manager.metrics, :plugin_loads)
      }

      {:ok, updated_manager}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Unloads a plugin from the manager.
  """
  @spec unload_plugin(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def unload_plugin(manager, plugin_name) do
    case Map.get(manager.plugins, plugin_name) do
      nil ->
        {:error, :plugin_not_found}

      plugin ->
        updated_plugins = Map.delete(manager.plugins, plugin_name)
        updated_hooks = unregister_plugin_hooks(manager.hooks, plugin)

        updated_manager = %{
          manager
          | plugins: updated_plugins,
            hooks: updated_hooks,
            metrics: update_metrics(manager.metrics, :plugin_unloads)
        }

        {:ok, updated_manager}
    end
  end

  @doc """
  Calls a hook with the given arguments.
  """
  @spec call_hook(t(), String.t(), [term()]) ::
          {:ok, [term()], t()} | {:error, term()}
  def call_hook(manager, hook_name, args \\ []) do
    case Map.get(manager.hooks, hook_name) do
      nil ->
        {:error, :hook_not_found}

      hooks ->
        results =
          Enum.map(hooks, fn hook ->
            apply_hook(hook, args)
          end)

        updated_manager = %{
          manager
          | metrics: update_metrics(manager.metrics, :hook_calls)
        }

        {:ok, results, updated_manager}
    end
  end

  @doc """
  Updates the configuration for a plugin.
  """
  @spec update_plugin_config(t(), String.t(), map()) ::
          {:ok, t()} | {:error, term()}
  def update_plugin_config(manager, plugin_name, config) do
    case Map.get(manager.plugins, plugin_name) do
      nil ->
        {:error, :plugin_not_found}

      plugin ->
        updated_plugin = %{plugin | config: Map.merge(plugin.config, config)}
        updated_plugins = Map.put(manager.plugins, plugin_name, updated_plugin)

        updated_manager = %{
          manager
          | plugins: updated_plugins,
            metrics: update_metrics(manager.metrics, :config_updates)
        }

        {:ok, updated_manager}
    end
  end

  @doc """
  Gets the current plugin metrics.
  """
  @spec get_metrics(t()) :: map()
  def get_metrics(manager) do
    manager.metrics
  end

  # Private helper functions

  defp validate_plugin(plugin) do
    required_fields = [
      :name,
      :version,
      :description,
      :author,
      :hooks,
      :config,
      :state
    ]

    case Enum.all?(required_fields, &Map.has_key?(plugin, &1)) do
      true ->
        :ok

      false ->
        {:error, :invalid_plugin}
    end
  end

  defp check_plugin_conflicts(manager, plugin) do
    case Map.has_key?(manager.plugins, plugin.name) do
      true ->
        {:error, :plugin_already_loaded}

      false ->
        :ok
    end
  end

  defp register_plugin_hooks(hooks, plugin) do
    Enum.reduce(plugin.hooks, hooks, fn hook_name, acc ->
      hook = %{
        name: hook_name,
        callback: &apply_hook/2,
        priority: 0
      }

      Map.update(acc, hook_name, [hook], &[hook | &1])
    end)
  end

  defp unregister_plugin_hooks(hooks, plugin) do
    Enum.reduce(plugin.hooks, hooks, fn hook_name, acc ->
      Map.update(
        acc,
        hook_name,
        [],
        &Enum.reject(&1, fn h -> h.name == plugin.name end)
      )
    end)
  end

  defp apply_hook(hook, args) do
    case Raxol.Core.ErrorHandling.safe_call(fn -> hook.callback.(args) end) do
      {:ok, result} -> result
      {:error, e} -> {:error, {:hook_error, e}}
    end
  end

  defp update_metrics(metrics, :plugin_loads) do
    update_in(metrics.plugin_loads, &(&1 + 1))
  end

  defp update_metrics(metrics, :plugin_unloads) do
    update_in(metrics.plugin_unloads, &(&1 + 1))
  end

  defp update_metrics(metrics, :hook_calls) do
    update_in(metrics.hook_calls, &(&1 + 1))
  end

  defp update_metrics(metrics, :config_updates) do
    update_in(metrics.config_updates, &(&1 + 1))
  end
end
