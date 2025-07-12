defmodule Raxol.Core.Runtime.Plugins.CommandHelper do
  @moduledoc """
  Handles plugin command registration and dispatch for the Plugin Manager.
  """

  import Raxol.Guards

  @behaviour Raxol.Core.Runtime.Plugins.PluginCommandHelper.Behaviour

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.CommandRegistry

  @impl Raxol.Core.Runtime.Plugins.PluginCommandHelper.Behaviour
  def find_plugin_for_command(command_table, command_name, namespace, _arity) do
    # Normalize command name: trim whitespace and downcase
    processed_command_name =
      command_name
      |> (fn name -> if atom?(name), do: Atom.to_string(name), else: name end).()
      |> String.trim()
      |> String.downcase()

    # Namespace is optional (pass nil for global search or specific module)
    namespace_module =
      cond do
        binary?(namespace) ->
          try do
            String.to_existing_atom(namespace)
          rescue
            ArgumentError ->
              # If namespace string cannot be converted to an atom, treat as no namespace
              Raxol.Core.Runtime.Log.debug(
                # {namespace}" could not be converted to an existing atom."
                "Namespace string "
              )

              nil
          end

        atom?(namespace) ->
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

  @impl Raxol.Core.Runtime.Plugins.PluginCommandHelper.Behaviour
  def register_plugin_commands(plugin_module, _plugin_state, command_table) do
    if function_exported?(plugin_module, :get_commands, 0) do
      try do
        commands = plugin_module.get_commands()
        process_commands(plugin_module, commands, command_table)
      rescue
        error ->
          log_command_error(plugin_module, error)
          command_table
      end
    else
      command_table
    end
  end

  defp process_commands(plugin_module, commands, command_table)
       when list?(commands) do
    Enum.reduce(
      commands,
      command_table,
      &register_command(plugin_module, &1, &2)
    )
  end

  defp process_commands(plugin_module, _invalid, command_table) do
    log_invalid_commands(plugin_module)
    command_table
  end

  defp register_command(plugin_module, {name, function, arity}, acc)
       when atom?(name) and atom?(function) and integer?(arity) and
              arity >= 0 do
    name_str = Atom.to_string(name) |> String.trim() |> String.downcase()

    if valid_command_name?(name_str) and
         function_exported?(plugin_module, function, arity) do
      register_valid_command(acc, plugin_module, name_str, function, arity)
    else
      log_invalid_command(plugin_module, name_str, function, arity)
      acc
    end
  end

  defp register_command(_plugin_module, _invalid, acc), do: acc

  defp valid_command_name?(name_str) do
    not String.contains?(name_str, " ") and
      String.match?(name_str, ~r/^[a-zA-Z0-9_-]+$/)
  end

  defp register_valid_command(acc, plugin_module, name_str, function, arity) do
    case CommandRegistry.register_command(
           acc,
           plugin_module,
           name_str,
           plugin_module,
           function,
           arity
         ) do
      {:ok, new_table} when map?(new_table) -> new_table
      {:error, _reason} -> acc
      new_table when map?(new_table) -> new_table
      _ -> acc
    end
  end

  defp log_invalid_command(plugin_module, name_str, function, arity) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin #{inspect(plugin_module)} does not export #{function}/#{arity} for command #{inspect(name_str)}. Skipping registration.",
      context: __MODULE__,
      stacktrace: nil
    )
  end

  defp log_invalid_commands(plugin_module) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin #{inspect(plugin_module)} get_commands/0 did not return a list.",
      context: __MODULE__,
      stacktrace: nil
    )
  end

  defp log_command_error(plugin_module, error) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Error calling get_commands/0 on #{inspect(plugin_module)}: #{inspect(error)}",
      error,
      nil
    )
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandHelper.Behaviour
  def handle_command(command_table, command_name_str, _namespace, args, state) do
    with {:ok, {plugin_module, handler, _arity}} <-
           lookup_valid_command(command_table, command_name_str, args),
         {:ok, plugin_id, plugin_state} <- get_plugin_state(state, plugin_module),
         {:ok, new_state, _result, plugin_id} <-
           execute_and_update_state(handler, args, plugin_state, plugin_id, state) do
      updated_plugin_states = Map.put(state.plugin_states, plugin_id, new_state)
      {:ok, updated_plugin_states}
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, :missing_plugin_state} -> {:error, :missing_plugin_state, state.plugin_states}
      {:error, reason, new_state, plugin_id} ->
        updated_plugin_states = Map.put(state.plugin_states, plugin_id, new_state)
        {:error, reason, updated_plugin_states}
      {:error, reason} -> {:error, reason, state.plugin_states}
    end
  end

  defp lookup_valid_command(command_table, command_name_str, args) do
    with :ok <- validate_command_args(args) do
      # Search for the command in all namespaces in the command table
      case find_command_in_table(command_table, command_name_str) do
        {:ok, result} -> {:ok, result}
        {:error, :not_found} -> {:error, :not_found}
      end
    end
  end

  defp find_command_in_table(command_table, command_name_str) do
    # Search through all namespaces in the command table
    Enum.find_value(command_table, {:error, :not_found}, fn {_namespace,
                                                             commands} ->
      case Enum.find(commands, fn {name, _, _} -> name == command_name_str end) do
        nil ->
          nil

        {_name, {module, function, arity}, _metadata} ->
          # Create a function that calls the module function
          handler = fn args, state ->
            apply(module, function, [args, state])
          end

          {:ok, {module, handler, arity}}
      end
    end)
  end

  defp get_plugin_state(state, plugin_module) do
    case find_plugin_id_by_module(state.plugins, plugin_module) do
      nil ->
        {:error, :missing_plugin_state}

      plugin_id ->
        case Map.get(state.plugin_states, plugin_id) do
          nil -> {:error, :missing_plugin_state}
          state -> {:ok, plugin_id, state}
        end
    end
  end

  defp execute_and_update_state(handler, args, plugin_state, plugin_id, _state) do
    case execute_command(handler, args, plugin_state) do
      {:ok, new_state, result} ->
        {:ok, new_state, result, plugin_id}

      {:error, :exception, new_state} ->
        {:error, :exception, new_state, plugin_id}

      {:error, reason, new_state} ->
        {:error, reason, new_state, plugin_id}
    end
  end

  defp execute_command(handler, args, plugin_state) do
    case with_timeout(fn -> handler.(args, plugin_state) end, 5000) do
      {:ok, new_state, result} when map?(new_state) ->
        {:ok, new_state, result}

      {:error, reason, new_state} when map?(new_state) ->
        {:error, reason, new_state}

      {:error, {:exception, _error}} ->
        {:error, :exception, plugin_state}

      invalid ->
        {:error, {:unexpected_plugin_return, invalid}, plugin_state}
    end
  end

  @impl Raxol.Core.Runtime.Plugins.PluginCommandHelper.Behaviour
  def unregister_plugin_commands(command_table, plugin_module) do
    Raxol.Core.Runtime.Log.debug(
      "Unregistering commands for module: #{inspect(plugin_module)}"
    )

    # Use correct function name and handle return value
    case CommandRegistry.unregister_commands_by_module(
           command_table,
           plugin_module
         ) do
      {:ok, updated_table} -> updated_table
      {:error, _reason} -> command_table
      _ -> command_table
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
      nil?(args) ->
        {:error, :invalid_args}

      not list?(args) ->
        {:error, :invalid_args}

      Enum.any?(args, &(not binary?(&1) and not number?(&1))) ->
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
