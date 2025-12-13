defmodule Raxol.Plugins.Lifecycle.Initialization do
  @moduledoc """
  Handles plugin initialization, config merging, struct creation, and compatibility checks for plugin lifecycle management.
  """

  alias Raxol.Plugins.Lifecycle.Validation
  alias Raxol.Plugins.PluginConfig
  alias Raxol.Plugins.PluginDependency

  # --- Plugin Initialization ---

  def initialize_plugin_with_config(manager, plugin_name, module, config) do
    with :ok <- validate_plugin_module(module),
         {:ok, merged_config} <-
           get_and_validate_config(manager, plugin_name, module, config),
         {:ok, plugin} <- initialize_plugin(module, merged_config),
         {:ok, final_plugin, plugin_state} <-
           prepare_plugin_for_manager(plugin, plugin_name, module) do
      {:ok, final_plugin, merged_config, plugin_state}
    end
  end

  def prepare_plugin_for_manager(plugin, plugin_name, module) do
    :ok = validate_plugin_state(plugin)
    :ok = validate_plugin_compatibility(plugin, module)

    plugin_with_module =
      plugin
      |> Map.put(:name, plugin_name)
      |> Map.merge(plugin.config)
      |> Map.put(:module, module)

    plugin_state =
      case plugin.state do
        s when is_struct(s) -> %{}
        s -> s || %{}
      end

    {:ok, plugin_with_module, plugin_state}
  end

  def validate_plugin_module(module) do
    with true <- Code.ensure_loaded?(module),
         true <- function_exported?(module, :init, 1),
         true <- function_exported?(module, :cleanup, 1) do
      :ok
    else
      false ->
        case {Code.ensure_loaded?(module), function_exported?(module, :init, 1),
              function_exported?(module, :cleanup, 1)} do
          {false, _, _} -> {:error, :module_not_found}
          {true, false, _} -> {:error, :missing_init}
          {true, true, false} -> {:error, :missing_cleanup}
        end
    end
  end

  def get_and_validate_config(manager, plugin_name, module, config) do
    merged_config = get_merged_config(manager, plugin_name, module, config)
    validate_config_structure(merged_config)
  end

  def validate_config_structure(config) when is_map(config), do: {:ok, config}
  def validate_config_structure(_), do: {:error, :invalid_config}

  def initialize_plugin(module, config) do
    case Raxol.Core.ErrorHandling.safe_call(fn -> module.init(config) end) do
      {:ok, {:ok, plugin_state}} ->
        handle_plugin_state_creation(plugin_state, module, config)

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:ok, other} ->
        {:error, {:invalid_init_return, other}}

      {:error, _error} ->
        # Logging should be handled by caller
        {:error, :init_failed}
    end
  end

  defp handle_plugin_state_creation(plugin_state, module, config) do
    case valid_plugin_struct?(plugin_state) do
      true ->
        {:ok, plugin_state}

      false ->
        plugin = create_plugin_struct(module, config, plugin_state)
        {:ok, plugin}
    end
  end

  defp valid_plugin_struct?(plugin_state) when is_struct(plugin_state) do
    plugin_state.__struct__ == Raxol.Plugins.Plugin or
      function_exported?(plugin_state.__struct__, :__struct__, 0)
  end

  defp valid_plugin_struct?(_plugin_state), do: false

  defp normalize_plugin_state(plugin_state) when is_struct(plugin_state),
    do: %{}

  defp normalize_plugin_state(plugin_state), do: plugin_state

  defp create_base_plugin(
         true,
         module,
         plugin_name,
         metadata,
         config,
         normalized_state
       ) do
    struct(module, %{
      name: plugin_name,
      version: Map.get(metadata, :version, "1.0.1"),
      description: Map.get(metadata, :description, "Plugin for #{module}"),
      enabled: true,
      config: config,
      dependencies: Map.get(metadata, :dependencies, []),
      api_version: Map.get(metadata, :api_version, get_api_version()),
      state: normalized_state
    })
  end

  defp create_base_plugin(
         false,
         module,
         plugin_name,
         metadata,
         config,
         normalized_state
       ) do
    %Raxol.Plugins.Plugin{
      name: plugin_name,
      version: Map.get(metadata, :version, "1.0.1"),
      description: Map.get(metadata, :description, "Plugin for #{module}"),
      enabled: true,
      config: config,
      dependencies: Map.get(metadata, :dependencies, []),
      api_version: Map.get(metadata, :api_version, get_api_version()),
      module: module,
      state: normalized_state
    }
  end

  def create_plugin_struct(module, config, plugin_state) do
    metadata = get_plugin_metadata(module)
    normalized_state = normalize_plugin_state(plugin_state)
    has_struct = function_exported?(module, :__struct__, 0)
    plugin_name = Map.get(metadata, :name, get_plugin_name(module))

    base_plugin =
      create_base_plugin(
        has_struct,
        module,
        plugin_name,
        metadata,
        config,
        normalized_state
      )

    finalize_plugin_struct(plugin_state, base_plugin)
  end

  defp finalize_plugin_struct(plugin_state, base_plugin)
       when is_map(plugin_state) do
    case is_struct(plugin_state) do
      true ->
        base_plugin

      false ->
        merged_plugin = Map.merge(base_plugin, plugin_state)
        ensure_plugin_has_name(merged_plugin, base_plugin.name)
    end
  end

  defp finalize_plugin_struct(_plugin_state, base_plugin), do: base_plugin

  defp ensure_plugin_has_name(merged_plugin, fallback_name) do
    case Map.get(merged_plugin, :name) do
      nil -> Map.put(merged_plugin, :name, fallback_name)
      _name -> merged_plugin
    end
  end

  def get_plugin_metadata(module) do
    call_metadata_if_available(
      function_exported?(module, :get_metadata, 0),
      module
    )
  end

  defp call_metadata_if_available(true, module), do: module.get_metadata()
  defp call_metadata_if_available(false, _module), do: %{}

  def validate_plugin_state(plugin) do
    case validate_required_fields(plugin) do
      :ok -> validate_field_types(plugin)
      error -> error
    end
  end

  def validate_required_fields(plugin) do
    required_fields = [:name, :version, :enabled, :config, :api_version]
    missing = Enum.filter(required_fields, &(Map.get(plugin, &1) == nil))
    check_missing_fields(Enum.empty?(missing), missing)
  end

  defp check_missing_fields(true, _missing), do: :ok

  defp check_missing_fields(false, missing),
    do: {:error, {:missing_fields, missing}}

  def validate_field_types(plugin) do
    with :ok <- Validation.validate_string_field(plugin.name, :name),
         :ok <- Validation.validate_string_field(plugin.version, :version),
         :ok <- Validation.validate_boolean_field(plugin.enabled, :enabled),
         :ok <- Validation.validate_map_field(plugin.config, :config),
         :ok <-
           Validation.validate_string_field(plugin.api_version, :api_version) do
      :ok
    else
      {:error, {:invalid_field, field, type}} ->
        {:error, {:invalid_field, field, type}}
    end
  end

  def validate_plugin_compatibility(plugin, module) do
    check_api_compatibility(plugin, module)
  end

  def check_api_compatibility(plugin, module) do
    PluginDependency.check_api_compatibility(
      plugin.api_version,
      module.get_api_version()
    )
  end

  def get_plugin_name(module) do
    Atom.to_string(module)
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
  end

  def get_api_version, do: "1.0"

  def get_merged_config(manager, plugin_name, module, config) do
    default_config = get_default_config(module)

    persisted_config =
      PluginConfig.get_plugin_config(manager.config, plugin_name)

    default_config
    |> Map.merge(persisted_config)
    |> Map.merge(config)
  end

  def get_default_config(module) do
    extract_default_config(function_exported?(module, :get_metadata, 0), module)
  end

  defp extract_default_config(true, module) do
    case module.get_metadata() do
      %{default_config: dc} when is_map(dc) -> dc
      _ -> %{}
    end
  end

  defp extract_default_config(false, _module), do: %{}

  def get_plugin_id_from_metadata(module) do
    _ = Code.ensure_loaded(module)
    extract_plugin_id(function_exported?(module, :get_metadata, 0), module)
  end

  defp extract_plugin_id(true, module) do
    metadata = module.get_metadata()

    case metadata do
      %{name: name} when is_binary(name) -> name
      %{id: id} when is_atom(id) -> Atom.to_string(id)
      _ -> get_plugin_name(module)
    end
  end

  defp extract_plugin_id(false, module), do: get_plugin_name(module)

  def initialize_all_plugins_with_configs(manager, module_configs) do
    Enum.reduce_while(module_configs, {:ok, []}, fn {module, config},
                                                    {:ok, acc_plugins} ->
      plugin_name = get_plugin_id_from_metadata(module)

      case initialize_plugin_with_config(manager, plugin_name, module, config) do
        {:ok, plugin, _merged_config, _plugin_state} ->
          {:cont, {:ok, [plugin | acc_plugins]}}

        {:error, reason} ->
          {:halt, {:error, :init_failed, module, reason}}
      end
    end)
  end
end
