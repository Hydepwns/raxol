defmodule Raxol.Core.Runtime.Plugins.CommandRegistry do
  @moduledoc """
  Manages commands registered by plugins using an ETS table.

  Provides functions to register, unregister, and look up commands.
  """

  require Logger

  @type command_name :: String.t()
  @type command_entry :: {module(), atom()}
  @type table_name :: atom()

  @doc """
  Creates a new ETS table for the command registry.

  Returns the name of the created table.
  """
  @spec new() :: table_name()
  def new() do
    table_name = :raxol_command_registry
    :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])
    Logger.debug("[#{__MODULE__}] ETS table `#{inspect(table_name)}` created.")
    table_name
  end

  @doc """
  Registers a command provided by a plugin.

  Args:
    - `table`: The ETS table name.
    - `command_name`: The name the command will be invoked by.
    - `module`: The plugin module implementing the command.
    - `function`: The function within the module to call.

  Returns `:ok` or `{:error, :already_registered}`.
  """
  @spec register_command(table_name(), command_name(), module(), atom()) ::
          :ok | {:error, :already_registered}
  def register_command(table, command_name, module, function)
      when is_atom(table) and is_binary(command_name) and is_atom(module) and
             is_atom(function) do
    # Check for existing command
    case :ets.lookup(table, command_name) do
      [] ->
        :ets.insert(table, {command_name, {module, function}})
        # TODO: How to get arity?
        Logger.info(
          "[#{__MODULE__}] Registered command \"#{command_name}\" -> #{inspect(module)}.#{function}/arity"
        )

        :ok

      [_] ->
        Logger.warning(
          "[#{__MODULE__}] Command \"#{command_name}\" already registered. Registration failed."
        )

        {:error, :already_registered}
    end
  end

  @doc """
  Unregisters a command.
  """
  @spec unregister_command(table_name(), command_name()) :: :ok
  def unregister_command(table, command_name)
      when is_atom(table) and is_binary(command_name) do
    :ets.delete(table, command_name)
    Logger.info("[#{__MODULE__}] Unregistered command \"#{command_name}\".")
    :ok
  end

  @doc """
  Looks up the handler {module, function} for a command name.
  """
  @spec lookup_command(table_name(), command_name()) ::
          {:ok, command_entry()} | {:error, :not_found}
  def lookup_command(table, command_name)
      when is_atom(table) and is_binary(command_name) do
    case :ets.lookup(table, command_name) do
      [{^command_name, handler}] -> {:ok, handler}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Unregisters all commands associated with a specific module.

  Useful when a plugin is unloaded.
  """
  @spec unregister_commands_by_module(table_name(), module()) :: :ok
  def unregister_commands_by_module(table, module_to_remove)
      when is_atom(table) and is_atom(module_to_remove) do
    match_spec = [{{:_, {module_to_remove, :_}}, [], [true]}]
    commands_to_delete = :ets.select(table, match_spec)
    count = Enum.count(commands_to_delete)

    if count > 0 do
      Logger.info(
        "[#{__MODULE__}] Unregistering #{count} commands for module #{inspect(module_to_remove)}..."
      )

      Enum.each(commands_to_delete, fn {command_name, _handler} ->
        :ets.delete(table, command_name)

        Logger.debug(
          "[#{__MODULE__}] Unregistered command \"#{command_name}\"."
        )
      end)
    end

    :ok
  end
end
