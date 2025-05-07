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
  def find_plugin_for_command(command_table, command_name_str, namespace, _arity) do
    # Namespace is optional (pass nil for global search or specific module)
    namespace_module = if namespace, do: String.to_existing_atom(namespace), else: nil # Convert ns string to atom if needed
    CommandRegistry.lookup_command(
      command_table,
      command_name_str,
      namespace_module
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
            when is_atom(name) and is_atom(function) and is_integer(arity) and arity >= 0 ->
              CommandRegistry.register_command(
                command_table,
                plugin_module, # Use module as namespace
                Atom.to_string(name),
                plugin_module, # Module containing the function
                function,
                arity
              )

            invalid ->
              Logger.warning(
                "Plugin #{inspect(plugin_module)} returned invalid command format in get_commands/0: #{inspect(invalid)}. Expected {name_atom, function_atom, arity_integer}."
              )
          end)
        else
          Logger.warning("Plugin #{inspect(plugin_module)} get_commands/0 did not return a list.")
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
    case find_plugin_for_command(command_table, command_name_str, namespace, :unknown) do # Arity isn't used in lookup yet
      # Correct match for successful lookup
      {:ok, {plugin_module, function_atom, _arity}} ->
        # Find current plugin state
        plugin_id = LifecycleHelper.find_plugin_id_by_module(state.plugins, plugin_module)

        if plugin_id && Map.has_key?(state.plugin_states, plugin_id) do
          current_plugin_state = state.plugin_states[plugin_id]

          try do
            # Call the plugin's handler function
            case apply(plugin_module, function_atom, args ++ [current_plugin_state]) do
              {:ok, new_plugin_state, result} ->
                # Update state map and potentially reply
                updated_plugin_states = Map.put(state.plugin_states, plugin_id, new_plugin_state)
                # TODO: Handle sending reply 'result' if needed (e.g., for :clipboard_read)
                Logger.debug("Command '#{command_name_str}' handled by #{inspect plugin_module}, result: #{inspect result}")
                {:ok, updated_plugin_states}

              {:error, reason, new_plugin_state} ->
                Logger.error("Error handling command '#{command_name_str}' in #{inspect plugin_module}: #{inspect reason}")
                {:error, reason, Map.put(state.plugin_states, plugin_id, new_plugin_state)}

              # Handle simpler returns if plugins don't follow full spec yet
              {:noreply, new_plugin_state} ->
                 Logger.debug("Command '#{command_name_str}' handled by #{inspect plugin_module} (noreply)")
                 {:ok, Map.put(state.plugin_states, plugin_id, new_plugin_state)}

              {:reply, reply, new_plugin_state} ->
                  Logger.debug("Command '#{command_name_str}' handled by #{inspect plugin_module} (reply: #{inspect reply})")
                  # TODO: Send reply
                  {:ok, Map.put(state.plugin_states, plugin_id, new_plugin_state)}

              other ->
                 Logger.warning("Plugin #{inspect plugin_module} returned unexpected value from command handler: #{inspect other}")
                 {:error, :unexpected_return, state.plugin_states} # Return original state
            end
          rescue
            error ->
              Logger.error("Exception handling command '#{command_name_str}' in #{inspect plugin_module}: #{inspect error}
              Stacktrace: #{inspect(__STACKTRACE__)}")
              {:error, :exception, state.plugin_states} # Return original state
          end
        else
          Logger.error("Could not find state for plugin #{inspect plugin_module} handling command '#{command_name_str}'")
          {:error, :plugin_state_not_found}
        end

      # Correct match for lookup failure
      {:error, :not_found} ->
        Logger.warning("Command not found: [#{namespace || "global"}] '#{command_name_str}'")
        :not_found # Indicate command was not found

      # Remove unreachable clauses
      # {:ok, plugin_module, function_atom, _arity} -> ...
      # :not_found -> ...
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
