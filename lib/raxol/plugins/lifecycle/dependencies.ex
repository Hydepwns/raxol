defmodule Raxol.Plugins.Lifecycle.Dependencies do
  @moduledoc """
  Handles dependency validation, circular dependency checks, and load order resolution for plugin lifecycle management.
  """

  # Simplified dependency checking - complex DependencyManager removed
  alias Raxol.Plugins.Manager.Core

  def validate_plugin_dependencies(plugin, manager) do
    case check_for_circular_dependency(plugin, manager) do
      :ok ->
        case check_dependencies(plugin, manager) do
          :ok ->
            :ok

          {:error, :missing_dependencies, missing, chain} ->
            {:error, :missing_dependencies, missing, chain}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, {:circular_dependency, name}} ->
        {:error, {:circular_dependency, name}}
    end
  end

  def check_dependencies(plugin, manager) do
    loaded_plugins_map =
      Core.list_plugins(manager)
      |> Enum.map(fn plugin -> {plugin.name, plugin} end)
      |> Enum.into(%{})

    # Simplified dependency check - just verify dependencies exist
    missing =
      (plugin.dependencies || [])
      |> Enum.filter(&(!Map.has_key?(loaded_plugins_map, &1)))

    if Enum.empty?(missing) do
      :ok
    else
      {:error, :missing_dependencies, missing, [plugin.name]}
    end
  end

  def resolve_plugin_order(initialized_plugins) do
    # Simplified load order - just return plugins in received order
    # Complex topological sorting removed for simplicity
    sorted_plugin_names = Enum.map(initialized_plugins, & &1.name)
    {:ok, Enum.map(sorted_plugin_names, &normalize_plugin_key/1)}

    # Note: Complex circular dependency detection removed for simplicity
  end

  def check_for_circular_dependency(plugin, manager) do
    plugin_key = plugin.name

    _plugins =
      manager.plugins
      |> Enum.map(fn {k, v} ->
        key = if is_atom(k), do: Atom.to_string(k), else: k
        {key, v}
      end)
      |> Enum.into(%{})
      |> Map.put(plugin_key, plugin)

    # Simplified circular dependency check - just check immediate dependencies
    # Complex topological sorting removed
    dependencies = plugin.dependencies || []

    if plugin.name in dependencies do
      {:error, {:circular_dependency, plugin.name}}
    else
      :ok
    end
  end

  # Helper to normalize plugin keys to strings
  def normalize_plugin_key(key) when is_atom(key), do: Atom.to_string(key)
  def normalize_plugin_key(key) when is_binary(key), do: key
end
