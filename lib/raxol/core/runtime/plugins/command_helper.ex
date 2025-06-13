defmodule Raxol.Core.Runtime.Plugins.CommandHelper do
  @moduledoc """
  Handles plugin command registration and dispatch for the Plugin Manager.
  """

  @behaviour Raxol.Core.Runtime.Plugins.PluginCommandHelper.Behaviour

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.CommandRegistry

  @impl true
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

  @impl true
  def register_plugin_commands(plugin_module, _plugin_state, command_table) do
    # Only support get_commands/0 now
    if function_exported?(plugin_module, :get_commands, 0) do
      try do
        commands = plugin_module.get_commands()

        if is_list(commands) do
          updated_table =
            Enum.reduce(commands, command_table, fn
              {name, function, arity}, acc
              when is_atom(name) and is_atom(function) and is_integer(arity) and
                     arity >= 0 ->
                name_str =
                  Atom.to_string(name) |> String.trim() |> String.downcase()

                # Disallow spaces in command names
                if String.contains?(name_str, " ") or
                     not String.match?(name_str, ~r/^[a-zA-Z0-9_-]+$/) do
                  Raxol.Core.Runtime.Log.warning_with_context(
                    "Command name '#{name_str}' is invalid. Skipping registration.",
                    context: __MODULE__,
                    stacktrace: nil
                  )

                  acc
                else
                  if function_exported?(plugin_module, function, arity) do
                    case CommandRegistry.register_command(
                           acc,
                           plugin_module,
                           name_str,
                           plugin_module,
                           function,
                           arity
                         ) do
                      new_table when is_map(new_table) -> new_table
                      _ -> acc
                    end
                  else
                    Raxol.Core.Runtime.Log.warning_with_context(
                      "Plugin #{inspect(plugin_module)} does not export #{function}/#{arity} for command #{inspect(name)}. Skipping registration.",
                      context: __MODULE__,
                      stacktrace: nil
                    )

                    acc
                  end
                end

              _invalid, acc ->
                acc
            end)

          updated_table
        else
          Raxol.Core.Runtime.Log.warning_with_context(
            "Plugin #{inspect(plugin_module)} get_commands/0 did not return a list.",
            context: __MODULE__,
            stacktrace: nil
          )

          command_table
        end
      rescue
        error ->
          Raxol.Core.Runtime.Log.error_with_stacktrace(
            "Error calling get_commands/0 on #{inspect(plugin_module)}: #{inspect(error)}",
            error,
            nil
          )

          command_table
      end
    else
      # No get_commands/0 function exported, nothing to register
      command_table
    end
  end

  @impl true
  def handle_command(command_table, command_name_str, namespace, args, state) do
    case validate_command_args(args) do
      :ok ->
        case find_plugin_for_command(
               command_table,
               command_name_str,
               namespace,
               :unknown
             ) do
          {:ok, {plugin_module, handler, _arity}}
          when is_function(handler, 2) ->
            plugin_id = find_plugin_id_by_module(state.plugins, plugin_module)

            if plugin_id && Map.has_key?(state.plugin_states, plugin_id) do
              current_plugin_state = state.plugin_states[plugin_id]

              try do
                case with_timeout(
                       fn -> handler.(args, current_plugin_state) end,
                       5000
                     ) do
                  {:ok, new_plugin_state, result_tuple}
                  when is_map(new_plugin_state) ->
                    Raxol.Core.Runtime.Log.debug(
                      "Command '#{command_name_str}' handled by #{inspect(plugin_module)}, result: #{inspect(result_tuple)} (direct match)"
                    )

                    _updated_states =
                      Map.put(state.plugin_states, plugin_id, new_plugin_state)

                    {:ok, new_plugin_state, result_tuple, plugin_id}

                  {:error, reason_tuple, new_plugin_state}
                  when is_map(new_plugin_state) ->
                    Raxol.Core.Runtime.Log.error_with_stacktrace(
                      "Error handling command '#{command_name_str}' in #{inspect(plugin_module)}: #{inspect(reason_tuple)} (direct match)",
                      nil,
                      nil,
                      %{
                        command_name: command_name_str,
                        plugin_module: plugin_module
                      }
                    )

                    {:error, reason_tuple, plugin_id}

                  {status, new_plugin_state}
                  when status in [:noreply, :reply, :stop] and
                         is_map(new_plugin_state) ->
                    Raxol.Core.Runtime.Log.warning_with_context(
                      "Plugin #{inspect(plugin_module)} returned {#{inspect(status)}, state} from command handler, which is not a valid command return. Expected {:ok, state, result} or {:error, reason, state}.",
                      context: __MODULE__,
                      stacktrace: nil
                    )

                    {:error,
                     {:unexpected_plugin_return, {status, new_plugin_state}},
                     plugin_id}

                  {:error, {:exception, _error}} = _invalid_return ->
                    Raxol.Core.Runtime.Log.error_with_stacktrace(
                      "Exception handling command '#{command_name_str}' in #{inspect(plugin_module)}: exception (from handler return)",
                      :exception,
                      nil,
                      %{
                        command_name: command_name_str,
                        plugin_module: plugin_module
                      }
                    )

                    {:error, :exception, plugin_id}

                  invalid_return ->
                    Raxol.Core.Runtime.Log.warning_with_context(
                      "Plugin #{inspect(plugin_module)} returned unexpected value from command handler: #{inspect(invalid_return)}. Expected {:ok, state, result} or {:error, reason, state}.",
                      context: __MODULE__,
                      stacktrace: nil
                    )

                    {:error, {:unexpected_plugin_return, invalid_return},
                     plugin_id}
                end
              rescue
                error ->
                  Raxol.Core.Runtime.Log.error_with_stacktrace(
                    "Exception handling command '#{command_name_str}' in #{inspect(plugin_module)}: #{inspect(error)}",
                    error,
                    nil,
                    %{
                      command_name: command_name_str,
                      plugin_module: plugin_module
                    }
                  )

                  {:error, {:exception, error}, plugin_id}
              end
            else
              Raxol.Core.Runtime.Log.error_with_stacktrace(
                "Could not find state for plugin #{inspect(plugin_module)} handling command '#{command_name_str}'",
                nil,
                nil,
                %{command_name: command_name_str, plugin_module: plugin_module}
              )

              {:error, :missing_plugin_state, plugin_id}
            end

          {:error, :not_found} ->
            {:error, :not_found, nil}
        end

      {:error, reason} ->
        {:error, reason, nil}
    end
  end

  @impl true
  def unregister_plugin_commands(command_table, plugin_module) do
    Raxol.Core.Runtime.Log.debug(
      "Unregistering commands for module: #{inspect(plugin_module)}"
    )

    # Use correct function name
    CommandRegistry.unregister_commands_by_module(command_table, plugin_module)
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
    task =
      Task.async(fn ->
        try do
          fun.()
        rescue
          error -> {:error, {:exception, error}}
        end
      end)

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
end
