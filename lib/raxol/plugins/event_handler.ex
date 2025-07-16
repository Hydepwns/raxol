defmodule Raxol.Plugins.EventHandler do
  @moduledoc """
  Handles dispatching various events (input, resize, mouse, etc.) to plugins.

  Provides a generic mechanism to iterate through enabled plugins and invoke
  specific callback functions defined by the `Raxol.Plugins.Plugin` behaviour.
  Updates the plugin manager state based on the results returned by the plugins.
  """

  import Raxol.Guards

  require Raxol.Core.Runtime.Log

  alias Raxol.Plugins.Manager.Core

  @type event :: map()
  @type plugin :: map()
  @type manager :: Core.t()
  @type result :: {:ok, manager()} | {:error, term()}
  @type propagation :: :propagate | :halt

  @doc """
  Dispatches an "input" event to all enabled plugins implementing `handle_input/2`.
  """
  @spec handle_input(Core.t(), binary()) :: result()
  def handle_input(manager, input) do
    initial_acc = %{manager: manager, input: input}

    result =
      Enum.reduce_while(manager.plugins, initial_acc, fn {_key, plugin}, acc ->
        handle_plugin_event(
          plugin,
          :handle_input,
          [acc.input],
          2,
          acc,
          &handle_input_result/4
        )
      end)

    if is_map(result) do
      {:ok, result.manager}
    else
      result
    end
  end

  defp handle_input_result(acc, plugin, _callback_name, result) do
    case result do
      {:ok, updated_plugin, updated_plugin_state} ->
        updated_manager =
          update_plugin_state(
            extract_manager_from_acc(acc),
            plugin,
            updated_plugin,
            updated_plugin_state
          )

        {:cont, update_acc_with_manager(acc, updated_manager)}

      {:ok, updated_plugin} ->
        updated_manager =
          update_plugin_state(
            extract_manager_from_acc(acc),
            plugin,
            updated_plugin
          )

        {:cont, update_acc_with_manager(acc, updated_manager)}

      {:error, reason} ->
        {:halt, {:error, reason}}

      _ ->
        {:cont, acc}
    end
  end

  @doc """
  Dispatches a "resize" event to all enabled plugins implementing `handle_resize/3`.
  """
  @spec handle_resize(Core.t(), integer(), integer()) :: result()
  def handle_resize(%Core{} = manager, width, height) do
    event = %{
      type: :resize,
      width: width,
      height: height,
      timestamp: System.monotonic_time()
    }

    dispatch_event(
      manager,
      :handle_resize,
      [event],
      {:ok, manager},
      &handle_simple_update/4
    )
  end

  @doc """
  Dispatches a mouse event to all enabled plugins implementing `handle_mouse/3`.
  Returns {:ok, updated_manager, :propagate | :halt} or {:error, reason}.
  """
  @spec handle_mouse_event(Core.t(), map(), map()) ::
          {:ok, Core.t(), propagation()} | {:error, term()}
  def handle_mouse_event(%Core{} = manager, event, rendered_cells) do
    # Ensure event has required fields
    event =
      Map.merge(
        %{
          type: :mouse,
          timestamp: System.monotonic_time()
        },
        event
      )

    # Initial accumulator includes the propagation state
    initial_acc = {:ok, manager, :propagate}

    result =
      dispatch_event(
        manager,
        :handle_mouse,
        [event, rendered_cells],
        initial_acc,
        &handle_mouse_update/4
      )

    case result do
      {:ok, _manager, _propagation} ->
        result

      {:error, _} = err ->
        err

      {:ok, mgr} ->
        {:ok, mgr, :propagate}

      mgr when is_map(mgr) ->
        # Check if this is a manager struct (has :plugins key)
        if Map.has_key?(mgr, :plugins) do
          {:ok, mgr, :propagate}
        else
          {:ok, manager, :propagate}
        end

      _ ->
        {:ok, manager, :propagate}
    end
  end

  @doc """
  Dispatches an "output" event to all enabled plugins implementing `handle_output/2`.
  Accumulates transformed output.
  """
  @spec handle_output(Core.t(), binary()) ::
          {:ok, Core.t(), binary()} | {:error, term()}
  def handle_output(manager, output) do
    initial_acc = %{manager: manager, output: output}

    result =
      Enum.reduce_while(manager.plugins, initial_acc, fn {_key, plugin}, acc ->
        handle_plugin_event(
          plugin,
          :handle_output,
          [acc.output],
          2,
          acc,
          &handle_output_result/4
        )
      end)

    if is_map(result) do
      {:ok, result.manager, result.output}
    else
      result
    end
  end

  defp handle_output_result(acc, plugin, _callback_name, result) do
    case result do
      {:ok, updated_plugin, transformed_output}
      when is_binary(transformed_output) ->
        updated_manager =
          update_plugin_state(
            extract_manager_from_acc(acc),
            plugin,
            updated_plugin
          )

        {:cont, %{acc | manager: updated_manager, output: transformed_output}}

      {:ok, updated_plugin, updated_plugin_state} ->
        updated_manager =
          update_plugin_state(
            extract_manager_from_acc(acc),
            plugin,
            updated_plugin,
            updated_plugin_state
          )

        {:cont, update_acc_with_manager(acc, updated_manager)}

      {:ok, updated_plugin} ->
        updated_manager =
          update_plugin_state(
            extract_manager_from_acc(acc),
            plugin,
            updated_plugin
          )

        {:cont, update_acc_with_manager(acc, updated_manager)}

      {:error, reason} ->
        {:halt, {:error, reason}}

      _ ->
        {:cont, acc}
    end
  end

  @doc """
  Dispatches a key event to enabled plugins implementing `handle_input/2`.
  Returns {:ok, updated_manager, :propagate | :halt} or {:error, reason}.
  """
  @spec handle_key_event(Core.t(), map()) ::
          {:ok, Core.t(), propagation()} | {:error, term()}
  def handle_key_event(%Core{} = manager, key_event) do
    # Ensure event has required fields
    event =
      Map.merge(
        %{
          type: :key,
          timestamp: System.monotonic_time()
        },
        key_event
      )

    # Initial accumulator includes the propagation state
    initial_acc = {:ok, manager, :propagate}

    dispatch_event(
      manager,
      :handle_input,
      [event],
      initial_acc,
      &handle_key_update/4
    )
  end

  # --- Private Generic Dispatcher ---

  # Now takes an initial_accumulator and passes it to Enum.reduce_while
  @type event_args :: list(any())
  @type callback_name :: atom()
  @type accumulator :: any()
  # Extracted type
  @type handler_payload :: accumulator() | {:error, term()}
  # Simplified line 82
  @type handler_result :: {:cont | :halt, handler_payload()}
  # @type result_handler_fun :: (accumulator(), map(), callback_name(), any()) -> handler_result() # Commented out

  # Use fun() instead
  @spec dispatch_event(
          Core.t(),
          callback_name(),
          event_args(),
          accumulator(),
          fun()
        ) ::
          accumulator() | {:error, term()}
  defp dispatch_event(
         manager,
         callback_name,
         event_args,
         initial_accumulator,
         handle_result_fun
       ) do
    # +1 for the plugin state itself
    required_arity = length(event_args) + 1

    Enum.reduce_while(manager.plugins, initial_accumulator, fn {_plugin_name,
                                                                plugin},
                                                               acc ->
      case acc do
        {:error, _reason} ->
          {:halt, acc}

        _ ->
          handle_plugin_event(
            plugin,
            callback_name,
            event_args,
            required_arity,
            acc,
            handle_result_fun
          )
      end
    end)
  end

  defp handle_plugin_event(
         plugin,
         callback_name,
         event_args,
         required_arity,
         acc,
         handle_result_fun
       ) do
    cond do
      not plugin.enabled ->
        {:cont, acc}

      not has_required_callback?(plugin, callback_name, required_arity) ->
        {:cont, acc}

      true ->
        execute_plugin_callback(
          plugin,
          callback_name,
          event_args,
          required_arity,
          acc,
          handle_result_fun
        )
    end
  end

  defp has_required_callback?(plugin, callback_name, required_arity) do
    module = extract_module(plugin)
    module && function_exported?(module, callback_name, required_arity)
  end

  defp extract_module(plugin) do
    case plugin do
      %{module: mod} when not is_nil(mod) -> mod
      %{__struct__: struct_module} -> struct_module
      _ -> nil
    end
  end

  defp execute_plugin_callback(
         plugin,
         callback_name,
         event_args,
         required_arity,
         acc,
         handle_result_fun
       ) do
    module = extract_module(plugin)
    acc_manager = extract_manager_from_acc(acc)
    plugin_key = normalize_plugin_key(plugin.name)
    current_plugin_state = Map.get(acc_manager.plugin_states, plugin_key, %{})

    callback_args =
      build_callback_args(
        plugin,
        callback_name,
        event_args,
        required_arity,
        current_plugin_state
      )

    try do
      result = apply(module, callback_name, callback_args)
      handle_result_fun.(acc, plugin, callback_name, result)
    rescue
      e ->
        stacktrace = Process.info(self(), :current_stacktrace) |> elem(1)
        handle_plugin_exception(plugin, callback_name, e, stacktrace)
    catch
      kind, value ->
        stacktrace = Process.info(self(), :current_stacktrace) |> elem(1)
        handle_plugin_error(plugin, callback_name, kind, value, stacktrace)
    end
  end

  defp build_callback_args(
         plugin,
         callback_name,
         event_args,
         required_arity,
         current_plugin_state
       ) do
    if (callback_name == :handle_output or callback_name == :handle_input) and
         required_arity == 2 do
      [plugin | event_args]
    else
      [plugin, current_plugin_state | event_args]
    end
  end

  defp handle_plugin_exception(plugin, callback_name, e, stacktrace) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "[#{__MODULE__}] Plugin #{inspect(plugin.name)} raised an exception during #{callback_name} event handling",
      e,
      stacktrace,
      %{plugin: plugin.name, callback: callback_name, module: __MODULE__}
    )

    exception = Exception.normalize(:error, e, stacktrace)
    {:halt, {:error, {exception, stacktrace}}}
  end

  defp handle_plugin_error(plugin, callback_name, kind, value, stacktrace) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "[#{__MODULE__}] Plugin #{inspect(plugin.name)} raised an error during #{callback_name} event handling",
      value,
      stacktrace,
      %{
        plugin: plugin.name,
        callback: callback_name,
        kind: kind,
        module: __MODULE__
      }
    )

    _ = Exception.normalize(:error, value, stacktrace)
    {:halt, {:error, {kind, value, stacktrace}}}
  end

  # Helper to update accumulator with new manager state
  defp update_acc_with_manager(acc, updated_manager) do
    %{acc | manager: updated_manager}
  end

  # Helper to extract manager from accumulator
  defp extract_manager_from_acc(acc) when is_map(acc) do
    acc.manager
  end

  defp extract_manager_from_acc({:ok, manager, _propagation}) do
    manager
  end

  defp extract_manager_from_acc({:ok, manager}) do
    manager
  end

  # Helper to normalize plugin keys to strings
  defp normalize_plugin_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_plugin_key(key) when is_binary(key), do: key

  # --- Private Result Handlers ---

  # Handles the common case where the plugin callback returns {:ok, updated_plugin} or {:error, reason}
  # and propagation should always continue.
  @spec handle_simple_update(accumulator(), plugin(), callback_name(), term()) ::
          handler_result()
  defp handle_simple_update(
         {:ok, acc_manager},
         plugin,
         callback_name,
         plugin_result
       ) do
    case plugin_result do
      {:ok, updated_plugin} ->
        new_manager_state =
          update_plugin_state(acc_manager, plugin, updated_plugin)

        {:cont, {:ok, new_manager_state}}

      {:error, reason} ->
        log_plugin_error(plugin, callback_name, reason)
        {:halt, {:error, reason}}

      other ->
        log_unexpected_result(plugin, callback_name, other)
        {:cont, {:ok, acc_manager}}
    end
  end

  # Handle cases where acc might already be an error
  defp handle_simple_update(
         {:error, _} = error_acc,
         _plugin,
         _callback_name,
         _plugin_result
       ),
       do: {:halt, error_acc}

  # Handles results for handle_output, accumulating transformed output.
  @spec handle_output_update(accumulator(), plugin(), callback_name(), term()) ::
          handler_result()
  defp handle_output_update(
         {:ok, acc_manager, acc_output},
         plugin,
         callback_name,
         plugin_result
       ) do
    case plugin_result do
      {:ok, updated_plugin} ->
        new_manager_state =
          update_plugin_state(acc_manager, plugin, updated_plugin)

        {:cont, {:ok, new_manager_state, acc_output}}

      {:ok, updated_plugin, transformed_output}
      when binary?(transformed_output) ->
        new_manager_state =
          update_plugin_state(acc_manager, plugin, updated_plugin)

        {:cont, {:ok, new_manager_state, transformed_output}}

      {:error, _reason} ->
        handle_plugin_error(
          plugin,
          callback_name,
          plugin_result,
          {:ok, acc_manager, acc_output}
        )

      other ->
        log_unexpected_result(plugin, callback_name, other)
        {:cont, {:ok, acc_manager, acc_output}}
    end
  end

  defp handle_output_update(
         {:error, _} = error_acc,
         _plugin,
         _callback_name,
         _plugin_result
       ),
       do: {:halt, error_acc}

  # Handles results for handle_mouse_event, managing :halt propagation.
  @spec handle_mouse_update(accumulator(), plugin(), callback_name(), term()) ::
          handler_result()
  defp handle_mouse_update(acc, plugin, callback_name, plugin_result) do
    {acc_manager, propagation} = extract_manager_and_propagation(acc)

    handle_mouse_result(
      acc_manager,
      propagation,
      plugin,
      callback_name,
      plugin_result
    )
  end

  defp extract_manager_and_propagation(acc) do
    case acc do
      {:ok, manager, prop} -> {manager, prop}
      {:ok, manager} -> {manager, :propagate}
      manager when is_map(manager) -> {manager, :propagate}
      _ -> {acc, :propagate}
    end
  end

  defp handle_mouse_result(
         acc_manager,
         propagation,
         plugin,
         callback_name,
         {:ok, updated_plugin}
       ) do
    create_continue_result(acc_manager, plugin, updated_plugin, propagation)
  end

  defp handle_mouse_result(
         acc_manager,
         _propagation,
         plugin,
         callback_name,
         {:ok, updated_plugin, :halt}
       ) do
    create_halt_result(acc_manager, plugin, updated_plugin)
  end

  defp handle_mouse_result(
         acc_manager,
         _propagation,
         plugin,
         callback_name,
         {:ok, updated_plugin, new_propagation}
       )
       when is_atom(new_propagation) do
    create_continue_result(acc_manager, plugin, updated_plugin, new_propagation)
  end

  defp handle_mouse_result(
         _acc_manager,
         _propagation,
         plugin,
         callback_name,
         {:error, reason}
       ) do
    handle_mouse_error(plugin, callback_name, reason)
  end

  defp handle_mouse_result(
         acc_manager,
         propagation,
         plugin,
         _callback_name,
         result
       )
       when is_map(result) and not is_tuple(result) do
    create_continue_result(acc_manager, plugin, result, propagation)
  end

  defp handle_mouse_result(
         acc_manager,
         propagation,
         plugin,
         callback_name,
         other
       ) do
    handle_mouse_unexpected(
      plugin,
      callback_name,
      other,
      acc_manager,
      propagation
    )
  end

  defp handle_mouse_error(plugin, callback_name, reason) do
    log_plugin_error(plugin, callback_name, reason)
    {:halt, {:error, reason}}
  end

  defp handle_mouse_unexpected(
         plugin,
         callback_name,
         other,
         acc_manager,
         propagation
       ) do
    log_unexpected_result(plugin, callback_name, other)
    {:cont, {:ok, acc_manager, propagation}}
  end

  defp create_continue_result(acc_manager, plugin, updated_plugin, propagation) do
    new_manager_state = update_plugin_state(acc_manager, plugin, updated_plugin)
    {:cont, {:ok, new_manager_state, propagation}}
  end

  defp create_halt_result(acc_manager, plugin, updated_plugin) do
    new_manager_state = update_plugin_state(acc_manager, plugin, updated_plugin)
    {:halt, {:ok, new_manager_state, :halt}}
  end

  # Handles results for handle_key_event, managing commands and propagation.
  @spec handle_key_update(accumulator(), plugin(), callback_name(), term()) ::
          handler_result()
  defp handle_key_update(
         {:ok, acc_manager, propagation},
         plugin,
         callback_name,
         plugin_result
       ) do
    case plugin_result do
      {:ok, updated_plugin} ->
        new_manager_state =
          update_plugin_state(acc_manager, plugin, updated_plugin)

        {:cont, {:ok, new_manager_state, propagation}}

      {:ok, updated_plugin, :halt} ->
        new_manager_state =
          update_plugin_state(acc_manager, plugin, updated_plugin)

        {:halt, {:ok, new_manager_state, :halt}}

      {:error, _reason} ->
        handle_plugin_error(
          plugin,
          callback_name,
          plugin_result,
          {:ok, acc_manager, propagation}
        )

      other ->
        log_unexpected_result(plugin, callback_name, other)
        {:cont, {:ok, acc_manager, propagation}}
    end
  end

  defp handle_key_update(
         {:error, _} = error_acc,
         _plugin,
         _callback_name,
         _result
       ),
       do: {:halt, error_acc}

  # Improved logging functions

  defp log_plugin_error(plugin, callback_name, reason) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Plugin #{plugin.name} failed during #{callback_name}",
      reason,
      nil,
      %{
        plugin: plugin.name,
        callback: callback_name,
        module: __MODULE__
      }
    )
  end

  defp log_unexpected_result(plugin, callback_name, result) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin #{plugin.name} returned unexpected value from #{callback_name}",
      %{
        plugin: plugin.name,
        callback: callback_name,
        value: result,
        module: __MODULE__
      }
    )
  end

  # Add this helper function
  defp update_plugin_state(acc_manager, plugin, updated_plugin) do
    update_plugin_state(acc_manager, plugin, updated_plugin, nil)
  end

  defp update_plugin_state(
         acc_manager,
         plugin,
         updated_plugin,
         explicit_plugin_state
       ) do
    plugin_key = normalize_plugin_key(plugin.name)

    # Use the updated plugin as-is, preserving all its fields including search_term
    # Only ensure it has the module field for consistency
    final_plugin =
      case updated_plugin do
        %{module: _} = p -> p
        p when is_map(p) -> Map.put(p, :module, plugin.module)
        _ -> %{updated_plugin | module: plugin.module}
      end

    # Extract state for the plugin_states map
    plugin_state =
      case explicit_plugin_state do
        nil -> extract_state_from_plugin_struct(final_plugin)
        state -> state
      end

    %{
      acc_manager
      | plugins: Map.put(acc_manager.plugins, plugin_key, final_plugin),
        plugin_states:
          if is_map(plugin_state) do
            Map.put(acc_manager.plugin_states, plugin_key, plugin_state)
          else
            acc_manager.plugin_states
          end
    }
  end

  # Helper to extract state from plugin struct fields
  defp extract_state_from_plugin_struct(plugin) do
    # Extract fields that represent state (excluding metadata fields)
    state_fields = [
      :search_term,
      :search_results,
      :current_result_index,
      :image_escape_sequence,
      :sequence_just_generated,
      :current_theme,
      :enabled,
      :selection_active,
      :selection_start,
      :selection_end,
      :last_cells_at_selection
    ]

    Enum.reduce(state_fields, %{}, fn field, acc ->
      case Map.get(plugin, field) do
        nil -> acc
        value -> Map.put(acc, field, value)
      end
    end)
  end

  # Add this helper function
  defp handle_plugin_error(plugin, callback_name, plugin_result, _acc) do
    case plugin_result do
      {:error, reason} ->
        log_plugin_error(plugin, callback_name, reason)
        {:halt, {:error, reason}}

      other ->
        log_unexpected_result(plugin, callback_name, other)
        {:cont, {:error, "Unexpected result"}}
    end
  end
end
