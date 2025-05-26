defmodule Raxol.Core.Runtime.Plugins.CommandHelper do
  @moduledoc """
  Handles plugin command registration and dispatch for the Plugin Manager.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.CommandRegistry
  alias Raxol.Core.Runtime.Plugins.LifecycleHelper

  @doc """
  Finds the plugin responsible for handling a command.

  Uses the CommandRegistry to look up the command by name and optional namespace.
  Returns `{:ok, module, function, arity} | :not_found`.
  """
  def find_plugin_for_command(command_table, command_name, namespace, _arity) do
    # Normalize command name: trim whitespace and downcase
    processed_command_name =
      command_name
      |> (fn name -> if is_atom(name), do: Atom.to_string(name), else: name end).()
      |> String.trim()
      |> String.downcase()

    # Namespace is optional (pass nil for global search or specific module)
    namespace_module =
      cond do
        is_binary(namespace) ->
          try do
            String.to_existing_atom(namespace)
          rescue
            ArgumentError ->
              # If namespace string cannot be converted to an atom, treat as no namespace
              Raxol.Core.Runtime.Log.debug(
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
              # HARDEN: Check function_exported? before registering
              if function_exported?(plugin_module, function, arity) do
                CommandRegistry.register_command(
                  command_table,
                  # Use module as namespace
                  plugin_module,
                  Atom.to_string(name)
                  |> String.trim()
                  |> String.downcase(),
                  # Module containing the function
                  plugin_module,
                  function,
                  arity
                )
              else
                Raxol.Core.Runtime.Log.warning_with_context(
                  "Plugin #{inspect(plugin_module)} does not export #{function}/#{arity} for command #{inspect(name)}. Skipping registration.",
                  context: __MODULE__,
                  stacktrace: nil
                )
              end
            invalid ->
              Raxol.Core.Runtime.Log.warning_with_context(
                "Plugin #{inspect(plugin_module)} returned invalid command format in get_commands/0: #{inspect(invalid)}. Expected {name_atom, function_atom, arity_integer}.",
                context: __MODULE__,
                stacktrace: nil
              )
          end)
        else
          Raxol.Core.Runtime.Log.warning_with_context(
            "Plugin #{inspect(plugin_module)} get_commands/0 did not return a list.",
            context: __MODULE__,
            stacktrace: nil
          )
        end
      rescue
        error ->
          Raxol.Core.Runtime.Log.error_with_stacktrace(
            "Error calling get_commands/0 on #{inspect(plugin_module)}: #{inspect(error)}"
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
  """
  def handle_command(command_table, command_name_str, namespace, args, state) do
    # Validate arguments
    case validate_command_args(args) do
      :ok ->
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
            plugin_id = find_plugin_id_by_module(state.plugins, plugin_module)

            if plugin_id && Map.has_key?(state.plugin_states, plugin_id) do
              current_plugin_state = state.plugin_states[plugin_id]

              # HARDEN: Check function_exported? before apply/3
              if function_exported?(plugin_module, function_atom, 3) do
                try do
                  # Call the plugin's handler function using apply(Module, function, [args_list, state])
                  # Use apply/3 correctly
                  command_name_atom = String.to_atom(command_name_str)

                  case with_timeout(
                         fn ->
                           apply(plugin_module, function_atom, [
                             command_name_atom,
                             args,
                             current_plugin_state
                           ])
                         end,
                         5000
                       ) do
                    {:ok, {:ok, new_plugin_state, result_tuple}} ->
                      Raxol.Core.Runtime.Log.debug(
                        "Command '#{command_name_str}' handled by #{inspect(plugin_module)}, result: #{inspect(result_tuple)}"
                      )

                      # Update plugin state in the state map
                      updated_states =
                        Map.put(state.plugin_states, plugin_id, new_plugin_state)

                      # Return result to plugin manager
                      {:ok, updated_states}

                    {:ok, {:error, reason_tuple, new_plugin_state}} ->
                      Raxol.Core.Runtime.Log.error_with_stacktrace(
                        "Error handling command '#{command_name_str}' in #{inspect(plugin_module)}: #{inspect(reason_tuple)}"
                      )

                      # Update plugin state even on error
                      updated_states =
                        Map.put(state.plugin_states, plugin_id, new_plugin_state)

                      # Return error to plugin manager
                      {:error, reason_tuple, updated_states}

                    {:ok, invalid_return} ->
                      Raxol.Core.Runtime.Log.warning_with_context(
                        "Plugin #{inspect(plugin_module)} returned unexpected value from command handler: #{inspect(invalid_return)}. Expected {:ok, state, result} or {:error, reason, state}.",
                        context: __MODULE__,
                        stacktrace: nil
                      )

                      # Return generic error to plugin manager
                      {:error, {:unexpected_plugin_return, invalid_return},
                       state.plugin_states}

                    {:error, :timeout} ->
                      Raxol.Core.Runtime.Log.error_with_stacktrace(
                        "Command '#{command_name_str}' in #{inspect(plugin_module)} timed out after 5 seconds"
                      )

                      {:error, :command_timeout, state.plugin_states}

                    {:error, reason} ->
                      Raxol.Core.Runtime.Log.error_with_stacktrace(
                        "Exception handling command '#{command_name_str}' in #{inspect(plugin_module)}: #{inspect(reason)}"
                      )

                      # Return exception error to plugin manager
                      {:error, {:exception, reason}, state.plugin_states}
                  end
                rescue
                  error ->
                    Raxol.Core.Runtime.Log.error_with_stacktrace(
                      "Exception handling command '#{command_name_str}' in #{inspect(plugin_module)}: #{inspect(error)}"
                    )

                    # Return exception error to plugin manager
                    {:error, {:exception, error}, state.plugin_states}
                end
              else
                Raxol.Core.Runtime.Log.error_with_stacktrace(
                  "Plugin #{inspect(plugin_module)} does not export #{function_atom}/3 for command '#{command_name_str}'"
                )
                {:error, :invalid_command_handler, state.plugin_states}
              end
            else
              Raxol.Core.Runtime.Log.error_with_stacktrace(
                "Could not find state for plugin #{inspect(plugin_module)} handling command '#{command_name_str}'"
              )

              # Return error to plugin manager
              {:error, :missing_plugin_state, state.plugin_states}
            end

          :not_found ->
            Raxol.Core.Runtime.Log.warning_with_context(
              "Command '#{command_name_str}' not found in namespace #{inspect(namespace)}",
              context: __MODULE__,
              stacktrace: nil
            )

            :not_found
        end

      {:error, reason} ->
        {:error, reason, state.plugin_states}
    end
  end

  @doc """
  Finds the plugin ID for a given module.
  """
  def find_plugin_id_by_module(plugins, module) do
    Enum.find_value(plugins, fn {id, mod} -> if mod == module, do: id end)
  end

  @doc """
  Validates command arguments.
  """
  def validate_command_args(args) do
    cond do
      is_nil(args) ->
        {:error, :invalid_args}

      not is_list(args) ->
        {:error, :invalid_args}

      Enum.any?(args, &(not is_binary(&1) and not is_number(&1))) ->
        {:error, :invalid_args}

      true ->
        :ok
    end
  end

  # Helper function to execute a function with a timeout
  defp with_timeout(fun, timeout) do
    task = Task.async(fun)

    try do
      Task.await(task, timeout)
    catch
      :exit, {:timeout, _} ->
        Task.shutdown(task)
        {:error, :timeout}

      :exit, reason ->
        {:error, reason}
    end
  end

  @doc """
  Unregisters all commands associated with a specific plugin module.
  """
  def unregister_plugin_commands(command_table, plugin_module) do
    Raxol.Core.Runtime.Log.debug("Unregistering commands for module: #{inspect(plugin_module)}")
    # Use correct function name
    CommandRegistry.unregister_commands_by_module(command_table, plugin_module)
  end
end
