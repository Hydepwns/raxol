defmodule Raxol.Plugins.EventHandler do
  @moduledoc """
  Handles dispatching various events (input, resize, mouse, etc.) to plugins.

  Provides a generic mechanism to iterate through enabled plugins and invoke
  specific callback functions defined by the `Raxol.Plugins.Plugin` behaviour.
  Updates the plugin manager state based on the results returned by the plugins.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Plugins.Manager.Core

  @doc """
  Dispatches an 'input' event to all enabled plugins implementing `handle_input/2`.
  """
  @spec handle_input(Core.t(), binary()) ::
          {:ok, Core.t()} | {:error, any()}
  def handle_input(%Core{} = manager, input) do
    dispatch_event(
      manager,
      :handle_input,
      [input],
      {:ok, manager},
      &handle_simple_update/4
    )
  end

  @doc """
  Dispatches a 'resize' event to all enabled plugins implementing `handle_resize/3`.
  """
  @spec handle_resize(Core.t(), integer(), integer()) ::
          {:ok, Core.t()} | {:error, any()}
  def handle_resize(%Core{} = manager, width, height) do
    dispatch_event(
      manager,
      :handle_resize,
      [width, height],
      {:ok, manager},
      &handle_simple_update/4
    )
  end

  @doc """
  Dispatches a 'mouse' event (older format) to all enabled plugins implementing `handle_mouse/3`.
  This corresponds to the previous plugin manager's process_mouse/3 function.

  @deprecated "Use handle_mouse_event/3 instead. The new function provides better event propagation control and cell context."
  """
  @spec handle_mouse_legacy(Core.t(), tuple(), map()) ::
          {:ok, Core.t()} | {:error, any()}
  def handle_mouse_legacy(%Core{} = manager, event, _emulator_state) do
    # Convert legacy tuple event to map format
    event_map =
      case event do
        {x, y, button, modifiers} ->
          %{
            type: :mouse,
            x: x,
            y: y,
            button: button,
            modifiers: modifiers
          }

        _ ->
          event
      end

    # Delegate to the new handler
    case handle_mouse_event(manager, event_map, _emulator_state) do
      {:ok, updated_manager, _propagation} -> {:ok, updated_manager}
      error -> error
    end
  end

  @doc """
  Dispatches an 'output' event to all enabled plugins implementing `handle_output/2`.
  Accumulates transformed output.
  """
  @spec handle_output(Core.t(), binary()) ::
          {:ok, Core.t(), binary()} | {:error, any()}
  def handle_output(%Core{} = manager, output) do
    # Initial accumulator includes the output
    initial_acc = {:ok, manager, output}

    dispatch_event(
      manager,
      :handle_output,
      [output],
      initial_acc,
      &handle_output_update/4
    )
  end

  @doc """
  Dispatches a mouse event (new format with propagation control) to enabled plugins implementing `handle_mouse/3`.
  """
  @spec handle_mouse_event(Core.t(), map(), map()) ::
          {:ok, Core.t(), :propagate | :halt} | {:error, any()}
  def handle_mouse_event(%Core{} = manager, event, _emulator_state) do
    # Initial accumulator includes the propagation state
    initial_acc = {:ok, manager, :propagate}

    dispatch_event(
      manager,
      :handle_mouse,
      [event, _emulator_state],
      initial_acc,
      &handle_mouse_update/4
    )
  end

  @doc """
  Dispatches a key event (map) to enabled plugins implementing `handle_input/2`.
  NOTE: Uses `handle_input/2` as per the original plugin manager logic. Consider adding
        a dedicated `handle_key_event` callback to the Plugin behaviour later.
  Accumulates commands and handles propagation control.
  """
  @spec handle_key_event(Core.t(), map(), map()) ::
          {:ok, Core.t(), list(any()), :propagate | :halt}
          | {:error, any()}
  def handle_key_event(%Core{} = manager, event, rendered_cells) do
    # Initial accumulator includes commands list and propagation state
    initial_acc = {:ok, manager, [], :propagate}
    # Note: Calling :handle_input with event map, requires plugin to handle it
    dispatch_event(
      manager,
      :handle_input,
      [event, rendered_cells],
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
    if plugin.enabled do
      module = plugin.__struct__

      if function_exported?(module, callback_name, required_arity) do
        acc_manager = extract_manager_from_acc(acc)
        current_plugin_state = Map.get(acc_manager.plugins, plugin.name)
        callback_args = [current_plugin_state | event_args]

        try do
          result = apply(module, callback_name, callback_args)
          handle_result_fun.(acc, plugin, callback_name, result)
        rescue
          e ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "[#{__MODULE__}] Plugin '#{inspect(plugin.name)}' raised an exception during #{callback_name} event handling",
              e,
              nil,
              %{
                plugin: plugin.name,
                callback: callback_name,
                module: __MODULE__
              }
            )

            exception = Exception.normalize(:error, e, __STACKTRACE__)
            {:halt, {:error, {exception, __STACKTRACE__}}}
        catch
          kind, value ->
            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "[#{__MODULE__}] Plugin '#{inspect(plugin.name)}' raised an error during #{callback_name} event handling",
              value,
              nil,
              %{
                plugin: plugin.name,
                callback: callback_name,
                kind: kind,
                module: __MODULE__
              }
            )

            _ = Exception.normalize(:error, value, __STACKTRACE__)
            {:halt, {:error, {kind, value, __STACKTRACE__}}}
        end
      else
        # Plugin enabled but doesn't implement the required callback, continue
        {:cont, acc}
      end
    else
      # Plugin disabled, continue
      {:cont, acc}
    end
  end

  # Helper to safely extract the manager from different accumulator structures
  defp extract_manager_from_acc({:ok, manager}), do: manager
  defp extract_manager_from_acc({:ok, manager, _}), do: manager
  defp extract_manager_from_acc({:ok, manager, _, _}), do: manager
  # Add more patterns if needed
  defp extract_manager_from_acc({:ok, manager, _, _, _}), do: manager
  # Or raise an error
  defp extract_manager_from_acc(_), do: nil

  # --- Private Result Handlers ---

  # Handles the common case where the plugin callback returns {:ok, updated_plugin} or {:error, reason}
  # and propagation should always continue.
  @spec handle_simple_update(accumulator(), map(), callback_name(), term()) ::
          handler_result
  defp handle_simple_update(
         {:ok, acc_manager},
         plugin,
         _callback_name,
         plugin_result
       ) do
    case plugin_result do
      {:ok, updated_plugin} ->
        new_manager_state = %{
          acc_manager
          | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin)
        }

        {:cont, {:ok, new_manager_state}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Plugin #{plugin.name} failed during event handling",
          reason,
          nil,
          %{plugin: plugin.name, module: __MODULE__}
        )

        # Halt the reduce_while loop on the first plugin error
        {:halt, {:error, reason}}

      other ->
        # Log a warning for unexpected return values but continue
        Raxol.Core.Runtime.Log.warning_with_context(
          "Plugin #{plugin.name} returned unexpected value. Ignoring.",
          %{plugin: plugin.name, value: other, module: __MODULE__}
        )

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
  @spec handle_output_update(accumulator(), map(), callback_name(), term()) ::
          handler_result
  defp handle_output_update(
         {:ok, acc_manager, acc_output},
         plugin,
         _callback_name,
         plugin_result
       ) do
    case plugin_result do
      # Plugin updated state only
      {:ok, updated_plugin} ->
        new_manager_state = %{
          acc_manager
          | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin)
        }

        {:cont, {:ok, new_manager_state, acc_output}}

      # Plugin updated state and transformed output
      {:ok, updated_plugin, transformed_output}
      when is_binary(transformed_output) ->
        new_manager_state = %{
          acc_manager
          | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin)
        }

        # Pass the transformed output along in the accumulator
        {:cont, {:ok, new_manager_state, transformed_output}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Plugin #{plugin.name} failed during output handling",
          reason,
          nil,
          %{plugin: plugin.name, module: __MODULE__}
        )

        {:halt, {:error, reason}}

      other ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Plugin #{plugin.name} returned unexpected value from handle_output. Ignoring.",
          %{plugin: plugin.name, value: other, module: __MODULE__}
        )

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
  @spec handle_mouse_update(accumulator(), map(), callback_name(), term()) ::
          handler_result
  defp handle_mouse_update(acc, plugin, _callback_name, result) do
    case result do
      {:ok, updated_plugin, :propagate} ->
        acc_manager = extract_manager_from_acc(acc)
        updated_manager = Core.update_plugins(acc_manager, Map.put(acc_manager.plugins, plugin.name, updated_plugin))
        {:cont, {:ok, updated_manager, :propagate}}
      {:ok, updated_plugin, :halt} ->
        acc_manager = extract_manager_from_acc(acc)
        updated_manager = Core.update_plugins(acc_manager, Map.put(acc_manager.plugins, plugin.name, updated_plugin))
        {:halt, {:ok, updated_manager, :halt}}
      {:ok, updated_plugin} ->
        acc_manager = extract_manager_from_acc(acc)
        updated_manager = Core.update_plugins(acc_manager, Map.put(acc_manager.plugins, plugin.name, updated_plugin))
        {:cont, {:ok, updated_manager, :propagate}}
      {:error, reason} ->
        {:halt, {:error, reason}}
      _ ->
        {:cont, acc}
    end
  end

  # Handles results for handle_key_event, managing commands and propagation.
  @spec handle_key_update(accumulator(), map(), callback_name(), term()) ::
          handler_result
  defp handle_key_update(acc, plugin, _callback_name, result) do
    case result do
      {:ok, updated_plugin, :propagate} ->
        acc_manager = extract_manager_from_acc(acc)
        updated_manager = Core.update_plugins(acc_manager, Map.put(acc_manager.plugins, plugin.name, updated_plugin))
        {:cont, {:ok, updated_manager, :propagate}}
      {:ok, updated_plugin, :halt} ->
        acc_manager = extract_manager_from_acc(acc)
        updated_manager = Core.update_plugins(acc_manager, Map.put(acc_manager.plugins, plugin.name, updated_plugin))
        {:halt, {:ok, updated_manager, :halt}}
      {:ok, updated_plugin} ->
        acc_manager = extract_manager_from_acc(acc)
        updated_manager = Core.update_plugins(acc_manager, Map.put(acc_manager.plugins, plugin.name, updated_plugin))
        {:cont, {:ok, updated_manager, :propagate}}
      {:error, reason} ->
        {:halt, {:error, reason}}
      _ ->
        {:cont, acc}
    end
  end

  defp handle_key_update({:error, _} = error_acc, _plugin, _callback_name, _result),
    do: {:halt, error_acc}
end
