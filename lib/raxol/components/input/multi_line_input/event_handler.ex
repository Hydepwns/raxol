defmodule Raxol.Components.Input.MultiLineInput.EventHandler do
  @moduledoc """
  Handles key and mouse events for MultiLineInput, translating them into update messages.
  """

  # Needed for update/2 calls
  alias Raxol.Components.Input.MultiLineInput
  # For event structs like KeyDown
  alias Raxol.Event
  require Logger

  # Directly handle the event struct for more clarity
  def handle_event(%Event.KeyDown{key: key, modifiers: modifiers}, state) do
    # Translate key data to update message
    msg =
      case {key, modifiers} do
        # Basic Input
        {char, []}
        when is_binary(char) and String.length(char) == 1 and
               String.printable?(char) ->
          {:input, char}

        {:backspace, []} ->
          {:backspace}

        {:delete, []} ->
          {:delete}

        {:enter, []} ->
          {:enter}

        # Basic Navigation (No Shift)
        {:left, []} ->
          {:move_cursor, :left}

        {:right, []} ->
          {:move_cursor, :right}

        {:up, []} ->
          {:move_cursor, :up}

        {:down, []} ->
          {:move_cursor, :down}

        {:home, []} ->
          {:move_cursor_line_start}

        {:end, []} ->
          {:move_cursor_line_end}

        {:pageup, []} ->
          {:move_cursor_page, :up}

        {:pagedown, []} ->
          {:move_cursor_page, :down}

        # TODO: Add Ctrl+Arrows etc. if not already mapped
        # {:left, [:ctrl]} -> {:move_cursor_word_left}
        # {:right, [:ctrl]} -> {:move_cursor_word_right}
        {:home, [:ctrl]} ->
          {:move_cursor_doc_start}

        {:end, [:ctrl]} ->
          {:move_cursor_doc_end}

        # Selection with Shift
        {:left, [:shift]} ->
          {:select_and_move, :left}

        {:right, [:shift]} ->
          {:select_and_move, :right}

        {:up, [:shift]} ->
          {:select_and_move, :up}

        {:down, [:shift]} ->
          {:select_and_move, :down}

        {:home, [:shift]} ->
          {:select_and_move, :line_start}

        {:end, [:shift]} ->
          {:select_and_move, :line_end}

        {:pageup, [:shift]} ->
          {:select_and_move, :page_up}

        {:pagedown, [:shift]} ->
          {:select_and_move, :page_down}

        # TODO: Add Shift + Ctrl + Arrows, etc. for word selection
        {:home, [:shift, :ctrl]} ->
          {:select_and_move, :doc_start}

        {:end, [:shift, :ctrl]} ->
          {:select_and_move, :doc_end}

        # Ctrl+A for select all
        {:a, [:ctrl]} ->
          {:select_all}

        # Clipboard
        {:c, [:ctrl]} ->
          {:copy}

        {:x, [:ctrl]} ->
          {:cut}

        {:v, [:ctrl]} ->
          {:paste}

        # TODO: Add other bindings (Undo/Redo?)

        # Ignore unhandled keys
        _ ->
          nil
      end

    # Call update on the main component module
    if msg, do: MultiLineInput.update(msg, state), else: {:noreply, state, nil}
  end

  # Handle Mouse Events (Placeholder/Basic)
  def handle_event(%Event.MouseClick{x: x, y: y, button: :left}, state) do
    # Calculate row/col based on component position/scroll (simplified)
    comp_x = Map.get(state.meta, :abs_col, 0)
    comp_y = Map.get(state.meta, :abs_row, 0)
    offset = state.scroll_offset
    scroll_row = elem(offset, 0)
    scroll_col = elem(offset, 1)
    row = max(0, y - comp_y + scroll_row)
    col = max(0, x - comp_x + scroll_col)

    msg = {:move_cursor_to, {row, col}}
    MultiLineInput.update(msg, state)
    # TODO: Handle drag for selection
  end

  # Ignore other events
  def handle_event(_event, state) do
    Logger.debug("Unhandled event: #{inspect(_event)}")
    {:noreply, state, nil}
  end

  # Private helper to handle mouse clicks within the component area
  # Needs component bounds/position from context/render state
  defp handle_mouse_click(
         %Event{type: :mouse_click, data: %{x: x, y: y}} = _event,
         state
       ) do
    comp_x = Map.get(state.meta, :abs_col, 0)
    comp_y = Map.get(state.meta, :abs_row, 0)
    offset = state.scroll_offset
    scroll_row = elem(offset, 0)
    scroll_col = elem(offset, 1)
    row = max(0, y - comp_y + scroll_row)
    col = max(0, x - comp_x + scroll_col)

    {:update, {:move_cursor_to, {row, col}}}
  end
end
