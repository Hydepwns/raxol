defmodule Raxol.Core.Runtime.Plugins.LifecycleHelper do
  @moduledoc """
  Helper functions for plugin lifecycle management.
  """

  @behaviour Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour

  alias Raxol.Core.Runtime.Plugins.{
    Loader,
    PluginValidator,
    PluginCommandManager,
    PluginEventProcessor,
    PluginReloader,
    PluginUnloader,
    PluginStateManager,
    PluginInitializer,
    PluginLifecycleCallbacks,
    PluginErrorHandler
  }

  require Raxol.Core.Runtime.Log

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def load_plugin(
        plugin_id_or_module,
        config,
        plugins,
        metadata,
        plugin_states,
        load_order,
        command_table,
        plugin_config
      ) do
    with {:ok, {plugin_id, plugin_module}} <-
           PluginValidator.resolve_plugin_identity(plugin_id_or_module),
         :ok <-
           PluginValidator.validate_plugin(plugin_id, plugin_module, plugins),
         {:ok, plugin_metadata} <- Loader.extract_metadata(plugin_module),
         {:ok, updated_maps} <-
           initialize_and_register_plugin(%{
             plugin_id: plugin_id,
             plugin_module: plugin_module,
             plugin_metadata: plugin_metadata,
             config: config,
             plugins: plugins,
             metadata: metadata,
             plugin_states: plugin_states,
             load_order: load_order,
             command_table: command_table,
             plugin_config: plugin_config
           }) do
      {:ok, updated_maps}
    else
      {:error, :already_loaded} ->
        {:error, "Plugin #{plugin_id_or_module} is already loaded"}

      {:error, :invalid_plugin} ->
        {:error,
         "Plugin #{plugin_id_or_module} does not implement required behaviour"}

      {:error, :dependency_missing, missing} ->
        {:error,
         "Missing dependency #{missing} for plugin #{plugin_id_or_module}"}

      {:error, :dependency_cycle, cycle} ->
        {:error, "Dependency cycle detected: #{inspect(cycle)}"}

      {:error, reason} ->
        PluginErrorHandler.handle_load_error(reason, plugin_id_or_module)
    end
  end

  defp initialize_and_register_plugin(%{
         plugin_id: plugin_id,
         plugin_module: plugin_module,
         plugin_metadata: plugin_metadata,
         config: config,
         plugins: plugins,
         metadata: metadata,
         plugin_states: plugin_states,
         load_order: load_order,
         command_table: command_table,
         plugin_config: plugin_config
       }) do
    with {:ok, initial_state} <-
           PluginStateManager.initialize_plugin_state(plugin_module, config),
         :ok <-
           register_plugin_components(%{
             plugin_id: plugin_id,
             plugin_module: plugin_module,
             initial_state: initial_state,
             command_table: command_table,
             plugin_metadata: plugin_metadata,
             plugins: plugins,
             metadata: metadata,
             plugin_states: plugin_states,
             load_order: load_order,
             plugin_config: plugin_config
           }) do
      build_updated_maps(%{
        plugin_id: plugin_id,
        plugin_module: plugin_module,
        plugin_metadata: plugin_metadata,
        initial_state: initial_state,
        config: config,
        plugins: plugins,
        metadata: metadata,
        plugin_states: plugin_states,
        load_order: load_order,
        plugin_config: plugin_config
      })
    end
  end

  defp register_plugin_components(%{
         plugin_id: plugin_id,
         plugin_module: plugin_module,
         initial_state: initial_state,
         command_table: command_table,
         plugin_metadata: plugin_metadata,
         plugins: plugins,
         metadata: metadata,
         plugin_states: plugin_states,
         load_order: load_order,
         plugin_config: plugin_config
       }) do
    with :ok <-
           PluginStateManager.update_plugin_state(
             plugin_id,
             initial_state,
             plugins,
             metadata,
             plugin_states,
             load_order,
             plugin_config
           ),
         :ok <-
           PluginCommandManager.register_commands(
             plugin_module,
             initial_state,
             command_table
           ) do
      register_plugin(plugin_id, plugin_metadata)
    end
  end

  defp build_updated_maps(%{
         plugin_id: plugin_id,
         plugin_module: plugin_module,
         plugin_metadata: plugin_metadata,
         initial_state: initial_state,
         config: config,
         plugins: plugins,
         metadata: metadata,
         plugin_states: plugin_states,
         load_order: load_order,
         plugin_config: plugin_config
       }) do
    %{
      plugins: Map.put(plugins, plugin_id, plugin_module),
      metadata: Map.put(metadata, plugin_id, plugin_metadata),
      plugin_states: Map.put(plugin_states, plugin_id, initial_state),
      load_order: [plugin_id | load_order],
      plugin_config: Map.put(plugin_config, plugin_id, config)
    }
  end

  defp register_plugin(plugin_id, plugin_metadata) do
    Raxol.Core.Runtime.Plugins.Registry.register_plugin(
      plugin_id,
      plugin_metadata
    )
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def initialize_plugins(
        plugins,
        metadata,
        config,
        states,
        load_order,
        command_table,
        opts
      ) do
    PluginInitializer.initialize_plugins(
      plugins,
      metadata,
      config,
      states,
      load_order,
      command_table,
      opts
    )
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def cleanup_plugin(plugin_id, metadata) do
    PluginLifecycleCallbacks.cleanup_plugin(plugin_id, metadata)
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def handle_state_transition(plugin_id, old_state, new_state) do
    PluginLifecycleCallbacks.handle_state_transition(
      plugin_id,
      old_state,
      new_state
    )
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def init_plugin(plugin_id, metadata) do
    PluginLifecycleCallbacks.init_plugin(plugin_id, metadata)
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def load_plugin_by_module(
        module,
        metadata,
        config,
        states,
        command_table,
        plugin_manager,
        current_metadata,
        opts
      ) do
    PluginLifecycleCallbacks.load_plugin_by_module(
      module,
      metadata,
      config,
      states,
      command_table,
      plugin_manager,
      current_metadata,
      opts
    )
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def reload_plugin(
        plugin_id,
        metadata,
        config,
        states,
        command_table,
        plugin_manager,
        opts
      ) do
    PluginLifecycleCallbacks.reload_plugin(
      plugin_id,
      metadata,
      config,
      states,
      command_table,
      plugin_manager,
      opts
    )
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def terminate_plugin(plugin_id, metadata, reason) do
    PluginLifecycleCallbacks.terminate_plugin(plugin_id, metadata, reason)
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def handle_event(
        event,
        plugins,
        metadata,
        plugin_states,
        load_order,
        command_table,
        plugin_config
      ) do
    # Delegate event processing to PluginEventProcessor
    case PluginEventProcessor.process_event_through_plugins(
           event,
           plugins,
           metadata,
           plugin_states,
           load_order,
           command_table,
           plugin_config
         ) do
      {:ok, {updated_metadata, updated_states, updated_table}} ->
        {:ok, {updated_metadata, updated_states, updated_table}}

      {:error, reason} ->
        PluginErrorHandler.handle_event_error(event, reason)
    end
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def reload_plugin_from_disk(
        plugin_id,
        plugin_module,
        plugin_path,
        plugin_state,
        command_table,
        metadata,
        plugin_manager,
        opts
      ) do
    PluginReloader.reload_plugin_from_disk(
      plugin_id,
      plugin_module,
      plugin_path,
      plugin_state,
      command_table,
      metadata,
      plugin_manager,
      opts
    )
  end

  @impl Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour
  def unload_plugin(plugin_id, metadata, config, states, command_table, opts) do
    PluginUnloader.unload_plugin(
      plugin_id,
      metadata,
      config,
      states,
      command_table,
      opts
    )
  end

  @doc """
  Catch-all for load_plugin/3. Raises a clear error if called with the wrong arity.
  """
  def load_plugin(_a, _b, _c) do
    raise "Raxol.Core.Runtime.Plugins.LifecycleHelper.load_plugin/3 is not implemented. Use load_plugin/8."
  end
end
