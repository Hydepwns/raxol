defmodule Raxol.Core.Runtime.Plugins.Manager.EventHandlers do
  @moduledoc """
  Handles GenServer event callbacks and message processing for the plugin manager.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.PluginReloader
  alias Raxol.Core.Runtime.Plugins.FileWatcher
  alias Raxol.Core.Runtime.Plugins.TimerManager
  alias Raxol.Core.Runtime.Plugins.CommandHandler
  alias Raxol.Core.Runtime.Plugins.Manager.{Lifecycle, State}

  @type state :: map()
  @type from :: {pid(), reference()}
  @type reply :: term()
  @type noreply :: :noreply
  @type stop :: {:stop, term(), state()}

  @doc """
  Handles synchronous GenServer calls.
  """
  @spec handle_call(term(), from(), state()) ::
          {:reply, reply(), state()} | {:noreply, state()}
  def handle_call(message, from, state) do
    handle_call_message(message, from, state)
  end

  defp handle_call_message({:get_plugin, plugin_id}, _from, state) do
    result = State.get_plugin(state, plugin_id)
    {:reply, result, state}
  end

  defp handle_call_message({:list_plugins}, _from, state) do
    plugins = State.list_plugins(state)
    {:reply, plugins, state}
  end

  defp handle_call_message({:get_plugin_state, plugin_id}, _from, state) do
    result = State.get_plugin_state(state, plugin_id)
    {:reply, result, state}
  end

  defp handle_call_message({:get_loaded_plugins}, _from, state) do
    plugins = State.get_loaded_plugins(state)
    {:reply, plugins, state}
  end

  defp handle_call_message({:plugin_loaded?, plugin_name}, _from, state) do
    loaded = State.plugin_loaded?(state, plugin_name)
    {:reply, loaded, state}
  end

  defp handle_call_message({:get_plugin_config, plugin_name}, _from, state) do
    result = State.get_plugin_config(state, plugin_name)
    {:reply, result, state}
  end

  defp handle_call_message({:get_commands}, _from, state) do
    commands = State.get_commands(state)
    {:reply, commands, state}
  end

  defp handle_call_message({:get_metadata}, _from, state) do
    metadata = State.get_metadata(state)
    {:reply, metadata, state}
  end

  defp handle_call_message(:initialize, _from, state) do
    case Lifecycle.initialize(state) do
      {:ok, initialized_state} ->
        final_state = setup_file_watching_if_enabled(initialized_state)
        {:reply, :ok, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp handle_call_message({:initialize_with_config, config}, _from, state) do
    updated_state = %{state | plugin_config: config}

    case Lifecycle.initialize(updated_state) do
      {:ok, initialized_state} ->
        final_state = setup_file_watching_if_enabled(initialized_state)
        {:reply, :ok, final_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp handle_call_message(
         {:load_plugin_by_module, module, config},
         _from,
         state
       ) do
    case Lifecycle.load_plugin_by_module(state, module, config) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp handle_call_message({:load_plugin, plugin_id}, _from, state) do
    case Lifecycle.load_plugin(state, plugin_id) do
      {:ok, updated_state} ->
        {:reply, :ok, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp handle_call_message(unhandled, from, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Unhandled call in plugin manager",
      %{module: __MODULE__, message: unhandled, from: from}
    )

    {:reply, {:error, :unhandled_call}, state}
  end

  @doc """
  Handles asynchronous GenServer casts.
  """
  @spec handle_cast(term(), state()) :: {:noreply, state()} | stop()
  def handle_cast(message, state) do
    handle_cast_message(message, state)
  end

  defp handle_cast_message({:enable_plugin, plugin_id}, state) do
    case Lifecycle.enable_plugin(state, plugin_id) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  defp handle_cast_message({:disable_plugin, plugin_id}, state) do
    case Lifecycle.disable_plugin(state, plugin_id) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  defp handle_cast_message({:load_plugin, plugin_id}, state) do
    case Lifecycle.load_plugin(state, plugin_id) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  defp handle_cast_message({:unload_plugin, plugin_id}, state) do
    case Lifecycle.unload_plugin(state, plugin_id) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  defp handle_cast_message({:reload_plugin, plugin_id}, state) do
    case Lifecycle.reload_plugin(state, plugin_id) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  defp handle_cast_message({:reload_plugin_by_id, plugin_id_string}, state) do
    case PluginReloader.reload_plugin(plugin_id_string, state) do
      {:ok, updated_state} -> {:noreply, updated_state}
      {:error, _reason, _error_state} -> {:noreply, state}
    end
  end

  defp handle_cast_message({:set_plugin_state, plugin_id, new_state}, state) do
    {:ok, updated_state} = State.set_plugin_state(state, plugin_id, new_state)
    {:noreply, updated_state}
  end

  defp handle_cast_message({:update_plugin_config, plugin_name, config}, state) do
    {:ok, updated_state} =
      State.update_plugin_config(state, plugin_name, config)

    {:noreply, updated_state}
  end

  defp handle_cast_message(:shutdown, state) do
    {:stop, :normal, state}
  end

  defp handle_cast_message({:plugin_error, _plugin_id, _reason}, state) do
    {:noreply, state}
  end

  defp handle_cast_message(unhandled_message, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Unhandled cast in plugin manager",
      %{module: __MODULE__, message: unhandled_message}
    )

    {:noreply, state}
  end

  @doc """
  Handles GenServer info messages.
  """
  @spec handle_info(term(), state()) :: {:noreply, state()} | stop()
  def handle_info(message, state) do
    handle_info_message(message, state)
  end

  defp handle_info_message({:send_clipboard_result, pid, content}, state) do
    handle_clipboard_result(pid, content, state)
  end

  defp handle_info_message(
         {:reload_plugin_file_debounced, plugin_id, path},
         state
       ) do
    handle_reload_plugin_file(plugin_id, path, state)
  end

  defp handle_info_message({:command_response, command, response}, state) do
    handle_command_response(command, response, state)
  end

  defp handle_info_message(:debounce_file_events, state) do
    handle_debounce_file_events(state)
  end

  defp handle_info_message({:lifecycle_event, :shutdown}, state) do
    handle_lifecycle_shutdown(state)
  end

  defp handle_info_message(:__internal_initialize__, state) do
    handle_internal_initialize(state)
  end

  defp handle_info_message({:fs, _, _}, state) do
    {:noreply, state}
  end

  defp handle_info_message({watcher_pid, true}, state)
       when is_pid(watcher_pid) do
    handle_watcher_ready(watcher_pid, state)
  end

  defp handle_info_message({:file_event, path}, state) do
    handle_file_event(path, state)
  end

  defp handle_info_message(:tick, state) do
    handle_tick(state)
  end

  defp handle_info_message({:plugin_error, _plugin_id, _reason}, state) do
    {:noreply, state}
  end

  defp handle_info_message(unhandled, state) do
    Raxol.Core.Runtime.Log.debug_with_context(
      "Unhandled info message in plugin manager",
      %{module: __MODULE__, message: unhandled}
    )

    {:noreply, state}
  end

  defp handle_clipboard_result(pid, content, state) do
    send(pid, {:clipboard_content, content})
    {:noreply, state}
  end

  defp handle_reload_plugin_file(plugin_id, _path, state) do
    {:ok, updated_state} = PluginReloader.reload_plugin(plugin_id, state)
    {:noreply, updated_state}
  end

  defp handle_command_response(command, response, state) do
    {:ok, updated_state} =
      CommandHandler.handle_response(command, response, state)

    {:noreply, updated_state}
  end

  defp handle_debounce_file_events(state) do
    updated_state = %{state | file_event_timer: nil}
    {:noreply, updated_state}
  end

  defp handle_lifecycle_shutdown(state) do
    state
    |> stop_file_watcher_if_exists()
    |> cancel_tick_timer_if_exists()

    {:stop, :normal, state}
  end

  defp stop_file_watcher_if_exists(%{file_watcher_pid: pid} = state)
       when is_pid(pid) do
    FileWatcher.stop(pid)
    state
  end

  defp stop_file_watcher_if_exists(state), do: state

  defp cancel_tick_timer_if_exists(%{tick_timer: timer} = state)
       when is_reference(timer) do
    Process.cancel_timer(timer)
    state
  end

  defp cancel_tick_timer_if_exists(state), do: state

  defp handle_internal_initialize(state) do
    {:ok, initialized_state} = Lifecycle.initialize(state)
    final_state = setup_file_watching_if_enabled(initialized_state)
    {:noreply, final_state}
  end

  defp handle_watcher_ready(watcher_pid, state) do
    updated_state = %{state | file_watcher_pid: watcher_pid}
    {:noreply, updated_state}
  end

  defp handle_file_event(path, state) do
    case should_process_file_event?(path, state) do
      true ->
        {:ok, plugin_id} = extract_plugin_id_from_path(path)
        schedule_plugin_reload(plugin_id, path, state)

      false ->
        {:noreply, state}
    end
  end

  defp handle_tick(state) do
    updated_state = TimerManager.start_periodic_tick(state)
    {:noreply, updated_state}
  end

  defp setup_file_watching_if_enabled(%{file_watching_enabled?: true} = state) do
    case FileWatcher.start_link(self()) do
      {:ok, watcher_pid} ->
        FileWatcher.subscribe(watcher_pid)
        %{state | file_watcher_pid: watcher_pid}

      _ ->
        state
    end
  end

  defp setup_file_watching_if_enabled(state), do: state

  defp should_process_file_event?(path, state) do
    String.ends_with?(path, ".ex") and
      Map.has_key?(state.plugins, extract_plugin_name(path))
  end

  defp extract_plugin_id_from_path(path) do
    case String.ends_with?(path, ".ex") do
      true -> {:ok, Path.basename(path, ".ex")}
      false -> {:error, :invalid_path}
    end
  end

  defp extract_plugin_name(path) do
    Path.basename(path, ".ex")
  end

  defp schedule_plugin_reload(plugin_id, path, _state) do
    Process.send_after(
      self(),
      {:reload_plugin_file_debounced, plugin_id, path},
      500
    )
  end
end
