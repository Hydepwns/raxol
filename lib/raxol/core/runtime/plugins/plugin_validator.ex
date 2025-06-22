defmodule Raxol.Core.Runtime.Plugins.PluginValidator do
  @moduledoc """
  Handles validation of plugins before loading.
  """

  alias Raxol.Core.Runtime.Plugins.Loader

  @doc """
  Validates that a plugin is not already loaded and implements required behaviour.
  """
  def validate_plugin(plugin_id, plugin_module, plugins) do
    validate_not_loaded(plugin_id, plugins)
    |> and_then(fn :ok -> validate_behaviour(plugin_module) end)
  end

  @doc """
  Validates that a plugin is not already loaded.
  """
  def validate_not_loaded(plugin_id, plugins) do
    if Map.has_key?(plugins, plugin_id) do
      {:error, :already_loaded}
    else
      :ok
    end
  end

  @doc """
  Validates that a plugin module implements the required behaviour.
  """
  def validate_behaviour(plugin_module) do
    if Loader.behaviour_implemented?(
         plugin_module,
         Raxol.Core.Runtime.Plugins.Plugin
       ) do
      :ok
    else
      {:error, :invalid_plugin}
    end
  end

  @doc """
  Resolves plugin identity from string or module.
  """
  def resolve_plugin_identity(id) do
    case Raxol.Core.Runtime.Plugins.Loader.load_code(id) do
      :ok -> {:ok, {id, nil}}
      {:error, :module_not_found} -> {:error, :module_not_found}
    end
  end

  # Helper function for chaining validation steps
  defp and_then(:ok, fun), do: fun.()
  defp and_then(error, _fun), do: error
end
