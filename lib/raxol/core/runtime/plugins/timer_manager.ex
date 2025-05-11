defmodule Raxol.Core.Runtime.Plugins.TimerManager do
  @moduledoc """
  Implements timer management functionality for plugins.

  This module is responsible for:
  - Managing plugin timers
  - Handling timer scheduling and cancellation
  - Coordinating timer events
  - Managing timer state
  """

  @behaviour Raxol.Core.Runtime.Plugins.TimerManager.Behaviour

  @impl true
  def cancel_existing_timer(state) do
    case state.file_event_timer do
      nil ->
        state

      timer_ref ->
        Process.cancel_timer(timer_ref)
        %{state | file_event_timer: nil}
    end
  end

  @impl true
  def schedule_timer(state, message, timeout) do
    # Cancel any existing timer first
    state = cancel_existing_timer(state)

    # Schedule new timer
    timer_ref = Process.send_after(self(), message, timeout)
    %{state | file_event_timer: timer_ref}
  end

  @impl true
  def handle_timer_message(state, message) do
    # Clear the timer reference
    state = %{state | file_event_timer: nil}

    # Handle the timer message
    case message do
      {:reload_plugin_file_debounced, plugin_id, path} ->
        send(self(), {:reload_plugin_file_debounced, plugin_id, path})
        state

      _ ->
        state
    end
  end

  @impl true
  def get_timer_state(state) do
    %{
      file_event_timer: state.file_event_timer
    }
  end

  @impl true
  def update_timer_state(state, new_state) do
    # Cancel any existing timer
    state = cancel_existing_timer(state)

    # Update with new timer state
    %{state | file_event_timer: new_state.file_event_timer}
  end
end
