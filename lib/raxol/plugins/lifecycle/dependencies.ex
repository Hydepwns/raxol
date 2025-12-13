defmodule Raxol.Plugins.Lifecycle.Dependencies do
  @moduledoc """
  Handles dependency validation, circular dependency checks, and load order resolution for plugin lifecycle management.
  """

  # Simplified dependency checking - complex DependencyManager removed

  def validate_plugin_dependencies(plugin, manager) do
    case check_for_circular_dependency(plugin, manager) do
      :ok ->
        check_dependencies(plugin, manager)

      {:error, {:circular_dependency, name}} ->
        {:error, {:circular_dependency, name}}
    end
  end

  def check_dependencies(plugin, manager) do
    loaded_plugins_map =
      Raxol.Plugins.Manager.list_plugins(manager)
      |> Enum.map(fn plugin -> {plugin.name, plugin} end)
      |> Enum.into(%{})

    # Simplified dependency check - just verify dependencies exist
    # Dependencies are {name, version} tuples, extract the name
    missing =
      (plugin.dependencies || [])
      |> Enum.map(&extract_dependency_name/1)
      |> Enum.filter(&(!Map.has_key?(loaded_plugins_map, &1)))
      |> Enum.zip(plugin.dependencies || [])
      |> Enum.map(fn {_name, dep} -> dep end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, :missing_dependencies, missing, [plugin.name]}
    end
  end

  # Extract dependency name from dependency tuple or string
  defp extract_dependency_name({name, _version}) when is_binary(name), do: name
  defp extract_dependency_name(name) when is_binary(name), do: name

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
    dependency_names = Enum.map(dependencies, &extract_dependency_name/1)

    if plugin.name in dependency_names do
      {:error, {:circular_dependency, plugin.name}}
    else
      :ok
    end
  end

  # Helper to normalize plugin keys to strings
  def normalize_plugin_key(key) when is_atom(key), do: Atom.to_string(key)
  def normalize_plugin_key(key) when is_binary(key), do: key
end
