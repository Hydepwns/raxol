defmodule Raxol.Plugins.PluginDependency do
  @moduledoc '''
  Provides utilities for plugin dependency and API compatibility checks.
  '''

  @doc '''
  Checks if the plugin's API version is compatible with the manager's API version.
  Returns :ok if compatible, {:error, :api_incompatible} otherwise.
  Compatibility is defined as matching major version (e.g., 1.x.x == 1.y.z).
  '''
  def check_api_compatibility(plugin_api_version, manager_api_version)
      when is_binary(plugin_api_version) and is_binary(manager_api_version) do
    case {parse_major(plugin_api_version), parse_major(manager_api_version)} do
      {major, major} when is_integer(major) -> :ok
      {_plugin_major, _manager_major} -> {:error, :api_incompatible}
    end
  end

  defp parse_major(version) do
    case String.split(version, ".") do
      [major | _] ->
        case Integer.parse(major) do
          {int, _} -> int
          :error -> nil
        end

      _ ->
        nil
    end
  end
end
