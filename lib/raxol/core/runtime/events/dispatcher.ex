defmodule Raxol.Core.Runtime.Events.Dispatcher do
  @moduledoc """
  Handles the dispatching of events to the appropriate handlers within a Raxol application.

  This module is responsible for:
  * Routing events to the correct application handlers
  * Processing system-level events
  * Maintaining the event flow through the system
  """

  use GenServer

  require Logger

  alias Raxol.Core.Events.Event

  @impl true
  def init(init_arg) do
    Logger.info("Dispatcher initializing...")
    {:ok, init_arg}
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
  def handle_event(event, state) do
    # Extract the application module and current model
    app_module = state.app_module
    current_model = state.model

    # Convert the event to an application message if the app defines a handle_event callback
    message =
      if function_exported?(app_module, :handle_event, 1) do
        app_module.handle_event(event)
      else
        # Default conversion for common events
        default_event_to_message(event)
      end

    # Update the application state with the new message
    case Raxol.Core.Runtime.Application.update(app_module, message, current_model) do
      {updated_model, commands} ->
        # Process any commands returned by the update function
        {:ok, %{state | model: updated_model, commands: commands}}

      {:error, reason} ->
        {:error, reason, state}
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

  @doc "Placeholder for subscribing to event topics."
  @spec subscribe(atom(), {module(), atom()}) :: :ok | {:error, term()}
  def subscribe(topic, subscriber) do
    Logger.debug("[#{__MODULE__}] subscribe called for topic '#{topic}': #{inspect(subscriber)}")
    # TODO: Implement subscription management (e.g., using Registry or ETS)
    :ok
  end

  @doc "Placeholder for broadcasting events to subscribers."
  @spec broadcast(atom(), map()) :: :ok | {:error, term()}
  def broadcast(topic, payload) do
    Logger.debug("[#{__MODULE__}] broadcast called for topic '#{topic}': #{inspect(payload)}")
    # TODO: Implement broadcast logic to notify subscribers
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
    case Raxol.Core.Runtime.Plugins.Manager.filter_event(state.plugin_manager, event) do
      {:ok, filtered_event} -> filtered_event
      :halt -> nil # Event processing halted by a plugin
      _ -> event # No filtering applied
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
end
