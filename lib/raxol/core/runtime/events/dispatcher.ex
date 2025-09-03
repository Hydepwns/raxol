defmodule Raxol.Core.Runtime.Events.Dispatcher do
  @moduledoc """
  Manages the application state (model) and dispatches events to the application's
  `update/2` function. It also handles commands returned by `update/2`.
  """

  use GenServer

  require Raxol.Core.Runtime.Log
  require Raxol.Core.Events.Event
  require Raxol.Core.Runtime.Command
  require Raxol.Core.UserPreferences

  alias Raxol.Core.Runtime.Application
  alias Raxol.Core.Runtime.Command
  alias Raxol.Core.Events.Event
  alias Raxol.Core.UserPreferences
  alias Raxol.Core.ErrorHandling
  
  @registry_name :raxol_event_subscriptions

  defmodule State do
    @moduledoc false
    defstruct runtime_pid: nil,
              app_module: nil,
              model: nil,
              width: 0,
              height: 0,
              focused: true,
              debug_mode: false,
              plugin_manager: nil,
              command_registry_table: nil,
              current_theme_id: :default,
              command_module: Raxol.Core.Runtime.Command
  end

  def start_link(runtime_pid, initial_state, opts \\ []) do
    command_module =
      Keyword.get(opts, :command_module, Raxol.Core.Runtime.Command)

    GenServer.start_link(
      __MODULE__,
      {runtime_pid, initial_state, command_module},
      name: __MODULE__
    )
  end

  @impl GenServer
  def init({runtime_pid, initial_state, command_module}) do
    state = %State{
      runtime_pid: runtime_pid,
      app_module: initial_state.app_module,
      model: initial_state.model,
      width: initial_state.width,
      height: initial_state.height,
      focused: true,
      debug_mode: initial_state.debug_mode,
      plugin_manager: initial_state.plugin_manager,
      command_registry_table: initial_state.command_registry_table,
      current_theme_id: UserPreferences.get_theme_id(),
      command_module: command_module
    }

    send(runtime_pid, {:runtime_initialized, self()})

    send(runtime_pid, {:plugin_manager_ready, initial_state.plugin_manager})

    if Mix.env() == :test do
      send(self(), {:dispatcher_ready, self()})
    end

    {:ok, state}
  end

  @doc """
  Dispatches an event to the appropriate handler based on event type and target.
  """
  def dispatch_event(event, state) do
    case ErrorHandling.safe_call(fn ->
      do_dispatch_event(event, state)
    end) do
      {:ok, result} -> result
      {:error, error} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "Error dispatching event",
          error,
          nil,
          %{module: __MODULE__, event: event, state: state}
        )
        {:error, {:dispatch_error, error}, state}
    end
  end

  @doc """
  Handles an application-level event and updates the application state.
  """
  def handle_event(event, %State{} = state) do
    message = default_event_to_message(event)
    process_app_update(state, message, event)
  end

  defp process_app_update(state, message, event) do
    case Application.delegate_update(state.app_module, message, state.model) do
      {updated_model, commands}
      when is_map(updated_model) and is_list(commands) ->
        process_successful_update(state, updated_model, commands)

      {:error, reason} ->
        log_update_error(state, message, event, reason)

      other ->
        log_unexpected_return(state, message, event, other)
    end
  end

  defp process_successful_update(state, updated_model, commands) do
    context = build_command_context(state)
    process_commands(commands, context, state.command_module)

    updated_state = handle_theme_update(state, updated_model)
    send(state.runtime_pid, :render_needed)
    {:ok, updated_state, commands}
  end

  defp build_command_context(state) do
    %{
      pid: self(),
      command_registry_table: state.command_registry_table,
      runtime_pid: state.runtime_pid
    }
  end

  defp handle_theme_update(state, updated_model) do
    new_theme_id =
      Map.get(updated_model, :current_theme_id, state.current_theme_id)

    if new_theme_id != state.current_theme_id do
      :ok = UserPreferences.set("theme.active_id", new_theme_id)
      %{state | model: updated_model, current_theme_id: new_theme_id}
    else
      %{state | model: updated_model}
    end
  end

  defp log_update_error(state, message, event, reason) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Application update failed",
      reason,
      nil,
      %{
        module: __MODULE__,
        app_module: state.app_module,
        message: message,
        current_model: state.model,
        event: event
      }
    )

    {:error, reason}
  end

  defp log_unexpected_return(state, message, event, other) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Unexpected return from #{state.app_module}.update",
      %{
        module: __MODULE__,
        app_module: state.app_module,
        message: message,
        current_model: state.model,
        event: event,
        other: other
      }
    )

    {:error, {:unexpected_return, other}}
  end

  @doc """
  Processes a system-level event that affects the runtime itself rather than the application logic.
  """
  def process_system_event(event, state) do
    case event do
      %Event{type: :resize, data: data} -> handle_resize_event(data, state)
      %Event{type: :quit} -> {:quit, state}
      %Event{type: :focus, data: data} -> handle_focus_event(data, state)
      %Event{type: :error, data: data} -> handle_error_event(data, state)
      _ -> {:ok, state, []}
    end
  end

  defp handle_resize_event(%{width: width, height: height}, state) do
    {:ok, %{state | width: width, height: height}, []}
  end

  defp handle_focus_event(%{focused: focused}, state) do
    {:ok, %{state | focused: focused}, []}
  end

  defp handle_error_event(%{error: error}, state) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "System error event",
      error,
      nil,
      %{module: __MODULE__, error: error, state: state}
    )

    {:error, error, state}
  end

  # --- Public API for PubSub ---

  @doc "Subscribes the calling process to a specific event topic."
  @spec subscribe(atom()) :: :ok | {:error, term()}
  def subscribe(topic) when is_atom(topic) do
    Registry.register(@registry_name, topic, {})
  end

  @doc "Unsubscribes the calling process from a specific event topic."
  @spec unsubscribe(atom()) :: :ok | {:error, term()}
  def unsubscribe(topic) when is_atom(topic) do
    Registry.unregister(@registry_name, topic)
  end

  @doc "Broadcasts an event payload to all subscribers of a topic."
  @spec broadcast(atom(), map()) :: :ok | {:error, term()}
  def broadcast(topic, payload) when is_atom(topic) and is_map(payload) do
    Raxol.Core.Runtime.Log.debug(
      # {topic}": #{inspect(payload)}"
      "[#{__MODULE__}] Broadcasting on topic "
    )

    # Find subscribers for the topic
    subscribers = Registry.lookup(@registry_name, topic)

    # Send the message to each subscriber
    # Consider async send vs. send for backpressure/ordering needs
    Enum.each(subscribers, fn {pid, _value} ->
      send(pid, {:event, topic, payload})
    end)

    :ok
  end

  # --- GenServer Callbacks ---

  @impl GenServer
  def handle_cast({:dispatch, event}, state) do
    Raxol.Core.Runtime.Log.debug(
      "[Dispatcher] handle_cast :dispatch event: #{inspect(event)}"
    )

    # Delegate to the main event handling logic using do_dispatch_event
    case do_dispatch_event(event, state) do
      {:ok, new_state, _commands} ->
        # Broadcast event globally if successfully handled by app logic
        # Ensure event.type and event.data are appropriate for broadcast
        if is_atom(event.type) and is_map(event.data) do
          Raxol.Core.Runtime.Log.debug(
            "[Dispatcher] Broadcasting event: #{inspect(event.type)} via internal broadcast"
          )

          _ = __MODULE__.broadcast(event.type, event.data)
        else
          Raxol.Core.Runtime.Log.warning(
            "[Dispatcher] Event not broadcast due to invalid type/data: #{inspect(event)}"
          )
        end

        {:noreply, new_state}

      {:quit, new_state} ->
        # Handle quit events by stopping the dispatcher
        {:stop, :normal, new_state}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error_with_stacktrace(
          "[Dispatcher] Error handling event in handle_cast",
          reason,
          nil,
          %{module: __MODULE__, event: event, state: state}
        )

        {:noreply, state}

      other ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "[Dispatcher] Unexpected return from do_dispatch_event in handle_cast",
          %{module: __MODULE__, event: event, state: state, other: other}
        )

        {:noreply, state}
    end
  end

  def handle_cast({:register_dispatcher, _pid}, state) do
    # This message is from Terminal.Driver to register itself.
    # No specific action needed here other than acknowledging it if necessary.
    # Or, if the dispatcher needs to know about the driver's PID, store it.
    Raxol.Core.Runtime.Log.debug(
      "[Dispatcher] Received :register_dispatcher (already registered via init)"
    )

    {:noreply, state}
  end

  def handle_cast({:internal_event, event}, state) do
    # This is for events that are internal to the dispatcher or runtime system.
    Raxol.Core.Runtime.Log.warning_with_context(
      "Dispatcher received unhandled internal_event",
      %{module: __MODULE__, event: event, state: state}
    )

    {:noreply, state}
  end

  # Catch-all for other cast messages
  def handle_cast(msg, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Dispatcher received unhandled cast message",
      %{module: __MODULE__, message: msg, state: state}
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:command_result, msg}, %State{} = state) do
    full_message = {:command_result, msg}
    process_command_result(state, full_message)
  end

  def handle_info(msg, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Dispatcher received unhandled info message",
      %{module: __MODULE__, message: msg, state: state}
    )

    {:noreply, state}
  end

  defp process_command_result(state, message) do
    case Application.delegate_update(state.app_module, message, state.model) do
      {updated_model, commands}
      when is_map(updated_model) and is_list(commands) ->
        process_command_commands(state, updated_model, commands)

      {:error, reason} ->
        log_command_error(state, message, reason)

      other ->
        log_command_unexpected(state, message, other)
    end
  end

  defp process_command_commands(state, updated_model, commands) do
    context = build_command_context(state)

    case ErrorHandling.safe_call(fn ->
      process_commands(commands, context, state.command_module)
    end) do
      {:ok, _} -> :ok
      {:error, error} -> log_command_process_error(error)
    end

    {:noreply, %{state | model: updated_model}}
  end

  defp log_command_error(state, message, reason) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "[Dispatcher] Error calling delegate_update in handle_info",
      reason,
      nil,
      %{module: __MODULE__, msg: message, state: state}
    )

    {:noreply, state}
  end

  defp log_command_unexpected(state, message, other) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[Dispatcher] Unexpected return from delegate_update in handle_info",
      %{module: __MODULE__, msg: message, state: state, other: other}
    )

    {:noreply, state}
  end

  defp log_command_process_error(error) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "[Dispatcher] Error processing commands from command result",
      error,
      nil,
      %{module: __MODULE__}
    )
  end

  @impl GenServer
  def handle_call(:get_model, _from, state) do
    {:reply, {:ok, state.model}, state}
  end

  @impl GenServer
  def handle_call(:get_render_context, _from, state) do
    Raxol.Core.Runtime.Log.debug(
      "Dispatcher received :get_render_context call. State: #{inspect(state)}"
    )

    render_context = %{
      model: state.model,
      theme_id: state.current_theme_id
    }

    Raxol.Core.Runtime.Log.debug(
      "Dispatcher returning render context: #{inspect(render_context)}"
    )

    {:reply, {:ok, render_context}, state}
  end

  @impl GenServer
  def terminate(reason, _state) do
    Raxol.Core.Runtime.Log.info(
      "Event Dispatcher terminating. Reason: #{inspect(reason)}"
    )

    :ok
  end

  defp do_dispatch_event(event, state) do
    if state.debug_mode do
      Raxol.Core.Runtime.Log.debug("Dispatching event: #{inspect(event)}")
    end

    if system_event?(event) do
      process_system_event(event, state)
    else
      filtered_event = apply_plugin_filters(event, state)

      if is_nil(filtered_event) do
        {:ok, state}
      else
        handle_event(filtered_event, state)
      end
    end
  end

  defp system_event?(%Event{type: type}) do
    type in [:resize, :quit, :focus, :error, :system]
  end

  defp system_event?(_), do: false

  defp apply_plugin_filters(event, state) do
    manager_pid = state.plugin_manager

    case GenServer.call(manager_pid, {:filter_event, event}) do
      {:ok, filtered_event} -> filtered_event
      :halt -> nil
      {:error, _reason} -> nil
      _ -> event
    end
  end

  defp default_event_to_message(%Event{
         type: :key,
         data: %{key: key, modifiers: mods}
       }) do
    {:key_press, key, mods}
  end

  defp default_event_to_message(%Event{
         type: :mouse,
         data: %{action: action, x: x, y: y, button: button}
       }) do
    {:mouse_event, action, x, y, button}
  end

  defp default_event_to_message(%Event{type: :text, data: %{text: text}}) do
    {:text_input, text}
  end

  defp default_event_to_message(event) do
    {:event, event}
  end

  # --- Command Processing ---

  defp process_commands(commands, context, command_module)
       when is_list(commands) do
    Raxol.Core.Runtime.Log.debug(
      "[Dispatcher.process_commands] Processing commands: #{inspect(commands)} with context: #{inspect(context)}"
    )

    Enum.each(commands, fn command ->
      case command do
        %Command{} = cmd ->
          command_module.execute(cmd, context)

        _ ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "[#{__MODULE__}] Invalid command format: #{inspect(command)}. Expected %Raxol.Core.Runtime.Command{}. Ignoring.",
            %{command: command}
          )
      end
    end)
  end
end
