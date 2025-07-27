defmodule Raxol.Plugins.Lifecycle.Dependencies do
  @moduledoc """
  Handles dependency validation, circular dependency checks, and load order resolution for plugin lifecycle management.
  """

  alias Raxol.Core.Runtime.Plugins.DependencyManager
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

      {:error, reason} ->
        {:error, reason}
    end
  end

  def check_dependencies(plugin, manager) do
    loaded_plugins_map =
      Core.list_plugins(manager)
      |> Enum.map(fn plugin -> {plugin.name, plugin} end)
      |> Enum.into(%{})

    DependencyManager.check_dependencies(
      plugin.name,
      plugin,
      loaded_plugins_map,
      []
    )
  end

  def resolve_plugin_order(initialized_plugins) do
    case DependencyManager.resolve_load_order(
           for plugin <- initialized_plugins,
               into: %{},
               do: {plugin.name, plugin}
         ) do
      {:ok, sorted_plugin_names} ->
        {:ok, Enum.map(sorted_plugin_names, &normalize_plugin_key/1)}

      {:error, cycle} ->
        {:error, :circular_dependency, cycle, nil}

      other ->
        {:error, :resolve_failed, other}
    end
  end

  def check_for_circular_dependency(plugin, manager) do
    plugin_key = plugin.name

    plugins =
      manager.plugins
      |> Enum.map(fn {k, v} ->
        key = if is_atom(k), do: Atom.to_string(k), else: k
        {key, v}
      end)
      |> Enum.into(%{})
      |> Map.put(plugin_key, plugin)

    case Raxol.Core.Runtime.Plugins.DependencyManager.Core.resolve_load_order(
           plugins
         ) do
      {:ok, _order} ->
        :ok

      {:error, :circular_dependency, _cycle, _chain} ->
        {:error, {:circular_dependency, plugin.name}}

      _other ->
        :ok
    end
  end

  # Helper to normalize plugin keys to strings
  def normalize_plugin_key(key) when is_atom(key), do: Atom.to_string(key)
  def normalize_plugin_key(key) when is_binary(key), do: key
end
