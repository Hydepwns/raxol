defmodule Raxol.Core.Runtime.Plugins.PluginCommandManager do
  @moduledoc """
  Manages plugin command registration and dispatch.
  Coordinates between plugins and the command system.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  # Client API

  @doc """
  Register commands for a plugin.
  """
  @spec register_commands(atom(), list(), map()) :: :ok | {:error, term()}
  def register_commands(plugin_id, commands, metadata \\ %{}) do
    GenServer.call(
      __MODULE__,
      {:register_commands, plugin_id, commands, metadata}
    )
  end

  @doc """
  Unregister all commands for a plugin.
  """
  @spec unregister_commands(atom()) :: :ok
  def unregister_commands(plugin_id) do
    GenServer.call(__MODULE__, {:unregister_commands, plugin_id})
  end

  @doc """
  Get all registered commands.
  """
  @spec get_commands() :: map()
  def get_commands do
    GenServer.call(__MODULE__, :get_commands)
  end

  @doc """
  Get commands for a specific plugin.
  """
  @spec get_plugin_commands(atom()) :: list()
  def get_plugin_commands(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin_commands, plugin_id})
  end

  @doc """
  Dispatch a command to the appropriate plugin.
  """
  @spec dispatch_command(atom(), list()) :: {:ok, term()} | {:error, term()}
  def dispatch_command(command_name, args \\ []) do
    GenServer.call(__MODULE__, {:dispatch_command, command_name, args})
  end

  # Server Callbacks

  @impl true
  def init_manager(_opts) do
    state = %{
      commands: %{},
      plugin_commands: %{},
      metadata: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_manager_call(
        {:register_commands, plugin_id, commands, metadata},
        _from,
        state
      ) do
    Log.debug(
      "Registering #{length(commands)} commands for plugin #{plugin_id}"
    )

    # Store commands by plugin
    plugin_commands = Map.put(state.plugin_commands, plugin_id, commands)

    # Store each command with its plugin reference
    new_commands =
      Enum.reduce(commands, state.commands, fn cmd, acc ->
        Map.put(acc, cmd.name, Map.put(cmd, :plugin_id, plugin_id))
      end)

    # Store metadata
    metadata_map = Map.put(state.metadata, plugin_id, metadata)

    new_state = %{
      state
      | commands: new_commands,
        plugin_commands: plugin_commands,
        metadata: metadata_map
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call({:unregister_commands, plugin_id}, _from, state) do
    Log.debug("Unregistering commands for plugin #{plugin_id}")

    # Get commands for this plugin
    plugin_cmds = Map.get(state.plugin_commands, plugin_id, [])

    # Remove commands from main registry
    new_commands =
      Enum.reduce(plugin_cmds, state.commands, fn cmd, acc ->
        Map.delete(acc, cmd.name)
      end)

    # Remove from plugin commands
    plugin_commands = Map.delete(state.plugin_commands, plugin_id)

    # Remove metadata
    metadata = Map.delete(state.metadata, plugin_id)

    new_state = %{
      state
      | commands: new_commands,
        plugin_commands: plugin_commands,
        metadata: metadata
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_manager_call(:get_commands, _from, state) do
    {:reply, state.commands, state}
  end

  @impl true
  def handle_manager_call({:get_plugin_commands, plugin_id}, _from, state) do
    commands = Map.get(state.plugin_commands, plugin_id, [])
    {:reply, commands, state}
  end

  @impl true
  def handle_manager_call({:dispatch_command, command_name, args}, _from, state) do
    case Map.get(state.commands, command_name) do
      nil ->
        {:reply, {:error, :command_not_found}, state}

      command ->
        result = execute_command(command, args)
        {:reply, result, state}
    end
  end

  # Private Functions

  @spec execute_command(any(), list()) :: any()
  defp execute_command(command, args) do
    # Execute the command handler
    case command do
      %{handler: handler} when is_function(handler) ->
        {:ok, handler.(args)}

      %{module: module, function: function} ->
        {:ok, apply(module, function, [args])}

      _ ->
        {:error, :invalid_command_spec}
    end
  rescue
    e ->
      Log.error("Error executing command #{command.name}: #{inspect(e)}")

      {:error, e}
  end

  @doc """
  Initialize command table with initial plugins.
  """
  @spec initialize_command_table(map(), map() | list()) :: map()
  def initialize_command_table(command_table, plugins) do
    Enum.reduce(plugins, command_table, fn plugin, table ->
      case plugin do
        %{commands: commands} when is_list(commands) ->
          add_plugin_commands_to_table(commands, table)

        _ ->
          table
      end
    end)
  end

  @doc """
  Update command table with plugin commands.
  """
  @spec update_command_table(map(), map()) :: map()
  def update_command_table(table, plugin) do
    case plugin do
      %{commands: commands} when is_list(commands) ->
        Enum.reduce(commands, table, fn cmd, tbl ->
          Map.put(tbl, cmd.name, cmd)
        end)

      _ ->
        table
    end
  end

  defp add_plugin_commands_to_table(commands, table) do
    Enum.reduce(commands, table, fn cmd, tbl ->
      Map.put(tbl, cmd.name, cmd)
    end)
  end
end
