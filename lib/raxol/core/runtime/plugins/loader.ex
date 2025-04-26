defmodule Raxol.Core.Runtime.Plugins.Loader do
  @moduledoc """
  Placeholder for the plugin loader.
  Handles loading plugin code and dependencies.
  """

  require Logger

  @doc """
  Loads a plugin module based on its ID.

  Assumes the plugin ID corresponds to an existing module atom.
  Returns the module atom, placeholder metadata, and config.
  """
  @spec load_plugin(atom(), map()) ::
          {:ok, module(), map(), map()} | {:error, term()}
  def load_plugin(plugin_id, config \\ %{})

  def load_plugin(plugin_id, config) when is_atom(plugin_id) do
    Logger.debug(
      "[#{__MODULE__}] Attempting to load plugin: #{inspect(plugin_id)}"
    )

    # Ensure the module code is loaded.
    # In a more complex system, this could involve dynamic compilation or loading .beam files.
    if Code.ensure_loaded?(plugin_id) do
      # TODO: Load actual metadata (e.g., from a manifest file or @behaviour)
      metadata = %{name: plugin_id, version: "0.1.0-dev"}

      Logger.info(
        "[#{__MODULE__}] Successfully loaded plugin: #{inspect(plugin_id)}"
      )

      {:ok, plugin_id, metadata, config}
    else
      Logger.error(
        "[#{__MODULE__}] Failed to load plugin module: #{inspect(plugin_id)}"
      )

      {:error, :module_not_found}
    end
  end

  def load_plugin(plugin_id, _config) do
    Logger.error(
      "[#{__MODULE__}] Invalid plugin ID: #{inspect(plugin_id)}. Must be an atom."
    )

    {:error, :invalid_plugin_id}
  end

  @doc """
  Discovers potential plugin modules in a given directory.

  Scans for `.ex` files and attempts to derive module names.
  Returns a list of `{potential_module_atom, file_path}` tuples.
  """
  def discover_plugins(directory) do
    Logger.debug("[#{__MODULE__}] Discovering plugins in: #{directory}")
    plugin_files = Path.wildcard(Path.join(directory, "**/*.ex"))

    Enum.map(plugin_files, fn file_path ->
      # Basic module name derivation (Assumes standard lib/ structure mapping)
      # Example: priv/plugins/my_plugin/core.ex -> MyPlugin.Core (Needs adjustment based on actual structure)
      # This is a placeholder and likely needs a more robust implementation.
      module_name = file_path
                    |> Path.relative_to(directory) # Get path relative to discovery dir
                    |> Path.rootname() # Remove .ex
                    |> String.split("/")
                    |> Enum.map(&Macro.camelize/1)
                    |> Enum.join(".")

      module_atom = try do
        String.to_existing_atom("Elixir." <> module_name)
      rescue ArgumentError ->
        Logger.warning("[#{__MODULE__}] Could not convert derived module name '#{module_name}' to existing atom for file: #{file_path}. Skipping file.")
        nil # Indicate failure for this file
      end

      {module_atom, file_path}
    end)
    |> Enum.filter(fn {module_atom, _file_path} -> !is_nil(module_atom) end) # Filter out failures
  end

  @doc """
  Sorts plugins based on dependencies (Placeholder).

  Currently returns the input list unsorted.
  Requires metadata extraction to be implemented first for actual sorting.
  Returns `{:ok, sorted_plugin_ids}` or `{:error, reason}`.
  """
  def sort_plugins(plugin_list) do
    # TODO: Implement topological sort based on dependencies extracted from metadata.
    Logger.debug("[#{__MODULE__}] Sorting plugins (placeholder - returning original order).")
    {:ok, plugin_list}
  end

  @doc """
  Extracts metadata for a given plugin module.

  Checks if the plugin implements `Raxol.Core.Runtime.Plugins.PluginMetadataProvider`.
  If so, it calls `get_metadata/0` on the module.
  Otherwise, it returns a default metadata map derived from the module name.
  """
  def extract_metadata(plugin_module) when is_atom(plugin_module) do
    # Check using standard behaviour introspection
    provider_behaviour = Raxol.Core.Runtime.Plugins.PluginMetadataProvider
    has_behaviour = function_exported?(plugin_module, :behaviour_info, 1) and
                  Enum.member?(plugin_module.behaviour_info(:callbacks), {:behaviour, [provider_behaviour]}) # Check callbacks instead

    if has_behaviour do
      try do
        Logger.debug("[#{__MODULE__}] Found #{inspect(provider_behaviour)} implementation for #{inspect(plugin_module)}. Calling get_metadata/0.")
        plugin_module.get_metadata()
      rescue
        e ->
          Logger.error("[#{__MODULE__}] Error calling get_metadata/0 for #{inspect(plugin_module)}: #{inspect(e)}")
          # Fallback to default if get_metadata fails
          default_metadata(plugin_module)
      end
    else
      Logger.debug("[#{__MODULE__}] #{inspect(provider_behaviour)} not implemented by #{inspect(plugin_module)}. Using default metadata.")
      default_metadata(plugin_module)
    end
  end

  # Helper to generate default metadata
  defp default_metadata(plugin_module) do
    plugin_id = module_to_default_id(plugin_module)
    %{id: plugin_id, version: "0.0.0-dev", dependencies: []}
  end

  # Helper to derive a default plugin ID from the module name (basic example)
  def module_to_default_id(plugin_module) do
    plugin_module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.replace_suffix("_plugin", "") # Optional: remove common suffix
    |> String.to_atom()
  end

  @doc """
  Ensures the code for a given plugin module is loaded.
  Returns `:ok` or `{:error, :module_not_found}`.
  """
  def load_code(plugin_module) when is_atom(plugin_module) do
    if Code.ensure_loaded?(plugin_module) do
      :ok
    else
      Logger.error("[#{__MODULE__}] Failed to ensure module code is loaded: #{inspect(plugin_module)}")
      {:error, :module_not_found}
    end
  end
end
