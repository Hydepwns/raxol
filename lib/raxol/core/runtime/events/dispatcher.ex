defmodule Raxol.Core.Runtime.Events.Dispatcher do
  @moduledoc """
  Manages the application state (model) and dispatches events to the application's
  `update/2` function. It also handles commands returned by `update/2`.
  """

  use GenServer
  @behaviour Raxol.Core.Runtime.Events.Dispatcher.Behaviour

  require Logger
  require Raxol.Core.Events.Event
  require Raxol.Core.Runtime.Command
  require Raxol.Core.UserPreferences

  alias Raxol.Core.Runtime.Application
  alias Raxol.Core.Runtime.Command
  alias Raxol.Core.Events.Event
  alias Raxol.Core.UserPreferences

  # Define the Registry name
  @registry_name :raxol_event_subscriptions

  # Internal state
  defmodule State do
    @moduledoc false
    defstruct [
      # PID of the main Runtime process
      runtime_pid: nil,
      app_module: nil,
      model: nil,
      width: 0,
      height: 0,
      focused: true,
      debug_mode: false,
      # Reference or PID?
      plugin_manager: nil,
      # ETS table name
      command_registry_table: nil,
      # Add current theme ID
      # Fetched from UserPreferences on init
      # Will be overwritten in init
      current_theme_id: :default
    ]
  end

  # --- Public API ---

  @impl true
  def start_link(runtime_pid, initial_state) do
    GenServer.start_link(__MODULE__, {runtime_pid, initial_state},
      name: __MODULE__
    )
  end

  @impl true
  def init({runtime_pid, initial_state_map}) do
    Logger.info("Dispatcher initializing...")

    # Ensure necessary modules are loaded to prevent runtime errors with function_exported?
    # Elixir's Application module
    true = Code.ensure_loaded?(Application)
    true = Code.ensure_loaded?(initial_state_map.app_module)

    # Call the application's init function
    # Determine arity and call appropriately
    # Expect {:ok, model, commands}
    {:ok, app_model, app_commands} =
      cond do
        function_exported?(initial_state_map.app_module, :init, 1) ->
          # Pass full map for context
          initial_state_map.app_module.init(initial_state_map)

        function_exported?(initial_state_map.app_module, :init, 2) ->
          # Legacy or specific arity
          initial_state_map.app_module.init(
            initial_state_map,
            initial_state_map.model
          )

        true ->
          Logger.error(
            "Application module #{inspect(initial_state_map.app_module)} does not implement init/1 or init/2."
          )

          # TODO: Return proper error to supervisor
          raise "Application module #{initial_state_map.app_module} does not implement init/1 or init/2."
      end

    # Merge UserPreferences into the model (Theme specific)
    # UserPreferences name
    user_prefs_pid = Process.whereis(UserPreferences)

    current_theme_id_string =
      if user_prefs_pid do
        # Get the theme NAME directly using the correct key
        UserPreferences.get(:theme, user_prefs_pid) || "Default Theme"
      else
        Logger.warning(
          "UserPreferences PID not found during Dispatcher init. Using default theme."
        )

        # Fallback default theme ID
        "Default Theme"
      end

    Logger.debug(
      "Dispatcher init: Loaded initial theme ID: \"#{current_theme_id_string}\""
    )

    model_with_theme =
      Map.put(app_model, :current_theme_id, current_theme_id_string)

    state = %State{
      runtime_pid: runtime_pid,
      app_module: initial_state_map.app_module,
      # Use the model returned by app's init, with theme
      model: model_with_theme,
      width: initial_state_map.width,
      height: initial_state_map.height,
      # Default focus state
      focused: true,
      debug_mode: initial_state_map.debug_mode || false,
      # This is an atom (registered name)
      plugin_manager: initial_state_map.plugin_manager,
      # This is an atom
      command_registry_table: initial_state_map.command_registry_table,
      # Store the theme ID string
      current_theme_id: current_theme_id_string
    }

    Logger.debug(
      "Dispatcher init: Processing initial commands: #{inspect(app_commands)}"
    )

    # Process any initial commands returned by the application's init
    # These are processed after the main state is set up.
    if Enum.any?(app_commands) do
      # self() is the Dispatcher's own PID
      # Using cast to avoid blocking init
      GenServer.cast(self(), {:process_commands, app_commands})
    end

    Logger.info("Dispatcher init complete.")
    {:ok, state}
  end

  @doc """
  Dispatches an event to the appropriate handler based on event type and target.

  Returns `{:ok, updated_state}` if the event was successfully handled,
  or `{:error, reason, state}` if something went wrong.
  """
  def dispatch_event(event, state) do
    try do
      do_dispatch_event(event, state)
    rescue
      error ->
        Logger.error("Error dispatching event: #{inspect(error)}")
        {:error, {:dispatch_error, error}, state}
    end
  end

  @doc """
  Handles an application-level event and updates the application state.

  This is typically used for user interaction events like keyboard or mouse input.
  """
  def handle_event(event, %State{} = state) do
    app_module = state.app_module
    current_model = state.model
    current_theme_id = state.current_theme_id

    # Convert event to message for app update
    message = default_event_to_message(event)

    # Delegate event processing to the application module
    case Application.delegate_update(
           app_module,
           message,
           current_model
         ) do
      {updated_model, commands} ->
        # Execute commands using the Command module
        context = %{
          pid: self(),
          command_registry_table: state.command_registry_table,
          runtime_pid: state.runtime_pid
        }

        process_commands(commands, context)

        # Check if theme ID changed in the model
        new_theme_id =
          Map.get(updated_model, :current_theme_id, current_theme_id)

        updated_state =
          if new_theme_id != current_theme_id do
            Logger.debug(
              "Theme changed in model: #{current_theme_id} -> #{new_theme_id}. Updating preferences."
            )

            # Save the new theme preference
            # Use :meck passthrough for this in tests if needed
            :ok = UserPreferences.set("theme.active_id", new_theme_id)
            %{state | model: updated_model, current_theme_id: new_theme_id}
          else
            %{state | model: updated_model}
          end

        # Inform RenderingEngine about the state change
        Logger.debug("State changed, sending :render_needed to Runtime")
        send(state.runtime_pid, :render_needed)

        # Return tuple indicating success, the new state, and commands
        {:ok, updated_state, commands}

      {:error, reason} ->
        # Application update failed
        Logger.error("Application update failed: #{inspect(reason)}")
        # Return tuple indicating handled error
        {:error, reason}

      other ->
        Logger.warning(
          "Unexpected return from #{app_module}.update: #{inspect(other)}"
        )

        # Return tuple indicating handled error
        {:error, {:unexpected_return, other}}
    end
  end

  @doc """
  Processes a system-level event that affects the runtime itself rather than
  the application logic.

  Examples include terminal resize events, focus events, or quit requests.
  """
  def process_system_event(event, state) do
    case event do
      %Event{type: :resize, data: %{width: width, height: height}} ->
        # Handle terminal resize event
        {:ok, %{state | width: width, height: height}}

      %Event{type: :quit} ->
        # Handle quit request
        {:quit, state}

      %Event{type: :focus, data: %{focused: focused}} ->
        # Handle focus change
        {:ok, %{state | focused: focused}}

      %Event{type: :error, data: %{error: error}} ->
        # Handle error events
        Logger.error("System error event: #{inspect(error)}")
        {:error, error, state}

      _ ->
        # Unknown system event, just pass through
        {:ok, state}
    end
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
    Logger.debug(
      "[#{__MODULE__}] Broadcasting on topic '#{topic}': #{inspect(payload)}"
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

  @impl true
  def handle_cast({:dispatch, event}, state) do
    Logger.debug("[Dispatcher] handle_cast :dispatch event: #{inspect(event)}")

    # Delegate to the main event handling logic
    case handle_event(event, state) do
      {:ok, new_state, _commands} ->
        # Broadcast event globally if successfully handled by app logic
        # Ensure event.type and event.data are appropriate for broadcast
        if is_atom(event.type) and is_map(event.data) do
          Logger.debug(
            "[Dispatcher] Broadcasting event: #{inspect(event.type)} via internal broadcast"
          )

          _ = __MODULE__.broadcast(event.type, event.data)
        else
          Logger.warning(
            "[Dispatcher] Event not broadcast due to invalid type/data: #{inspect(event)}"
          )
        end

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error(
          "[Dispatcher] Error handling event in handle_cast: #{inspect(reason)}"
        )

        # Or handle error more gracefully
        {:noreply, state}

      other ->
        Logger.warning(
          "[Dispatcher] Unexpected return from handle_event in handle_cast: #{inspect(other)}"
        )

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:register_dispatcher, _pid}, state) do
    # This message is from Terminal.Driver to register itself.
    # No specific action needed here other than acknowledging it if necessary.
    # Or, if the dispatcher needs to know about the driver's PID, store it.
    Logger.debug(
      "[Dispatcher] Received :register_dispatcher (already registered via init)"
    )

    {:noreply, state}
  end

  # Catch-all for other cast messages
  @impl true
  def handle_cast(unhandled_message, state) do
    Logger.warning(
      "[Dispatcher] Unhandled cast message: #{inspect(unhandled_message)}"
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:command_result, msg}, %State{} = state) do
    # A command executed via Command.execute (e.g., a Task or Delay) has finished
    # We need to feed this message back into the application's update loop
    # Construct the full message tuple
    full_message = {:command_result, msg}

    Logger.debug(
      "[#{__MODULE__}] Received command result, forwarding to app: #{inspect(full_message)}"
    )

    # Call Application.update with the received message
    case Application.delegate_update(
           state.app_module,
           full_message,
           state.model
         ) do
      {updated_model, commands} ->
        # Execute any new commands generated by the update
        context = %{
          pid: self(),
          command_registry_table: state.command_registry_table,
          runtime_pid: state.runtime_pid
        }

        # Wrap process_commands to prevent crashes here from losing state update
        try do
          process_commands(commands, context)
        rescue
          error ->
            Logger.error(
              "[Dispatcher] Error processing commands from command result: #{inspect(error)}\\nStacktrace: #{inspect(__STACKTRACE__)}"
            )

            # Decide if we should still update the model or not. Usually yes.
        end

        {:noreply, %{state | model: updated_model}}

      # Handle cases where delegate_update itself might fail
      {:error, reason} ->
        Logger.error(
          "[Dispatcher] Error calling delegate_update in handle_info: #{inspect(reason)}"
        )

        # Keep old state
        {:noreply, state}

      other ->
        Logger.warning(
          "[Dispatcher] Unexpected return from delegate_update in handle_info: #{inspect(other)}"
        )

        # Keep old state
        {:noreply, state}
    end
  end

  # Catch-all for other messages
  @impl GenServer
  def handle_info(msg, state) do
    Logger.warning("Dispatcher received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_model, _from, state) do
    {:reply, {:ok, state.model}, state}
  end

  @impl true
  def handle_call(:get_render_context, _from, state) do
    Logger.debug(
      "Dispatcher received :get_render_context call. State: #{inspect(state)}"
    )

    render_context = %{
      model: state.model,
      theme_id: state.current_theme_id
    }

    Logger.debug(
      "Dispatcher returning render context: #{inspect(render_context)}"
    )

    {:reply, {:ok, render_context}, state}
  end

  @impl GenServer
  def terminate(reason, _state) do
    Logger.info("Event Dispatcher terminating. Reason: #{inspect(reason)}")
    # The linked Registry process (named @registry_name) should be automatically
    # terminated by OTP when this Dispatcher process exits, due to the link
    # established in init/1. No explicit stop is needed here for the registry.
    :ok
  end

  # Private functions

  defp do_dispatch_event(event, state) do
    # Log the event if in debug mode
    if state.debug_mode do
      Logger.debug("Dispatching event: #{inspect(event)}")
    end

    # Determine if this is a system event or application event
    if system_event?(event) do
      process_system_event(event, state)
    else
      # Process plugin event filters if any
      filtered_event = apply_plugin_filters(event, state)

      # Skip completely filtered events
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
    # Allow plugins to filter/modify the event before processing
    # TODO: Ensure state.plugin_manager is correctly passed/set
    # Assuming named process if nil
    manager_pid = state.plugin_manager || Raxol.Core.Runtime.Plugins.Manager
    # Assuming Manager implements handle_call for :filter_event
    case GenServer.call(manager_pid, {:filter_event, event}) do
      {:ok, filtered_event} -> filtered_event
      # Event processing halted by a plugin
      :halt -> nil
      # No filtering applied
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
    # For other events, just pass through the whole event
    {:event, event}
  end

  # --- Command Processing ---

  defp process_commands(commands, context) when is_list(commands) do
    Logger.debug(
      "[Dispatcher.process_commands] Processing commands: #{inspect(commands)} with context: #{inspect(context)}"
    )

    Enum.each(commands, fn command ->
      # Use the Command module's execution logic
      # Add error handling around execute if needed
      # Note: Command.execute handles different command types (:task, :batch, :broadcast, etc.)
      # It needs context, including the PID to send results back to.
      case command do
        %Command{} = cmd ->
          Command.execute(cmd, context)

        _ ->
          Logger.warning(
            "[#{__MODULE__}] Invalid command format: #{inspect(command)}. Expected %Raxol.Core.Runtime.Command{}. Ignoring."
          )
      end
    end)
  end
end
