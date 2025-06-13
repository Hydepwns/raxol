defmodule Raxol.Terminal.Events.Handlers do
  @moduledoc """
  Contains handlers for different types of terminal events.
  """

  alias Raxol.Terminal.Emulator

  def handle_window_event(%{action: :resize, width: w, height: h}, emulator)
      when is_integer(w) and is_integer(h) do
    {emulator, nil}
  end

  def handle_window_event(%{action: :focus, focused: focused?}, emulator) do
    {emulator, nil}
  end

  def handle_window_event(%{action: :blur}, emulator) do
    {emulator, nil}
  end

  def handle_window_event(_, emulator), do: {emulator, nil}

  def handle_mode_event(%{mode: new_mode}, emulator) do
    {emulator, nil}
  end

  def handle_mode_event(_, emulator), do: {emulator, nil}

  def handle_focus_event(%{focused: focused?}, emulator) do
    {emulator, nil}
  end

  def handle_focus_event(_, emulator), do: {emulator, nil}

  def handle_clipboard_event(%{op: op, content: content}, emulator) do
    {emulator, nil}
  end

  def handle_clipboard_event(_, emulator), do: {emulator, nil}

  def handle_selection_event(%{start_pos: _, end_pos: _, text: _} = selection, emulator) do
    {emulator, nil}
  end

  def handle_selection_event(%{selection: selection}, emulator) do
    {emulator, nil}
  end

  def handle_selection_event(_, emulator), do: {emulator, nil}

  def handle_paste_event(%{text: text, position: pos}, emulator) do
    {emulator, nil}
  end

  def handle_paste_event(_, emulator), do: {emulator, nil}

  def handle_cursor_event(%{visible: _, style: _, blink: _, position: _} = cursor, emulator) do
    {emulator, nil}
  end

  def handle_cursor_event(_, emulator), do: {emulator, nil}

  def handle_scroll_event(%{direction: dir, delta: delta, position: pos}, emulator) do
    {emulator, nil}
  end

  def handle_scroll_event(_, emulator), do: {emulator, nil}
end
