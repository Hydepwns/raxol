require Raxol.Core.Events.Event

defmodule Raxol.Core.Runtime.Events.Dispatcher do
  @moduledoc """
  Handles the dispatching of events and commands within a Raxol application.

  Acts as a central hub for:
  * Routing events (system, application)
  * Processing commands returned by application updates
  * Managing PubSub subscriptions and broadcasts using Registry
  """

  use GenServer

  require Logger

  alias Raxol.Core.Runtime.Application
  alias Raxol.Core.Runtime.Command
  alias Raxol.Core.Runtime.Events.Event
  # alias Raxol.Core.Runtime.Plugins.CommandRegistry # Remove unused alias
  alias Raxol.Registry

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
      current_theme_id: :default # Default to :default theme
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
  def init({runtime_pid, %State{} = initial_state}) do
    # Ensure model has a default theme ID if not provided
    initial_model = Map.put_new(initial_state.model, :current_theme_id, :default)
    updated_initial_state = %{initial_state | model: initial_model}
    Logger.info("Dispatcher initialized.")
    {:ok, %{updated_initial_state | runtime_pid: runtime_pid}}
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

    # --- Handle theme change event specifically ---
    message =
      case event do
        # Define a specific event structure for theme changes
        %Event{type: :set_theme, data: %{theme_id: theme_id}} when is_atom(theme_id) ->
          # Let the application update decide, passing the theme_id as the message
          {:set_theme, theme_id}
        _ ->
          # Default event processing
          if function_exported?(app_module, :handle_event, 1) do
            app_module.handle_event(event)
          else
            default_event_to_message(event)
          end
      end

    # --- Call application update ---
    case Raxol.Core.Runtime.Application.update(
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
        # Ensure the theme ID from the model is stored in the Dispatcher state as well
        new_theme_id = Map.get(updated_model, :current_theme_id, state.current_theme_id)
        {:ok, %{state | model: updated_model, current_theme_id: new_theme_id}}
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
        send(state.runtime_pid, :quit_runtime) # Send message to runtime to handle shutdown
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
    case Application.update(state.app_module, msg, state.model) do
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
  def handle_info(message, state) do
    Logger.warning(
      "[#{__MODULE__}] Received unexpected message: #{inspect(message)}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_model, _from, state) do
    {:reply, {:ok, state.model}, state}
  end

  @impl true
  def handle_call(:get_render_context, _from, state) do
    # Return both the model and the current theme ID
    render_context = %{
      model: state.model,
      theme_id: state.current_theme_id # Use the theme ID stored in Dispatcher state
    }
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
