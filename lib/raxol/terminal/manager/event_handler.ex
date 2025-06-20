defmodule Raxol.Terminal.Manager.EventHandler do
  @moduledoc """
  Handles terminal events and dispatches them to appropriate handlers.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.NotificationManager

  @doc """
  Handles a terminal event.
  """
  def handle_event(emulator, {:key_press, key, modifiers}) do
    handle_key_press(emulator, key, modifiers)
  end

  def handle_event(emulator, {:key_release, key, modifiers}) do
    handle_key_release(emulator, key, modifiers)
  end

  def handle_event(emulator, {:mouse_click, button, x, y}) do
    handle_mouse_click(emulator, button, x, y)
  end

  def handle_event(emulator, {:mouse_drag, button, x, y}) do
    handle_mouse_drag(emulator, button, x, y)
  end

  def handle_event(emulator, {:mouse_release, button, x, y}) do
    handle_mouse_release(emulator, button, x, y)
  end

  def handle_event(emulator, {:focus_gain}) do
    handle_focus_gain(emulator)
  end

  def handle_event(emulator, {:focus_loss}) do
    handle_focus_loss(emulator)
  end

  def handle_event(_emulator, _event) do
    {:error, :unknown_event}
  end

  @doc """
  Processes a terminal event and sends appropriate notifications.
  """
  def process_event(event, state) do
    if is_nil(state.terminal) do
      {:error, :no_terminal}
    else
      process_event_by_type(event, state)
    end
  end

  defp process_event_by_type(%{type: :window} = event, state) do
    process_window_event(event, state)
  end

  defp process_event_by_type(%{type: :mode} = event, state) do
    process_mode_event(event, state)
  end

  defp process_event_by_type(%{type: :focus} = event, state) do
    process_focus_event(event, state)
  end

  defp process_event_by_type(%{type: :clipboard} = event, state) do
    process_clipboard_event(event, state)
  end

  defp process_event_by_type(%{type: :selection} = event, state) do
    process_selection_event(event, state)
  end

  defp process_event_by_type(%{type: :paste} = event, state) do
    process_paste_event(event, state)
  end

  defp process_event_by_type(%{type: :cursor} = event, state) do
    process_cursor_event(event, state)
  end

  defp process_event_by_type(%{type: :scroll} = event, state) do
    process_scroll_event(event, state)
  end

  defp process_event_by_type(_event, _state) do
    {:error, :unknown_event_type}
  end

  # Private helper functions

  defp handle_key_press(emulator, key, modifiers) do
    {:ok, updated_emulator, _commands} =
      Emulator.Input.process_key_press(emulator, key, modifiers)

    {:ok, updated_emulator}
  end

  defp handle_key_release(emulator, key, modifiers) do
    {:ok, updated_emulator, _commands} =
      Emulator.Input.process_key_release(emulator, key, modifiers)

    {:ok, updated_emulator}
  end

  defp handle_mouse_click(emulator, button, x, y) do
    {:ok, updated_emulator, _commands} =
      Emulator.Input.process_mouse_event(emulator, %{
        type: :mouse_click,
        button: button,
        x: x,
        y: y
      })

    {:ok, updated_emulator}
  end

  defp handle_mouse_drag(emulator, button, x, y) do
    {:ok, updated_emulator, _commands} =
      Emulator.Input.process_mouse_event(emulator, %{
        type: :mouse_drag,
        button: button,
        x: x,
        y: y
      })

    {:ok, updated_emulator}
  end

  defp handle_mouse_release(emulator, button, x, y) do
    {:ok, updated_emulator, _commands} =
      Emulator.Input.process_mouse_event(emulator, %{
        type: :mouse_release,
        button: button,
        x: x,
        y: y
      })

    {:ok, updated_emulator}
  end

  defp handle_focus_gain(emulator) do
    {:ok, emulator}
  end

  defp handle_focus_loss(emulator) do
    {:ok, emulator}
  end

  # Event processing functions

  defp process_window_event(event, state) do
    case event.data do
      %{action: :resize, width: width, height: height} ->
        NotificationManager.notify_resized(state.runtime_pid, state.callback_module, width, height)
        {:ok, state}

      %{action: :focus, focused: focused} ->
        NotificationManager.notify_focus_changed(state.runtime_pid, state.callback_module, focused)
        {:ok, state}

      %{action: :blur} ->
        NotificationManager.notify_focus_changed(state.runtime_pid, state.callback_module, false)
        {:ok, state}

      _ ->
        {:error, :unknown_window_action}
    end
  end

  defp process_mode_event(event, state) do
    case event.data do
      %{mode: mode} ->
        NotificationManager.notify_mode_changed(state.runtime_pid, state.callback_module, mode)
        {:ok, state}

      _ ->
        {:error, :invalid_mode_data}
    end
  end

  defp process_focus_event(event, state) do
    case event.data do
      %{focused: focused} ->
        NotificationManager.notify_focus_changed(state.runtime_pid, state.callback_module, focused)
        {:ok, state}

      _ ->
        {:error, :invalid_focus_data}
    end
  end

  defp process_clipboard_event(event, state) do
    case event.data do
      %{op: op, content: content} ->
        NotificationManager.notify_clipboard_event(state.runtime_pid, state.callback_module, op, content)
        {:ok, state}

      _ ->
        {:error, :invalid_clipboard_data}
    end
  end

  defp process_selection_event(event, state) do
    case event.data do
      %{start_pos: start_pos, end_pos: end_pos, text: text} ->
        selection = %{start_pos: start_pos, end_pos: end_pos, text: text}
        NotificationManager.notify_selection_changed(state.runtime_pid, state.callback_module, selection)
        {:ok, state}

      _ ->
        {:error, :invalid_selection_data}
    end
  end

  defp process_paste_event(event, state) do
    case event.data do
      %{text: text, position: position} ->
        NotificationManager.notify_paste_event(state.runtime_pid, state.callback_module, text, position)
        {:ok, state}

      _ ->
        {:error, :invalid_paste_data}
    end
  end

  defp process_cursor_event(event, state) do
    case event.data do
      %{visible: visible, style: style, blink: blink, position: position} ->
        cursor = %{visible: visible, style: style, blink: blink, position: position}
        NotificationManager.notify_cursor_event(state.runtime_pid, state.callback_module, cursor)
        {:ok, state}

      _ ->
        {:error, :invalid_cursor_data}
    end
  end

  defp process_scroll_event(event, state) do
    case event.data do
      %{direction: direction, delta: delta, position: position} ->
        NotificationManager.notify_scroll_event(state.runtime_pid, state.callback_module, direction, delta, position)
        {:ok, state}

      _ ->
        {:error, :invalid_scroll_data}
    end
  end
end
