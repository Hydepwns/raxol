defmodule Raxol.Core.Runtime.Plugins.CommandHelper do
  @moduledoc """
  Handles plugin command registration and dispatch for the Plugin Manager.
  """

  require Logger

  alias Raxol.Core.Runtime.Plugins.CommandRegistry
  alias Raxol.Core.Runtime.Plugins.LifecycleHelper

  @doc """
  Finds the plugin responsible for handling a command.

  Uses the CommandRegistry to look up the command by name and optional namespace.
  Returns `{:ok, module, function, arity} | :not_found`.
  """
  def find_plugin_for_command(command_table, command_name, namespace, _arity) do
    # Ensure command_name is a binary for lookup
    processed_command_name =
      if is_atom(command_name) do
        Atom.to_string(command_name)
      else
        # Assuming it's already a binary or handle error if not
        command_name
      end

    # Namespace is optional (pass nil for global search or specific module)
    namespace_module =
      cond do
        is_binary(namespace) ->
          try do
            String.to_existing_atom(namespace)
          rescue
            ArgumentError ->
              # If namespace string cannot be converted to an atom, treat as no namespace
              Logger.debug(
                "Namespace string '#{namespace}' could not be converted to an existing atom."
              )

              nil
          end

        is_atom(namespace) ->
          namespace

        true ->
          nil
      end

    CommandRegistry.lookup_command(
      command_table,
      # Corrected: Pass the processed namespace (atom or nil)
      namespace_module,
      # Use the processed command name (binary)
      processed_command_name
    )
  end

  @doc """
  Registers the commands exposed by a plugin.

  Calls the plugin's `get_commands/1` or `get_commands/0` callback
  and registers them in the command table.
  """
  def register_plugin_commands(plugin_module, _plugin_state, command_table) do
    # Only support get_commands/0 now
    if function_exported?(plugin_module, :get_commands, 0) do
      try do
        commands = plugin_module.get_commands()

        if is_list(commands) do
          Enum.each(commands, fn
            # Match standard command tuple: {name_atom, function_atom, arity_integer}
            {name, function, arity}
            when is_atom(name) and is_atom(function) and is_integer(arity) and
                   arity >= 0 ->
              CommandRegistry.register_command(
                command_table,
                # Use module as namespace
                plugin_module,
                Atom.to_string(name),
                # Module containing the function
                plugin_module,
                function,
                arity
              )

            invalid ->
              Logger.warning(
                "Plugin #{inspect(plugin_module)} returned invalid command format in get_commands/0: #{inspect(invalid)}. Expected {name_atom, function_atom, arity_integer}."
              )
          end)
        else
          Logger.warning(
            "Plugin #{inspect(plugin_module)} get_commands/0 did not return a list."
          )
        end
      rescue
        error ->
          Logger.error(
            "Error calling get_commands/0 on #{inspect(plugin_module)}: #{inspect(error)}
            Stacktrace: #{inspect(__STACKTRACE__)}"
          )
      end
    else
      # No get_commands/0 function exported, nothing to register
      :ok
    end
  end

  @doc """
  Handles the dispatching of a command to the appropriate plugin.

  This function is called by the Manager's `handle_cast`.
  It finds the plugin, calls its command handler, and returns an updated
  plugin state map or an error indicator.

  Returns `{:ok, updated_plugin_states_map} | :not_found | {:error, reason}`.
  Replies are sent directly via `send/2` within this function.
  """
  def handle_command(command_table, command_name_str, namespace, args, state) do
    # Arity isn't used in lookup yet
    case find_plugin_for_command(
           command_table,
           command_name_str,
           namespace,
           :unknown
         ) do
      # Correct match for successful lookup
      {:ok, {plugin_module, function_atom, _arity}} ->
        # Find current plugin state
        plugin_id =
          LifecycleHelper.find_plugin_id_by_module(state.plugins, plugin_module)

        if plugin_id && Map.has_key?(state.plugin_states, plugin_id) do
          current_plugin_state = state.plugin_states[plugin_id]

          try do
            # Call the plugin's handler function using apply(Module, function, [args_list, state])
            # Use apply/3 correctly
            case apply(plugin_module, function_atom, [
                   args,
                   current_plugin_state
                 ]) do
              # Expected success format from plugin: {:ok, new_plugin_state, result_tuple}
              {:ok, new_plugin_state, result_tuple} ->
                Logger.debug(
                  "Command '#{command_name_str}' handled by #{inspect(plugin_module)}, result: #{inspect(result_tuple)}"
                )

                # Return result to PluginManager
                {:ok, new_plugin_state, result_tuple, plugin_id}

              # Expected error format from plugin: {:error, reason_tuple, new_plugin_state}
              {:error, reason_tuple, new_plugin_state} ->
                Logger.error(
                  "Error handling command '#{command_name_str}' in #{inspect(plugin_module)}: #{inspect(reason_tuple)}"
                )

                # Return error to PluginManager
                {:error, reason_tuple, plugin_id}

              other ->
                Logger.warning(
                  "Plugin #{inspect(plugin_module)} returned unexpected value from command handler: #{inspect(other)}. Expected {:ok, state, result} or {:error, reason, state}."
                )

                # Return generic error to PluginManager
                {:error, {:unexpected_plugin_return, other}, plugin_id}
            end
          rescue
            error ->
              Logger.error(
                "Exception handling command '#{command_name_str}' in #{inspect(plugin_module)}: #{inspect(error)}
              Stacktrace: #{inspect(__STACKTRACE__)}"
              )

              # Return exception error to PluginManager
              # Include plugin_id if possible
              {:error, {:exception, error}, plugin_id}
          end
        else
          Logger.error(
            "Could not find state for plugin #{inspect(plugin_module)} handling command '#{command_name_str}'"
          )

          # Return error to PluginManager
          # No specific plugin_id
          {:error, :plugin_state_not_found, nil}
        end

      # Correct match for lookup failure
      {:error, :not_found} ->
        Logger.warning(
          "Command not found: [#{namespace || "global"}] '#{command_name_str}'"
        )

        # Indicate command was not found
        :not_found
    end
  end

  @doc """
  Unregisters all commands associated with a specific plugin module.
  """
  def unregister_plugin_commands(command_table, plugin_module) do
    Logger.debug("Unregistering commands for module: #{inspect(plugin_module)}")
    # Use correct function name
    CommandRegistry.unregister_commands_by_module(command_table, plugin_module)
  end
end
