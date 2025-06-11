defmodule Raxol.Core.Runtime.Plugins.Loader do
  @moduledoc """
  Handles loading and management of plugins.
  """

  use Raxol.UI.Components.Base.Component

  alias Raxol.Core.Runtime.Plugins.Loader.Behaviour

  @behaviour Behaviour

  require Raxol.Core.Runtime.Log

  # --- Component Callbacks ---

  @impl Raxol.UI.Components.Base.Component
  def init(_props) do
    {:ok, %{}}
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(_event, _opts, state) do
    {:ok, state}
  end

  @impl Raxol.UI.Components.Base.Component
  def render(_props, _state) do
    {:ok, []}
  end

  @impl Raxol.UI.Components.Base.Component
  def update(_props, state) do
    {:ok, state}
  end

  # --- Loader.Behaviour Callbacks ---

  @impl true
  def discover_plugins(plugin_dirs) when is_list(plugin_dirs) do
    Raxol.Core.Runtime.Log.debug(
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
                Raxol.Core.Runtime.Log.warning_with_context(
                  "[#{__MODULE__}] Could not convert derived module name '#{module_name_str}' to existing atom for file: #{file_path}. Skipping file.",
                  %{
                    module: __MODULE__,
                    file_path: file_path,
                    module_name_str: module_name_str
                  }
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

    Raxol.Core.Runtime.Log.info(
      "[#{__MODULE__}] Discovered #{length(discovered_plugins)} potential plugins."
    )

    {:ok, discovered_plugins}
  rescue
    e ->
      Raxol.Core.Runtime.Log.error_with_stacktrace(
        "[#{__MODULE__}] Error during plugin discovery",
        e,
        nil,
        %{module: __MODULE__, plugin_dirs: plugin_dirs}
      )

      {:error, :discovery_failed}
  end

  @impl true
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
            metadata = module_atom.metadata()

            # --- ADDED VALIDATION ---
            version = Map.get(metadata, :version)
            id = Map.get(metadata, :id)
            dependencies = Map.get(metadata, :dependencies, [])

            optional_dependencies =
              Map.get(metadata, :optional_dependencies, [])

            name = Map.get(metadata, :name)
            description = Map.get(metadata, :description)
            author = Map.get(metadata, :author)

            errors = []

            # Helper to check if a value is a non-empty string (trimmed)
            is_nonempty_string = fn val ->
              is_binary(val) and String.trim(val) != ""
            end

            # Validate :id
            errors =
              cond do
                is_nil(id) ->
                  [:missing_id | errors]

                is_binary(id) and String.trim(id) == "" ->
                  [:empty_id | errors]

                not (is_atom(id) or is_nonempty_string.(id)) ->
                  [:invalid_id_type | errors]

                true ->
                  errors
              end

            # Validate :version (semver check already below)
            errors =
              if not is_nonempty_string.(version) do
                [:missing_version | errors]
              else
                errors
              end

            # Validate :dependencies
            errors =
              cond do
                is_nil(dependencies) ->
                  [:missing_dependencies | errors]

                is_list(dependencies) == false ->
                  [:invalid_dependencies_type | errors]

                true ->
                  Enum.reduce(dependencies, errors, fn dep, acc ->
                    case dep do
                      {dep_id, ver_req} ->
                        valid_id =
                          is_atom(dep_id) or is_nonempty_string.(dep_id)

                        valid_ver = is_binary(ver_req)

                        if valid_id and valid_ver,
                          do: acc,
                          else: [:invalid_dependency_format | acc]

                      {dep_id, ver_req, _opts} ->
                        valid_id =
                          is_atom(dep_id) or is_nonempty_string.(dep_id)

                        valid_ver = is_binary(ver_req)

                        if valid_id and valid_ver,
                          do: acc,
                          else: [:invalid_dependency_format | acc]

                      _ ->
                        [:invalid_dependency_format | acc]
                    end
                  end)
              end

            # Validate :optional_dependencies
            errors =
              if optional_dependencies != nil and
                   not is_list(optional_dependencies) do
                [:invalid_optional_dependencies_type | errors]
              else
                Enum.reduce(optional_dependencies || [], errors, fn dep, acc ->
                  case dep do
                    {dep_id, ver_req} ->
                      valid_id = is_atom(dep_id) or is_nonempty_string.(dep_id)
                      valid_ver = is_binary(ver_req)

                      if valid_id and valid_ver,
                        do: acc,
                        else: [:invalid_optional_dependency_format | acc]

                    {dep_id, ver_req, _opts} ->
                      valid_id = is_atom(dep_id) or is_nonempty_string.(dep_id)
                      valid_ver = is_binary(ver_req)

                      if valid_id and valid_ver,
                        do: acc,
                        else: [:invalid_optional_dependency_format | acc]

                    _ ->
                      [:invalid_optional_dependency_format | acc]
                  end
                end)
              end

            # Validate :name, :description, :author (if present)
            errors =
              if name != nil and not is_nonempty_string.(name) do
                [:invalid_name | errors]
              else
                errors
              end

            errors =
              if description != nil and not is_nonempty_string.(description) do
                [:invalid_description | errors]
              else
                errors
              end

            errors =
              if author != nil and not is_nonempty_string.(author) do
                [:invalid_author | errors]
              else
                errors
              end

            # Validate version is semver (already checked below, but move here for error aggregation)
            errors =
              if is_nonempty_string.(version) do
                case Version.parse(version) do
                  {:ok, _parsed} -> errors
                  :error -> [:invalid_version_format | errors]
                end
              else
                errors
              end

            if errors != [] do
              Raxol.Core.Runtime.Log.error_with_stacktrace(
                "[#{__MODULE__}] Plugin #{inspect(module_atom)} metadata validation failed: #{inspect(errors)} | Metadata: #{inspect(metadata)}",
                nil,
                nil,
                %{
                  module: __MODULE__,
                  module_atom: module_atom,
                  errors: errors,
                  metadata: metadata
                }
              )

              {:error, :invalid_metadata, Enum.reverse(errors), metadata}
            else
              Raxol.Core.Runtime.Log.debug(
                "[#{__MODULE__}] Successfully called metadata/0 on #{inspect(module_atom)}."
              )

              {:ok, module_atom}
            end
          rescue
            e ->
              Raxol.Core.Runtime.Log.error_with_stacktrace(
                "[#{__MODULE__}] Error calling metadata/0 on #{inspect(module_atom)}",
                e,
                nil,
                %{module: __MODULE__, module_atom: module_atom}
              )

              {:error, :metadata_call_failed}
          end

        true ->
          # Module doesn't provide metadata via PluginMetadataProvider, but it's loaded.
          Raxol.Core.Runtime.Log.debug(
            "[#{__MODULE__}] Module #{inspect(module_atom)} loaded, metadata to be handled by caller or defaults."
          )

          {:ok, module_atom}
      end
    else
      Raxol.Core.Runtime.Log.error_with_stacktrace(
        "[#{__MODULE__}] Failed to ensure module for metadata is loaded",
        nil,
        nil,
        %{module: __MODULE__, module_atom: module_atom}
      )

      {:error, :module_not_found_for_metadata}
    end
  end

  @impl true
  def load_plugin_module(module_atom) when is_atom(module_atom) do
    if Code.ensure_loaded?(module_atom) do
      Raxol.Core.Runtime.Log.debug(
        "[#{__MODULE__}] Module code ensured loaded for: #{inspect(module_atom)}"
      )

      {:ok, module_atom}
    else
      Raxol.Core.Runtime.Log.error_with_stacktrace(
        "[#{__MODULE__}] Failed to ensure module code is loaded",
        nil,
        nil,
        %{module: __MODULE__, module_atom: module_atom}
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
  @doc false
  def load_plugin(plugin_id, config \\ %{})

  def load_plugin(plugin_id, config) when is_atom(plugin_id) do
    Raxol.Core.Runtime.Log.debug(
      "[#{__MODULE__}] Attempting to load plugin (legacy): #{inspect(plugin_id)}"
    )

    case load_plugin_module(plugin_id) do
      {:ok, module} ->
        metadata = default_metadata(module)

        Raxol.Core.Runtime.Log.info(
          "[#{__MODULE__}] Successfully loaded plugin (legacy): #{inspect(plugin_id)}"
        )

        {:ok, module, metadata, config}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[#{__MODULE__}] Failed to load plugin module (legacy)",
          reason,
          nil,
          %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
        )

        {:error, reason}
    end
  end

  def load_plugin(plugin_id, _config) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "[#{__MODULE__}] Invalid plugin ID (legacy)",
      nil,
      nil,
      %{module: __MODULE__, plugin_id: plugin_id}
    )

    {:error, :invalid_plugin_id}
  end

  @doc """
  Sorts plugins based on dependencies.

  Takes a list of plugin structures (e.g., `Raxol.Core.Runtime.Plugins.Plugin.t()`),
  each containing at least an `:id` and a `:dependencies` field.
  The `:dependencies` field is expected to be a list of `{dependency_id, version_requirement}` tuples.

  Returns `{:ok, sorted_plugin_ids}` in topological order, or
  `{:error, :cycle_detected, problematic_ids}` if a cycle is found,
  or `{:error, :missing_dependency, %{plugin_id: id, missing_dep_id: dep_id}}`
  if a declared dependency is not found within the input plugin list.
  """
  def sort_plugins(plugins_with_metadata) when is_list(plugins_with_metadata) do
    # Validate that all declared dependencies are present in the input list.
    # This is crucial for the integrity of the sort.
    known_plugin_ids = Enum.map(plugins_with_metadata, & &1.id) |> MapSet.new()

    missing_dep_check =
      Enum.find_value(plugins_with_metadata, fn plugin ->
        Enum.find_value(plugin.dependencies, fn {dep_id, _req} ->
          unless MapSet.member?(known_plugin_ids, dep_id) do
            {:error, :missing_dependency,
             %{plugin_id: plugin.id, missing_dep_id: dep_id}}
          else
            # Continue checking
            nil
          end
        end)
      end)

    if missing_dep_check do
      # A missing dependency was found, return the error
      missing_dep_check
    else
      # Proceed with topological sort
      adj_list =
        plugins_with_metadata
        |> Enum.map(& &1.id)
        |> Enum.into(%{}, fn id -> {id, []} end)

      {in_degree, adj_list_populated} =
        Enum.reduce(plugins_with_metadata, {%{}, adj_list}, fn plugin,
                                                               {acc_in_degree,
                                                                acc_adj_list} ->
          # Initialize in_degree for the current plugin
          num_deps = Enum.count(plugin.dependencies)
          new_in_degree = Map.put(acc_in_degree, plugin.id, num_deps)

          # Populate adjacency list: if P depends on D, edge D -> P
          new_adj_list =
            Enum.reduce(plugin.dependencies, acc_adj_list, fn {dep_id, _req},
                                                              current_adj ->
              # dep_id is guaranteed to be in known_plugin_ids due to the check above
              Map.update!(current_adj, dep_id, fn dependents ->
                [plugin.id | dependents]
              end)
            end)

          {new_in_degree, new_adj_list}
        end)

      initial_queue =
        in_degree
        |> Enum.filter(fn {_id, count} -> count == 0 end)
        |> Enum.map(fn {id, _count} -> id end)
        # Reverse to maintain a more stable order for items with same priority if desired,
        # though :queue doesn't guarantee FIFO among items added in a batch like this.
        # For deterministic output, could sort initial_queue by ID here.
        |> Enum.reverse()
        |> :queue.from_list()

      {_final_queue, sorted_order_reversed, final_in_degree, count_sorted_nodes} =
        loop_topo_sort(initial_queue, [], in_degree, adj_list_populated, 0)

      if count_sorted_nodes == MapSet.size(known_plugin_ids) do
        {:ok, Enum.reverse(sorted_order_reversed)}
      else
        problematic_ids =
          final_in_degree
          |> Enum.filter(fn {_id, count} -> count > 0 end)
          |> Enum.map(fn {id, _count} -> id end)

        {:error, :cycle_detected, problematic_ids}
      end
    end
  end

  defp loop_topo_sort(
         queue,
         sorted_acc,
         in_degree_map,
         adj_list_map,
         nodes_processed_count
       ) do
    if :queue.is_empty(queue) do
      {queue, sorted_acc, in_degree_map, nodes_processed_count}
    else
      {{:value, u_id}, remaining_queue} = :queue.out(queue)
      new_sorted_acc = [u_id | sorted_acc]
      new_nodes_processed_count = nodes_processed_count + 1

      dependents_of_u = Map.get(adj_list_map, u_id, [])

      {updated_queue, updated_in_degree_map} =
        Enum.reduce(dependents_of_u, {remaining_queue, in_degree_map}, fn v_id,
                                                                          {current_q,
                                                                           current_id_map} ->
          new_v_in_degree = Map.update!(current_id_map, v_id, &(&1 - 1))

          if Map.get(new_v_in_degree, v_id) == 0 do
            {:queue.in(v_id, current_q), new_v_in_degree}
          else
            {current_q, new_v_in_degree}
          end
        end)

      loop_topo_sort(
        updated_queue,
        new_sorted_acc,
        updated_in_degree_map,
        adj_list_map,
        new_nodes_processed_count
      )
    end
  end

  @doc """
  Extracts metadata for a given plugin module.
  """
  def extract_metadata(module) do
    # Extract metadata from module attributes
    metadata = %{
      id: Module.get_attribute(module, :plugin_id),
      version: Module.get_attribute(module, :plugin_version),
      dependencies: Module.get_attribute(module, :plugin_dependencies) || [],
      description: Module.get_attribute(module, :plugin_description),
      author: Module.get_attribute(module, :plugin_author),
      license: Module.get_attribute(module, :plugin_license)
    }

    # Filter out nil values
    Enum.reject(metadata, fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  # Helper to generate default metadata (used by legacy and potentially new functions)
  @doc false
  defp default_metadata(plugin_module) do
    plugin_id = module_to_default_id(plugin_module)
    %{id: plugin_id, version: "0.0.0-dev", dependencies: []}
  end

  @doc """
  Loads a plugin module's code.

  ## Parameters

  * `module` - The module to load

  ## Returns

  * `:ok` - If the module was loaded successfully
  * `{:error, :module_not_found}` - If the module could not be found

  ## Examples

      iex> Loader.load_code(MyPlugin)
      :ok
  """
  def load_code(module) when is_atom(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} -> :ok
      {:error, :nofile} -> {:error, :module_not_found}
    end
  end

  @impl true
  def behaviour_implemented?(module, behaviour)
      when is_atom(module) and is_atom(behaviour) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        behaviours =
          module.module_info(:attributes)
          |> Keyword.get_values(:behaviour)
          |> List.flatten()

        behaviour in behaviours

      {:error, :nofile} ->
        false
    end
  end

  @impl true
  def initialize_plugin(module, config) when is_atom(module) do
    try do
      case module.init(config) do
        {:ok, state} -> {:ok, state}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Error during plugin init",
          error,
          nil,
          %{module: __MODULE__, plugin_module: module}
        )

        {:error, {:init_exception, error}}
    end
  end
end
