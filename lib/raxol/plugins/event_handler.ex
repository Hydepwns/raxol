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
  def handle_mouse_legacy(%Core{} = manager, event, emulator_state) do
    # Convert legacy tuple event to map format
    event_map = case event do
      {x, y, button, modifiers} -> %{
        type: :mouse,
        x: x,
        y: y,
        button: button,
        modifiers: modifiers
      }
      _ -> event
    end

    # Delegate to the new handler
    case handle_mouse_event(manager, event_map, emulator_state) do
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
  def handle_mouse_event(%Core{} = manager, event, rendered_cells) do
    # Initial accumulator includes the propagation state
    initial_acc = {:ok, manager, :propagate}

    dispatch_event(
      manager,
      :handle_mouse,
      [event, rendered_cells],
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
      # Ensure accumulator is not an error before proceeding
      case acc do
        # Stop if previous step resulted in error
        {:error, _reason} ->
          {:halt, acc}

        # Proceed if accumulator is ok
        _ ->
          if plugin.enabled do
            module = plugin.__struct__

            if function_exported?(module, callback_name, required_arity) do
              # Ensure acc_manager can be extracted (may vary based on accumulator structure)
              acc_manager = extract_manager_from_acc(acc)
              current_plugin_state = Map.get(acc_manager.plugins, plugin.name)

              # Prepend the plugin state to the arguments for the callback
              callback_args = [current_plugin_state | event_args]

              try do
                # Call the plugin's callback function
                result = apply(module, callback_name, callback_args)
                # Process the result using the provided handler function
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
    end)
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
         error_acc = {:error, _},
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
         error_acc = {:error, _},
         _plugin,
         _callback_name,
         _plugin_result
       ),
       do: {:halt, error_acc}

  # Handles results for handle_mouse_event, managing :halt propagation.
  @spec handle_mouse_update(accumulator(), map(), callback_name(), term()) ::
          handler_result
  defp handle_mouse_update(
         {:ok, acc_manager, _propagation_state},
         plugin,
         _callback_name,
         plugin_result
       ) do
    case plugin_result do
      # Plugin handled, continue propagation
      {:ok, updated_plugin_state, :propagate} ->
        new_manager_state = %{
          acc_manager
          | plugins:
              Map.put(acc_manager.plugins, plugin.name, updated_plugin_state)
        }

        {:cont, {:ok, new_manager_state, :propagate}}

      # Plugin handled, halt propagation
      {:ok, updated_plugin_state, :halt} ->
        new_manager_state = %{
          acc_manager
          | plugins:
              Map.put(acc_manager.plugins, plugin.name, updated_plugin_state)
        }

        # Halt the Enum.reduce_while
        {:halt, {:ok, new_manager_state, :halt}}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Error from plugin #{plugin.name} in handle_mouse",
          reason,
          nil,
          %{plugin: plugin.name, module: __MODULE__}
        )

        {:halt, {:error, reason}}

      other ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Invalid return from #{plugin.name}.handle_mouse/3. Propagating.",
          %{plugin: plugin.name, value: other, module: __MODULE__}
        )

        # Continue propagating if plugin returns invalid value
        {:cont, {:ok, acc_manager, :propagate}}
    end
  end

  defp handle_mouse_update(
         error_acc = {:error, _},
         _plugin,
         _callback_name,
         _plugin_result
       ),
       do: {:halt, error_acc}

  # Handles results for handle_key_event, managing commands and propagation.
  @spec handle_key_update(accumulator(), map(), callback_name(), term()) ::
          handler_result
  defp handle_key_update(
         {:ok, acc_manager, acc_commands, _propagation_state},
         plugin,
         _callback_name,
         plugin_result
       ) do
    case plugin_result do
      # Plugin returns {:ok, state, command} - Assume propagation continues unless halted
      {:ok, updated_plugin_state, {:command, command_data}} ->
        new_manager_state = %{
          acc_manager
          | plugins:
              Map.put(acc_manager.plugins, plugin.name, updated_plugin_state)
        }

        # Continue processing, add command, maintain propagate state
        {:cont,
         {:ok, new_manager_state, [command_data | acc_commands], :propagate}}

      # Plugin returns {:ok, state} (no command) - Assume propagation continues
      {:ok, updated_plugin_state} ->
        new_manager_state = %{
          acc_manager
          | plugins:
              Map.put(acc_manager.plugins, plugin.name, updated_plugin_state)
        }

        # Continue processing, no command added
        {:cont, {:ok, new_manager_state, acc_commands, :propagate}}

      # TODO: Add explicit :halt handling if needed in Plugin behaviour
      # {:ok, updated_plugin_state, :halt} -> ...
      # {:ok, updated_plugin_state, {:command, cmd}, :halt} -> ...

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Error from plugin #{plugin.name} in handle_input (key event)",
          reason,
          nil,
          %{plugin: plugin.name, module: __MODULE__}
        )

        {:halt, {:error, reason}}

      other ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Invalid return from #{plugin.name}.handle_input/2 (key event). Propagating.",
          %{plugin: plugin.name, value: other, module: __MODULE__}
        )

        # Continue, assuming propagate
        {:cont, {:ok, acc_manager, acc_commands, :propagate}}
    end
  end

  defp handle_key_update(
         error_acc = {:error, _},
         _plugin,
         _callback_name,
         _plugin_result
       ),
       do: {:halt, error_acc}
end
