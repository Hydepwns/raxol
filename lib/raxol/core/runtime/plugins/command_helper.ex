defmodule Raxol.Core.Runtime.Plugins.CommandHelper do
  @moduledoc """
  Handles plugin command registration and dispatch for the Plugin Manager.
  Uses functional patterns with proper error handling using with statements and Tasks.
  """

  # Removed undefined @behaviour Raxol.Core.Runtime.Plugins.PluginCommandHelper.Behaviour

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.CommandRegistry

  # Removed @impl for undefined behaviour
  def find_plugin_for_command(command_table, command_name, namespace, _arity) do
    # Normalize command name: trim whitespace and downcase
    processed_command_name =
      command_name
      |> (fn name -> if is_atom(name), do: Atom.to_string(name), else: name end).()
      |> String.trim()
      |> String.downcase()

    # Namespace is optional (pass nil for global search or specific module)
    namespace_module = process_namespace(namespace)

    case CommandRegistry.lookup_command(
           command_table,
           namespace_module,
           processed_command_name
         ) do
      {:ok, {module, _handler, arity}} ->
        # The callback expects atom for function name, but we have a handler function
        # We need to find the actual function name from the registry
        {:ok, {module, :handle_command, arity}}

      {:error, :not_found} ->
        :not_found
    end
  end

  @spec process_namespace(String.t() | atom()) :: atom() | nil
  defp process_namespace(namespace) when is_binary(namespace) do
    # Functional approach to converting namespace string to atom
    case safe_string_to_existing_atom(namespace) do
      {:ok, atom} ->
        atom

      {:error, _} ->
        Raxol.Core.Runtime.Log.debug(
          "Namespace string could not be converted to an existing atom."
        )

        nil
    end
  end

  @spec process_namespace(String.t() | atom()) :: atom() | nil
  defp process_namespace(namespace) when is_atom(namespace), do: namespace
  @spec process_namespace(term()) :: nil
  defp process_namespace(_), do: nil

  @spec safe_string_to_existing_atom(String.t()) ::
          {:ok, atom()} | {:error, :atom_not_found}
  defp safe_string_to_existing_atom(string) do
    # Safe conversion without try/catch
    case atom_exists?(string) do
      true ->
        {:ok, String.to_existing_atom(string)}

      false ->
        {:error, :atom_not_found}
    end
  end

  @spec atom_exists?(String.t()) :: boolean()
  defp atom_exists?(string) do
    # Check if the atom already exists in the atom table
    # This is a safe way to check without creating new atoms
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           string
           |> String.to_charlist()
           |> :erlang.list_to_existing_atom()
           |> is_atom()
         end) do
      {:ok, result} -> result
      {:error, _} -> false
    end
  end

  # Removed @impl for undefined behaviour
  def register_plugin_commands(plugin_module, _plugin_state, command_table) do
    case function_exported?(plugin_module, :get_commands, 0) do
      true ->
        case safe_get_commands(plugin_module) do
          {:ok, commands} ->
            process_commands(plugin_module, commands, command_table)

          {:error, error} ->
            log_command_error(plugin_module, error)
            command_table
        end

      false ->
        command_table
    end
  end

  @spec safe_get_commands(module()) :: {:ok, list()} | {:error, term()}
  defp safe_get_commands(plugin_module) do
    # Use Task to safely execute and handle any errors
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           get_commands_with_timeout(plugin_module)
         end) do
      {:ok, result} -> result
      {:error, error} -> {:error, error}
    end
  end

  @spec process_commands(module(), list(), map()) :: map()
  defp process_commands(plugin_module, commands, command_table)
       when is_list(commands) do
    Enum.reduce(
      commands,
      command_table,
      &register_command(plugin_module, &1, &2)
    )
  end

  @spec register_command(module(), {atom(), atom(), non_neg_integer()}, map()) ::
          map()
  defp register_command(plugin_module, {name, function, arity}, acc)
       when is_atom(name) and is_atom(function) and is_integer(arity) and
              arity >= 0 do
    name_str = Atom.to_string(name) |> String.trim() |> String.downcase()

    case valid_command_name?(name_str) and
           function_exported?(plugin_module, function, arity) do
      true ->
        register_valid_command(acc, plugin_module, name_str, function, arity)

      false ->
        log_invalid_command(plugin_module, name_str, function, arity)
        acc
    end
  end

  @spec register_command(module(), term(), map()) :: map()
  defp register_command(_plugin_module, _invalid, acc), do: acc

  @spec valid_command_name?(String.t()) :: boolean()
  defp valid_command_name?(name_str) do
    not String.contains?(name_str, " ") and
      String.match?(name_str, ~r/^[a-zA-Z0-9_-]+$/)
  end

  @spec register_valid_command(
          map(),
          module(),
          String.t(),
          atom(),
          non_neg_integer()
        ) :: map()
  defp register_valid_command(acc, plugin_module, name_str, function, arity) do
    # CommandRegistry.register_command always returns a map when given a map input
    CommandRegistry.register_command(
      acc,
      plugin_module,
      name_str,
      plugin_module,
      function,
      arity
    )
  end

  @spec log_invalid_command(module(), String.t(), atom(), non_neg_integer()) ::
          :ok
  defp log_invalid_command(plugin_module, name_str, function, arity) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin #{inspect(plugin_module)} does not export #{function}/#{arity} for command #{inspect(name_str)}. Skipping registration.",
      context: __MODULE__,
      stacktrace: nil
    )
  end

  @spec log_command_error(module(), term()) :: :ok
  defp log_command_error(plugin_module, error) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Error calling get_commands/0 on #{inspect(plugin_module)}: #{inspect(error)}",
      error,
      nil
    )
  end

  # Removed @impl for undefined behaviour
  def handle_command(command_table, command_name_str, _namespace, args, state) do
    with {:ok, {plugin_module, handler, _arity}} <-
           lookup_valid_command(command_table, command_name_str, args),
         {:ok, plugin_id, plugin_state} <-
           get_plugin_state(state, plugin_module),
         {:ok, new_state, _result, plugin_id} <-
           execute_and_update_state(
             handler,
             args,
             plugin_state,
             plugin_id,
             state
           ) do
      updated_plugin_states = Map.put(state.plugin_states, plugin_id, new_state)
      {:ok, updated_plugin_states}
    else
      {:error, :not_found} ->
        {:error, :not_found}

      {:error, :invalid_args} ->
        {:error, :invalid_args, state.plugin_states}

      {:error, :missing_plugin_state} ->
        {:error, :missing_plugin_state, state.plugin_states}

      {:error, :exception, new_state, plugin_id} ->
        updated_plugin_states =
          Map.put(state.plugin_states, plugin_id, new_state)

        {:error, :exception, updated_plugin_states}

      {:error, reason, new_state, plugin_id} ->
        updated_plugin_states =
          Map.put(state.plugin_states, plugin_id, new_state)

        {:error, reason, updated_plugin_states}
    end
  end

  @spec lookup_valid_command(map(), String.t(), list()) ::
          {:ok, {module(), function(), non_neg_integer()}}
          | {:error, :not_found | :invalid_args}
  defp lookup_valid_command(command_table, command_name_str, args) do
    case validate_command_args(args) do
      :ok ->
        # Search for the command in all namespaces in the command table
        case find_command_in_table(command_table, command_name_str) do
          {:ok, result} -> {:ok, result}
          {:error, :not_found} -> {:error, :not_found}
        end

      {:error, :invalid_args} ->
        {:error, :invalid_args}
    end
  end

  @spec find_command_in_table(map(), String.t()) ::
          {:ok, {module(), function(), non_neg_integer()}}
          | {:error, :not_found}
  defp find_command_in_table(command_table, command_name_str) do
    # Search through all namespaces in the command table
    Enum.find_value(command_table, {:error, :not_found}, fn {_namespace,
                                                             commands} ->
      find_and_build_command(commands, command_name_str)
    end)
  end

  @spec get_plugin_state(map(), module()) ::
          {:ok, String.t(), map()} | {:error, :missing_plugin_state}
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

  @spec execute_and_update_state(
          function(),
          list(),
          map(),
          String.t(),
          map()
        ) ::
          {:ok, map(), term(), String.t()} | {:error, term(), map(), String.t()}
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

  @spec execute_command(function(), list(), map()) ::
          {:ok, map(), term()} | {:error, term(), map()}
  defp execute_command(handler, args, plugin_state) do
    case with_timeout(fn -> handler.(args, plugin_state) end, 5000) do
      {:ok, new_state, result} when is_map(new_state) ->
        {:ok, new_state, result}

      {:error, reason, new_state} when is_map(new_state) ->
        {:error, reason, new_state}

      {:error, {:exception, _error}} ->
        {:error, :exception, plugin_state}

      invalid ->
        {:error, {:unexpected_plugin_return, invalid}, plugin_state}
    end
  end

  # Removed @impl for undefined behaviour
  def unregister_plugin_commands(command_table, plugin_module) do
    Raxol.Core.Runtime.Log.debug(
      "Unregistering commands for module: #{inspect(plugin_module)}"
    )

    # Use correct function name and return updated table
    CommandRegistry.unregister_commands_by_module(
      command_table,
      plugin_module
    )
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
    with false <- is_nil(args),
         true <- is_list(args),
         true <- Enum.all?(args, &(is_binary(&1) or is_number(&1))) do
      :ok
    else
      _ -> {:error, :invalid_args}
    end
  end

  # Functional helper function to execute a function with a timeout using Task
  @spec with_timeout(function(), timeout()) ::
          {:ok, map(), term()}
          | {:error, term(), map()}
          | {:error, :timeout}
          | {:error, {:exit, term()}}
          | {:error, {:exception, term()}}
  defp with_timeout(fun, timeout) do
    task =
      Task.async(fn ->
        safe_execute(fun)
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} ->
        result

      nil ->
        {:error, :timeout}

      {:exit, reason} ->
        {:error, {:exit, reason}}
    end
  end

  @spec safe_execute(function()) ::
          {:ok, map(), term()}
          | {:error, term(), map()}
          | {:error, {:exception, term()}}
  defp safe_execute(fun) do
    # Execute the function safely and return structured result
    case Raxol.Core.ErrorHandling.safe_call(fn -> normalize_result(fun.()) end) do
      {:ok, result} -> result
      {:error, %RuntimeError{} = error} -> {:error, {:exception, error}}
      {:error, error} -> {:error, {:exception, error}}
    end
  end

  defp yield_task_with_timeout(task, timeout) do
    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, {:exit, reason}}
    end
  end

  defp build_command_result(module, function, arity) do
    # Create a function that calls the module function
    handler = fn args, state ->
      apply(module, function, [args, state])
    end

    {:ok, {module, handler, arity}}
  end

  defp normalize_result(result) do
    case result do
      {:ok, _state, _result} = success -> success
      {:error, _reason, _state} = error -> error
      {:error, _reason} = error -> error
      other -> {:ok, other, nil}
    end
  end

  defp get_commands_with_timeout(plugin_module) do
    task =
      Task.async(fn ->
        {:ok, plugin_module.get_commands()}
      end)

    yield_task_with_timeout(task, 5000)
  end

  defp find_and_build_command(commands, command_name_str) do
    case Enum.find(commands, fn {name, _, _} -> name == command_name_str end) do
      nil ->
        nil

      {_name, {module, function, arity}, _metadata} ->
        build_command_result(module, function, arity)
    end
  end
end
