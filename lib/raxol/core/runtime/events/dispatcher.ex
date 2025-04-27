defmodule Raxol.Core.Runtime.Events.Dispatcher do
  @moduledoc """
  Manages the application state (model) and dispatches events to the application's
  `update/2` function. It also handles commands returned by `update/2`.
  """

  use GenServer

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
      current_theme_id: :default # Will be overwritten in init
    ]
  end

  # --- Public API ---

  def start_link(runtime_pid, initial_state) do
    # Start the Registry for subscriptions
    {:ok, _pid} = Registry.start_link(keys: :duplicate, name: @registry_name)
    Logger.info("Event Dispatcher starting...")

    GenServer.start_link(__MODULE__, {runtime_pid, initial_state},
      name: __MODULE__
    )
  end

  @impl true
  def init({runtime_pid, initial_state_map}) do
    # Start the Registry for subscriptions
    {:ok, _pid} = Registry.start_link(keys: :duplicate, name: @registry_name)
    Logger.info("Event Dispatcher starting...")

    # Load initial theme from preferences
    initial_theme_id = UserPreferences.get("theme.active_id") || :default
    Logger.debug("Dispatcher init: Loaded initial theme ID: #{inspect(initial_theme_id)}")

    # Ensure model has the loaded theme ID if not provided explicitly
    initial_model =
      Map.put_new(initial_state_map.model, :current_theme_id, initial_theme_id)

    # Extract initial commands
    initial_commands = initial_state_map.initial_commands

    # Build the final initial state struct
    initial_state = %State{
      runtime_pid: runtime_pid,
      app_module: initial_state_map.app_module,
      model: initial_model,
      width: initial_state_map.width,
      height: initial_state_map.height,
      plugin_manager: initial_state_map.plugin_manager,
      command_registry_table: initial_state_map.command_registry_table,
      current_theme_id: initial_theme_id # Set from preferences
      # Add other fields from initial_state_map if needed, setting defaults
    }

    Logger.info("Dispatcher initialized with theme: #{inspect(initial_state.current_theme_id)}")

    # Process initial commands after state is set up
    context = %{
      pid: self(),
      command_registry_table: initial_state.command_registry_table,
      runtime_pid: initial_state.runtime_pid
    }

    process_commands(initial_commands, context)

    {:ok, initial_state}
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

    # Call application update
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
            Logger.debug("Theme changed in model: #{current_theme_id} -> #{new_theme_id}. Updating preferences.")
            # Save the new theme preference
            :ok = UserPreferences.set("theme.active_id", new_theme_id)
            %{state | model: updated_model, current_theme_id: new_theme_id}
          else
            %{state | model: updated_model}
          end

        {:ok, updated_state}

      # Handle other potential return values from delegate_update if necessary
      # e.g., {:error, reason}
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
  def handle_cast({:dispatch, event}, %State{} = state) do
    # Dispatch event internally
    case do_dispatch_event(event, state) do
      {:ok, updated_state} ->
        # Check if state actually changed before rendering?
        if updated_state != state do
          # Signal Runtime to render
          Logger.debug("State changed, sending :render_needed to Runtime")
          send(state.runtime_pid, :render_needed)
          {:noreply, updated_state}
        else
          # No change, no render
          {:noreply, state}
        end

      {:quit, final_state} ->
        # TODO: How to signal Runtime to quit?
        Logger.info("Quit requested via event dispatch.")
        # Send message to runtime to handle shutdown
        send(state.runtime_pid, :quit_runtime)
        {:noreply, final_state}

      {:error, _reason, final_state} ->
        # Error already logged by do_dispatch_event
        {:noreply, final_state}
    end
  end

  @impl GenServer
  def handle_info({:command_result, msg}, %State{} = state) do
    # A command executed via Command.execute (e.g., a Task or Delay) has finished
    # We need to feed this message back into the application's update loop
    Logger.debug("[#{__MODULE__}] Received command result: #{inspect(msg)}")

    # Call Application.update with the received message
    case Application.delegate_update(state.app_module, msg, state.model) do
      {updated_model, commands} ->
        # Execute any new commands generated by the update
        context = %{
          pid: self(),
          command_registry_table: state.command_registry_table,
          runtime_pid: state.runtime_pid
        }

        process_commands(commands, context)
        {:noreply, %{state | model: updated_model}}
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
    render_context = %{model: state.model, theme_id: state.current_theme_id}
    {:reply, {:ok, render_context}, state}
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
