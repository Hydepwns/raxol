defmodule Raxol.Core.Runtime.Plugins.CommandRegistry do
  @moduledoc """
  Manages commands registered by plugins using an ETS table.

  Provides functions to register, unregister, and look up commands.
  """

  require Logger

  @type command_name :: String.t()
  @type namespace :: atom() | nil
  @type command_key :: {namespace(), command_name()}
  @type command_entry :: {module(), atom(), integer() | nil}
  @type table_name :: atom()

  @doc """
  Creates a new ETS table for the command registry.

  Returns the name of the created table.
  """
  @spec new() :: table_name()
  def new() do
    table_name = :raxol_command_registry

    if :ets.info(table_name, :name) != table_name do
      :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])

      Logger.debug(
        "[#{__MODULE__}] ETS table `#{inspect(table_name)}` created."
      )
    end

    table_name
  end

  @doc """
  Registers a command provided by a plugin.

  Args:
    - `table`: The ETS table name.
    - `command_name`: The name the command will be invoked by.
    - `module`: The plugin module implementing the command.
    - `function`: The function within the module to call.
    - `arity`: The arity of the function.

  Returns `:ok` or `{:error, :already_registered}`.
  """
  @spec register_command(
          table_name(),
          namespace(),
          command_name(),
          module(),
          atom(),
          integer() | nil
        ) ::
          :ok | {:error, :already_registered}
  def register_command(table, namespace, command_name, module, function, arity)
      when is_atom(table) and (is_atom(namespace) or is_nil(namespace)) and
             is_binary(command_name) and is_atom(module) and
             is_atom(function) and (is_integer(arity) or is_nil(arity)) do
    key = {namespace, command_name}
    value = {module, function, arity}

    case :ets.lookup(table, key) do
      [] ->
        :ets.insert(table, {key, value})

        Logger.info(
          ~c"[#{__MODULE__}] Registered command [#{namespace || "global"}] \"#{command_name}\" -> #{inspect(module)}.#{function}/#{arity || ~c"?"}"
        )

        :ok

      [_] ->
        Logger.warning(
          "[#{__MODULE__}] Command [#{namespace || "global"}] \"#{command_name}\" already registered. Registration failed."
        )

        {:error, :already_registered}
    end
  end

  @doc """
  Unregisters a command.
  """
  @spec unregister_command(table_name(), namespace(), command_name()) :: :ok
  def unregister_command(table, namespace, command_name)
      when is_atom(table) and (is_atom(namespace) or is_nil(namespace)) and
             is_binary(command_name) do
    key = {namespace, command_name}
    :ets.delete(table, key)

    Logger.info(
      "[#{__MODULE__}] Unregistered command [#{namespace || "global"}] \"#{command_name}\"."
    )

    :ok
  end

  @doc """
  Looks up the handler {module, function, arity} for a command name and namespace.
  """
  @spec lookup_command(table_name(), namespace(), command_name()) ::
          {:ok, command_entry()} | {:error, :not_found}
  def lookup_command(table, namespace, command_name)
      when is_atom(table) and (is_atom(namespace) or is_nil(namespace)) and
             is_binary(command_name) do
    key = {namespace, command_name}

    case :ets.lookup(table, key) do
      [{^key, handler}] -> {:ok, handler}
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
    match_spec = [
      {{{:"$1", :"$2"}, {module_to_remove, :_, :_}}, [], [{{:"$1", :"$2"}}]}
    ]

    keys_to_delete = :ets.select(table, match_spec)
    count = Enum.count(keys_to_delete)

    if count > 0 do
      Logger.info(
        "[#{__MODULE__}] Unregistering #{count} commands for module #{inspect(module_to_remove)}..."
      )

      Enum.each(keys_to_delete, fn {namespace, command_name} = key ->
        :ets.delete(table, key)

        Logger.debug(
          ~c"[#{__MODULE__}] Unregistered command [#{namespace || "global"}] \"#{command_name}\"."
        )
      end)
    end

    :ok
  end
end
