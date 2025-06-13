defmodule Raxol.Terminal.Manager.EventHandler do
  @moduledoc """
  Handles terminal event processing and routing.

  This module is responsible for:
  - Processing terminal events
  - Routing events to appropriate handlers
  - Managing event state transitions
  - Coordinating with notification system
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Core.Events.Event
  alias Raxol.Terminal.NotificationManager
  alias Raxol.Terminal.MemoryManager

  @doc """
  Processes a terminal event and returns updated state.
  """
  @spec process_event(Event.t(), map()) :: {:ok, map()} | {:error, term()}
  def process_event(event, state) do
    case event do
      {:memory_check, _} ->
        new_state = MemoryManager.update_usage(state)
        {:ok, new_state}
      _ ->
        {:ok, state}
    end
  end

  # --- Private Event Type Handlers ---

  defp handle_event_type(:selection, data, state) do
    case data do
      %{start_pos: _, end_pos: _, text: _} = selection ->
        NotificationManager.notify_selection_changed(state.runtime_pid, state.callback_module, selection)
        {:ok, state}

      %{selection: selection} ->
        NotificationManager.notify_selection_changed(state.runtime_pid, state.callback_module, selection)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp handle_event_type(:paste, data, state) do
    case data do
      %{text: text, position: pos} ->
        NotificationManager.notify_paste_event(state.runtime_pid, state.callback_module, text, pos)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp handle_event_type(:cursor, data, state) do
    case data do
      %{visible: _, style: _, blink: _, position: _} = cursor ->
        NotificationManager.notify_cursor_event(state.runtime_pid, state.callback_module, cursor)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp handle_event_type(:scroll, data, state) do
    case data do
      %{direction: dir, delta: delta, position: pos} ->
        NotificationManager.notify_scroll_event(state.runtime_pid, state.callback_module, dir, delta, pos)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp handle_event_type(type, data, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Unknown terminal event type: #{inspect(type)} with data: #{inspect(data)}",
      %{}
    )
    {:ok, state}
  end
end
