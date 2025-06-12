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
  alias Raxol.Terminal.EventProcessor
  alias Raxol.Terminal.NotificationManager
  alias Raxol.Terminal.MemoryManager
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Processes a terminal event and returns updated state.
  """
  @spec process_event(Event.t(), map()) :: {:ok, map()} | {:error, term()}
  def process_event(%Event{type: type, data: data} = event, state) do
    case state.terminal do
      %EmulatorStruct{} = emulator ->
        {new_emulator, _output} = EventProcessor.process_event(event, emulator)

        # Notify runtime process if present
        if state.runtime_pid do
          send(state.runtime_pid, {:terminal_event_processed, event, new_emulator})
        end

        # Update state with new emulator
        new_state = %{state | terminal: new_emulator}
        updated_state = MemoryManager.check_and_cleanup(new_state)

        # Handle specific event types
        handle_event_type(type, data, updated_state)

      _ ->
        if state.runtime_pid do
          send(state.runtime_pid, {:terminal_error, :no_terminal,
            %{action: :process_event, event: event}})
        end
        {:error, :no_terminal}
    end
  end

  # --- Private Event Type Handlers ---

  defp handle_event_type(:window, data, state) do
    case data do
      %{action: :resize, width: w, height: h} when is_integer(w) and is_integer(h) ->
        NotificationManager.notify_resized(state.runtime_pid, state.callback_module, w, h)
        {:ok, state}

      %{action: :focus, focused: focused?} ->
        NotificationManager.notify_focus_changed(state.runtime_pid, state.callback_module, focused?)
        {:ok, state}

      %{action: :blur} ->
        NotificationManager.notify_focus_changed(state.runtime_pid, state.callback_module, false)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp handle_event_type(:mode, data, state) do
    case data do
      %{mode: new_mode} ->
        NotificationManager.notify_mode_changed(state.runtime_pid, state.callback_module, new_mode)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp handle_event_type(:focus, data, state) do
    case data do
      %{focused: focused?} ->
        NotificationManager.notify_focus_changed(state.runtime_pid, state.callback_module, focused?)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  defp handle_event_type(:clipboard, data, state) do
    case data do
      %{op: op, content: content} ->
        NotificationManager.notify_clipboard_event(state.runtime_pid, state.callback_module, op, content)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

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
