defmodule Raxol.Core.Runtime.Plugins.Loader do
  @moduledoc """
  Handles loading plugin code, metadata, and discovery.
  Implements the `Raxol.Core.Runtime.Plugins.LoaderBehaviour`.
  """
  @behaviour Raxol.Core.Runtime.Plugins.LoaderBehaviour

  require Logger

  # --- LoaderBehaviour Callbacks ---

  @impl Raxol.Core.Runtime.Plugins.LoaderBehaviour
  def discover_plugins(plugin_dirs) when is_list(plugin_dirs) do
    Logger.debug(
      "[#{__MODULE__}] Discovering plugins in: #{inspect(plugin_dirs)}"
    )

    discovered_plugins =
      Enum.flat_map(plugin_dirs, fn directory ->
        plugin_files = Path.wildcard(Path.join(directory, "**/*.ex"))

        Enum.map(plugin_files, fn file_path ->
          module_name_str =
            file_path
            |> Path.relative_to(directory)
            |> Path.rootname()
            |> String.split("/")
            |> Enum.map(&Macro.camelize/1)
            |> Enum.join(".")

          module_atom =
            try do
              String.to_existing_atom("Elixir." <> module_name_str)
            rescue
              ArgumentError ->
                Logger.warning(
                  "[#{__MODULE__}] Could not convert derived module name '#{module_name_str}' to existing atom for file: #{file_path}. Skipping file."
                )

                nil
            end

          if module_atom do
            # Derive a default ID from the module atom
            plugin_id = module_to_default_id(module_atom)
            %{module: module_atom, path: file_path, id: plugin_id}
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      end)

    Logger.info(
      "[#{__MODULE__}] Discovered #{length(discovered_plugins)} potential plugins."
    )

    {:ok, discovered_plugins}
  rescue
    e ->
      Logger.error(
        "[#{__MODULE__}] Error during plugin discovery: #{inspect(e)}"
      )

      {:error, :discovery_failed}
  end

  @impl Raxol.Core.Runtime.Plugins.LoaderBehaviour
  def load_plugin_metadata(module_atom) when is_atom(module_atom) do
    # For now, we assume metadata is intrinsically part of the module or accessed via it.
    # The primary goal here is to ensure the module providing metadata is "loaded" or accessible.
    # If the module has a `metadata/0` function (checked by PluginMetadataProvider), that's preferred.
    if Code.ensure_loaded?(module_atom) do
      # Attempt to call metadata/0 if module implements PluginMetadataProvider
      # This is more for verification; the actual metadata might be read by LifecycleHelper
      cond do
        function_exported?(module_atom, :behaviour_info, 1) and
          Enum.any?(module_atom.behaviour_info(:callbacks), fn {b, _} ->
            b == Raxol.Core.Runtime.Plugins.PluginMetadataProvider
          end) and
            function_exported?(module_atom, :metadata, 0) ->
          try do
            _metadata = module_atom.metadata()

            Logger.debug(
              "[#{__MODULE__}] Successfully called metadata/0 on #{inspect(module_atom)}."
            )

            # Return the module itself, as per callback expectation
            {:ok, module_atom}
          rescue
            e ->
              Logger.error(
                "[#{__MODULE__}] Error calling metadata/0 on #{inspect(module_atom)}: #{inspect(e)}"
              )

              {:error, :metadata_call_failed}
          end

        true ->
          # Module doesn't provide metadata via PluginMetadataProvider, but it's loaded.
          Logger.debug(
            "[#{__MODULE__}] Module #{inspect(module_atom)} loaded, metadata to be handled by caller or defaults."
          )

          {:ok, module_atom}
      end
    else
      Logger.error(
        "[#{__MODULE__}] Failed to ensure module for metadata is loaded: #{inspect(module_atom)}"
      )

      {:error, :module_not_found_for_metadata}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.LoaderBehaviour
  def load_plugin_module(module_atom) when is_atom(module_atom) do
    if Code.ensure_loaded?(module_atom) do
      Logger.debug(
        "[#{__MODULE__}] Module code ensured loaded for: #{inspect(module_atom)}"
      )

      {:ok, module_atom}
    else
      Logger.error(
        "[#{__MODULE__}] Failed to ensure module code is loaded: #{inspect(module_atom)}"
      )

      {:error, :module_not_found}
    end
  end

  # --- Existing Helper Functions (modified or kept as is) ---

  @doc """
  Helper to derive a default plugin ID from the module name.
  Example: `MyOrg.MyPlugin` becomes `:my_plugin`.
  """
  def module_to_default_id(plugin_module) when is_atom(plugin_module) do
    plugin_module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    # Example: remove a common suffix like _plugin, if desired by convention
    # |> String.replace_suffix("_plugin", "")
    |> String.to_atom()
  end

  # --- Potentially Deprecated or Internal Functions ---
  # Review if these are still needed or if their logic is now part of the behaviour implementations.

  @doc """
  Loads a plugin module based on its ID (Original function - consider for removal or refactor).

  Assumes the plugin ID corresponds to an existing module atom.
  Returns the module atom, placeholder metadata, and config.
  """
  @spec load_plugin(atom(), map()) ::
          {:ok, module(), map(), map()} | {:error, term()}
  def load_plugin(plugin_id, config \\ %{})

  def load_plugin(plugin_id, config) when is_atom(plugin_id) do
    Logger.debug(
      "[#{__MODULE__}] Attempting to load plugin (legacy): #{inspect(plugin_id)}"
    )

    # This function's logic might be superseded by the behaviour implementations.
    # For now, it can delegate or be kept for specific internal uses not covered by behaviour.
    case load_plugin_module(plugin_id) do
      {:ok, module} ->
        # Simplified metadata fetching for this legacy function
        # Uses a simplified default
        metadata = default_metadata(module)

        Logger.info(
          "[#{__MODULE__}] Successfully loaded plugin (legacy): #{inspect(plugin_id)}"
        )

        {:ok, module, metadata, config}

      {:error, reason} ->
        Logger.error(
          "[#{__MODULE__}] Failed to load plugin module (legacy): #{inspect(plugin_id)}, reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def load_plugin(plugin_id, _config) do
    Logger.error(
      "[#{__MODULE__}] Invalid plugin ID (legacy): #{inspect(plugin_id)}. Must be an atom."
    )

    {:error, :invalid_plugin_id}
  end

  @doc """
  Sorts plugins based on dependencies (Placeholder - consider for removal or refactor).

  Currently returns the input list unsorted.
  Requires metadata extraction to be implemented first for actual sorting.
  Returns `{:ok, sorted_plugin_ids}` or `{:error, reason}`.
  """
  def sort_plugins(plugin_list) do
    # TODO: Implement topological sort based on dependencies extracted from metadata.
    Logger.debug(
      "[#{__MODULE__}] Sorting plugins (placeholder - returning original order)."
    )

    {:ok, plugin_list}
  end

  @doc """
  Extracts metadata for a given plugin module (Original function - consider for removal or refactor).

  Checks if the plugin implements `Raxol.Core.Runtime.Plugins.PluginMetadataProvider`.
  If so, it calls `get_metadata/0` on the module.
  Otherwise, it returns a default metadata map derived from the module name.
  """
  def extract_metadata(plugin_module) when is_atom(plugin_module) do
    # This logic is partially integrated into load_plugin_metadata, but kept for reference
    provider_behaviour = Raxol.Core.Runtime.Plugins.PluginMetadataProvider

    has_provider_behaviour =
      function_exported?(plugin_module, :behaviour_info, 1) &&
        Enum.any?(plugin_module.behaviour_info(:callbacks), fn {b, _} ->
          b == provider_behaviour
        end)

    if has_provider_behaviour && function_exported?(plugin_module, :metadata, 0) do
      try do
        Logger.debug(
          "[#{__MODULE__}] Found #{inspect(provider_behaviour)} (legacy check). Calling metadata/0."
        )

        plugin_module.metadata()
      rescue
        e ->
          Logger.error(
            "[#{__MODULE__}] Error calling metadata/0 (legacy check) for #{inspect(plugin_module)}: #{inspect(e)}"
          )

          default_metadata(plugin_module)
      end
    else
      Logger.debug(
        "[#{__MODULE__}] #{inspect(provider_behaviour)} not implemented or metadata/0 not exported (legacy check). Using default metadata."
      )

      default_metadata(plugin_module)
    end
  end

  # Helper to generate default metadata (used by legacy and potentially new functions)
  defp default_metadata(plugin_module) do
    plugin_id = module_to_default_id(plugin_module)
    %{id: plugin_id, version: "0.0.0-dev", dependencies: []}
  end

  @doc """
  Ensures the code for a given plugin module is loaded (Original function - renamed to load_code).
  Returns `:ok` or `{:error, :module_not_found}`.
  """
  def load_code(plugin_module) when is_atom(plugin_module) do
    # This is essentially what load_plugin_module does now.
    if Code.ensure_loaded?(plugin_module) do
      :ok
    else
      Logger.error(
        "[#{__MODULE__}] Failed to ensure module code is loaded (legacy load_code): #{inspect(plugin_module)}"
      )

      {:error, :module_not_found}
    end
  end
end
