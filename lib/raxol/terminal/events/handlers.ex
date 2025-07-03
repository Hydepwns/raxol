defmodule Raxol.Terminal.Events.Handlers do
  @moduledoc """
  Handles terminal events and dispatches them to appropriate handlers.
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.ANSI.WindowManipulation

  @doc """
  Handles window-related events.
  """
  def handle_window_event(emulator_state, event) do
    case event do
      {:resize, w, h} ->
        handle_resize(emulator_state, w, h)

      {:title, title} ->
        handle_title_change(emulator_state, title)

      {:icon_name, name} ->
        handle_icon_name_change(emulator_state, name)

      _ ->
        {:error, "Unknown window event: #{inspect(event)}"}
    end
  end

  @doc """
  Handles mode change events.
  """
  def handle_mode_event(emulator_state, event) do
    case event do
      {:change, new_mode} ->
        handle_mode_change(emulator_state, new_mode)

      _ ->
        {:error, "Unknown mode event: #{inspect(event)}"}
    end
  end

  @doc """
  Handles mouse events.
  """
  def handle_mouse_event(emulator_state, event) do
    case event do
      {:click, button, x, y} ->
        handle_mouse_click(emulator_state, button, x, y)

      {:drag, button, x, y} ->
        handle_mouse_drag(emulator_state, button, x, y)

      {:release, button, x, y} ->
        handle_mouse_release(emulator_state, button, x, y)

      _ ->
        {:error, "Unknown mouse event: #{inspect(event)}"}
    end
  end

  @doc """
  Handles keyboard events.
  """
  def handle_keyboard_event(emulator_state, event) do
    case event do
      {:press, key} ->
        handle_key_press(emulator_state, key)

      {:release, key} ->
        handle_key_release(emulator_state, key)

      _ ->
        {:error, "Unknown keyboard event: #{inspect(event)}"}
    end
  end

  @doc """
  Handles focus events.
  """
  def handle_focus_event(emulator_state, event) do
    case event do
      {:gain} ->
        handle_focus_gain(emulator_state)

      {:loss} ->
        handle_focus_loss(emulator_state)

      _ ->
        {:error, "Unknown focus event: #{inspect(event)}"}
    end
  end

  @doc """
  Generic event handler that dispatches to appropriate handlers.
  """
  def handle_event(emulator_state, event) do
    case event do
      {:window, window_event} ->
        handle_window_event(emulator_state, window_event)

      {:mode, mode_event} ->
        handle_mode_event(emulator_state, mode_event)

      {:mouse, mouse_event} ->
        handle_mouse_event(emulator_state, mouse_event)

      {:keyboard, keyboard_event} ->
        handle_keyboard_event(emulator_state, keyboard_event)

      {:focus, focus_event} ->
        handle_focus_event(emulator_state, focus_event)

      _ ->
        {:error, "Unknown event type: #{inspect(event)}"}
    end
  end

  # Private helper functions

  defp handle_resize(emulator_state, w, h) do
    # Update terminal dimensions
    updated_state = %{emulator_state | width: w, height: h}

    # Clear screen and reset cursor position
    commands = [
      WindowManipulation.clear_screen(),
      WindowManipulation.move_cursor(1, 1)
    ]

    {:ok, updated_state, commands}
  end

  defp handle_title_change(emulator_state, title) do
    # Update window title
    updated_state = %{emulator_state | title: title}

    # Send title change command
    commands = [WindowManipulation.set_title(title)]

    {:ok, updated_state, commands}
  end

  defp handle_icon_name_change(emulator_state, name) do
    # Update icon name
    updated_state = %{emulator_state | icon_name: name}

    # Send icon name change command
    commands = [WindowManipulation.set_icon_name(name)]

    {:ok, updated_state, commands}
  end

  defp handle_mode_change(emulator_state, new_mode) do
    # Update terminal mode
    updated_state = %{emulator_state | mode: new_mode}

    # Send mode change command
    commands = [WindowManipulation.set_mode(new_mode)]

    {:ok, updated_state, commands}
  end

  defp handle_mouse_click(emulator_state, button, x, y) do
    # Handle mouse click
    commands = [WindowManipulation.mouse_click(button, x, y)]

    {:ok, emulator_state, commands}
  end

  defp handle_mouse_drag(emulator_state, button, x, y) do
    # Handle mouse drag
    commands = [WindowManipulation.mouse_drag(button, x, y)]

    {:ok, emulator_state, commands}
  end

  defp handle_mouse_release(emulator_state, button, x, y) do
    # Handle mouse release
    commands = [WindowManipulation.mouse_release(button, x, y)]

    {:ok, emulator_state, commands}
  end

  defp handle_key_press(emulator_state, key) do
    # Handle key press
    commands = [WindowManipulation.key_press(key)]

    {:ok, emulator_state, commands}
  end

  defp handle_key_release(emulator_state, key) do
    # Handle key release
    commands = [WindowManipulation.key_release(key)]

    {:ok, emulator_state, commands}
  end

  defp handle_focus_gain(emulator_state) do
    # Handle focus gain
    commands = [WindowManipulation.focus_gain()]

    {:ok, emulator_state, commands}
  end

  defp handle_focus_loss(emulator_state) do
    # Handle focus loss
    commands = [WindowManipulation.focus_loss()]

    {:ok, emulator_state, commands}
  end

  # === Additional Event Handlers ===

  @doc """
  Handles selection events.
  """
  @spec handle_selection_event(any(), any()) :: {:ok, any()} | {:error, any()}
  def handle_selection_event(emulator_state, _event) do
    # TODO: Implement selection event handling
    {:ok, emulator_state}
  end

  @doc """
  Handles scroll events.
  """
  @spec handle_scroll_event(any(), any()) :: {:ok, any()} | {:error, any()}
  def handle_scroll_event(emulator_state, _event) do
    # TODO: Implement scroll event handling
    {:ok, emulator_state}
  end

  @doc """
  Handles paste events.
  """
  @spec handle_paste_event(any(), any()) :: {:ok, any()} | {:error, any()}
  def handle_paste_event(emulator_state, _event) do
    # TODO: Implement paste event handling
    {:ok, emulator_state}
  end

  @doc """
  Handles cursor events.
  """
  @spec handle_cursor_event(any(), any()) :: {:ok, any()} | {:error, any()}
  def handle_cursor_event(emulator_state, _event) do
    # TODO: Implement cursor event handling
    {:ok, emulator_state}
  end

  @doc """
  Handles clipboard events.
  """
  @spec handle_clipboard_event(any(), any()) :: {:ok, any()} | {:error, any()}
  def handle_clipboard_event(emulator_state, _event) do
    # TODO: Implement clipboard event handling
    {:ok, emulator_state}
  end
end
