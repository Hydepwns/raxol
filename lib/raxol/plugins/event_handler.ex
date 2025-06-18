defmodule Raxol.Plugins.EventHandler do
  @moduledoc """
  Handles dispatching various events (input, resize, mouse, etc.) to plugins.

  Provides a generic mechanism to iterate through enabled plugins and invoke
  specific callback functions defined by the `Raxol.Plugins.Plugin` behaviour.
  Updates the plugin manager state based on the results returned by the plugins.
  """

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
  def handle_input(%Core{} = manager, input) do
    event = %{
      type: :input,
      data: input,
      timestamp: System.monotonic_time()
    }

    dispatch_event(
      manager,
      :handle_input,
      [event],
      {:ok, manager},
      &handle_simple_update/4
    )
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
  def handle_output(%Core{} = manager, output) do
    event = %{
      type: :output,
      data: output,
      timestamp: System.monotonic_time()
    }

    # Initial accumulator includes the output
    initial_acc = {:ok, manager, output}

    dispatch_event(
      manager,
      :handle_output,
      [event],
      initial_acc,
      &handle_output_update/4
    )
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
      when is_binary(transformed_output) ->
        new_manager_state =
          update_plugin_state(acc_manager, plugin, updated_plugin)

        {:cont, {:ok, new_manager_state, transformed_output}}

      {:error, reason} ->
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

      {:error, reason} ->
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
    %{
      acc_manager
      | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin)
    }
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
