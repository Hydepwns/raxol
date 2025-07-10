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
          3,
          acc,
          fn acc, plugin, _callback_name, result ->
            case result do
              {:ok, updated_plugin, updated_plugin_state} ->
                # Plugin returned both updated plugin and plugin state
                acc_manager = extract_manager_from_acc(acc)

                updated_manager =
                  update_plugin_state(
                    acc_manager,
                    plugin,
                    updated_plugin,
                    updated_plugin_state
                  )

                {:cont, update_acc_with_manager(acc, updated_manager)}

              {:ok, updated_plugin} ->
                # Plugin returned only updated plugin
                acc_manager = extract_manager_from_acc(acc)

                updated_manager =
                  update_plugin_state(acc_manager, plugin, updated_plugin)

                {:cont, update_acc_with_manager(acc, updated_manager)}

              {:error, reason} ->
                {:halt, {:error, reason}}

              _ ->
                # Unknown result format, continue with current state
                {:cont, acc}
            end
          end
        )
      end)

    case result do
      {:error, reason} -> {:error, reason}
      acc -> {:ok, acc.manager}
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

    dispatch_event(
      manager,
      :handle_mouse,
      [event, rendered_cells],
      initial_acc,
      &handle_mouse_update/4
    )
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
          fn acc, plugin, _callback_name, result ->
            case result do
              {:ok, updated_plugin, transformed_output}
              when is_binary(transformed_output) ->
                acc_manager = extract_manager_from_acc(acc)

                updated_manager =
                  update_plugin_state(acc_manager, plugin, updated_plugin)

                updated_acc = %{
                  acc
                  | manager: updated_manager,
                    output: transformed_output
                }

                {:cont, updated_acc}

              {:ok, updated_plugin, updated_plugin_state} ->
                acc_manager = extract_manager_from_acc(acc)

                updated_manager =
                  update_plugin_state(
                    acc_manager,
                    plugin,
                    updated_plugin,
                    updated_plugin_state
                  )

                {:cont, update_acc_with_manager(acc, updated_manager)}

              {:ok, updated_plugin} ->
                acc_manager = extract_manager_from_acc(acc)

                updated_manager =
                  update_plugin_state(acc_manager, plugin, updated_plugin)

                {:cont, update_acc_with_manager(acc, updated_manager)}

              {:error, reason} ->
                {:halt, {:error, reason}}

              _ ->
                {:cont, acc}
            end
          end
        )
      end)

    case result do
      {:error, reason} ->
        {:error, reason}

      acc ->
        {:ok, acc.manager, acc.output}
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
    if plugin.enabled do
      # Get module from plugin struct, with fallback to __struct__
      module =
        case plugin do
          %{module: mod} when not is_nil(mod) -> mod
          %{__struct__: struct_module} -> struct_module
          _ -> nil
        end

      if module && function_exported?(module, callback_name, required_arity) do
        acc_manager = extract_manager_from_acc(acc)
        plugin_key = normalize_plugin_key(plugin.name)

        current_plugin_state =
          Map.get(acc_manager.plugin_states, plugin_key, %{})

        # Special case for handle_output and handle_input: only pass plugin and event
        callback_args =
          if (callback_name == :handle_output or callback_name == :handle_input) and
               required_arity == 2 do
            [plugin | event_args]
          else
            [plugin, current_plugin_state | event_args]
          end

        try do
          result = apply(module, callback_name, callback_args)
          handle_result_fun.(acc, plugin, callback_name, result)
        rescue
          e ->
            stacktrace = __STACKTRACE__

            Raxol.Core.Runtime.Log.error_with_stacktrace(
              "[#{__MODULE__}] Plugin #{inspect(plugin.name)} raised an exception during #{callback_name} event handling",
              e,
              stacktrace,
              %{
                plugin: plugin.name,
                callback: callback_name,
                module: __MODULE__
              }
            )

            exception = Exception.normalize(:error, e, stacktrace)
            {:halt, {:error, {exception, stacktrace}}}
        catch
          kind, value ->
            stacktrace = __STACKTRACE__

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
      else
        # Plugin enabled but doesn't implement the required callback, continue
        {:cont, acc}
      end
    else
      # Plugin disabled, continue
      {:cont, acc}
    end
  end

  # Helper to update accumulator with new manager state
  defp update_acc_with_manager(acc, updated_manager) do
    %{acc | manager: updated_manager}
  end

  # Helper to extract manager from accumulator
  defp extract_manager_from_acc(acc) do
    acc.manager
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
  defp handle_mouse_update(
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

      {:error, reason} ->
        log_plugin_error(plugin, callback_name, reason)
        {:halt, {:error, reason}}

      other ->
        log_unexpected_result(plugin, callback_name, other)
        {:cont, {:ok, acc_manager, propagation}}
    end
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

    # Ensure the updated plugin has the required fields
    enhanced_plugin =
      case updated_plugin do
        # Already has required fields
        %{module: mod, state: _state} = p when not is_nil(mod) ->
          p

        %{__struct__: struct_module} = p ->
          # Extract state from the plugin struct fields
          plugin_state = extract_state_from_plugin_struct(p)
          Map.merge(p, %{module: struct_module, state: plugin_state})

        p when is_map(p) ->
          # If module is missing, set it to the original plugin's module
          Map.put(p, :module, plugin.module)

        _ ->
          # Fallback: create a basic plugin struct
          %{updated_plugin | module: plugin.module, state: %{}}
      end

    # Use explicit plugin state if provided, otherwise extract from enhanced plugin
    plugin_state =
      case explicit_plugin_state do
        nil ->
          case enhanced_plugin do
            %{state: state} when not is_nil(state) -> state
            _ -> %{}
          end

        state ->
          state
      end

    %{
      acc_manager
      | plugins: Map.put(acc_manager.plugins, plugin_key, enhanced_plugin),
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
      :enabled
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
