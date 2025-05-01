defmodule Raxol.Components.Input.MultiLineInput.EventHandler do
  @moduledoc """
  Handles key and mouse events for MultiLineInput, translating them into update messages.
  """

  # Needed for update/2 calls
  alias Raxol.Components.Input.MultiLineInput
  # For event structs like KeyDown
  alias Raxol.Core.Events.Event, as: Event
  require Logger

  # Directly handle the event struct for more clarity
  def handle_event(%Event{type: :key, data: %{key: key, state: state, modifiers: modifiers}} = _event, state)
  when state in [:pressed, :repeat] do
    # Translate key data to update message
    msg =
      case {key, modifiers} do
        # Basic Input
        {char, []} when is_binary(char) ->
          if String.length(char) == 1 and String.printable?(char) do
            {:input, char}
          else
            # Ignore multi-character sequences for now, or handle if needed
            nil
          end

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

    # Return the update message directly for the component behaviour
    if msg do
      {:update, msg, state}
    else
      {:noreply, state, nil}
    end
  end

  # Handle Mouse Events (Placeholder/Basic)
  def handle_event(%Event{type: :mouse, data: %{x: x, y: y, button: :left, state: :pressed}} = _event, state) do
    # Calculate row/col based on component position/scroll (simplified)
    comp_x = Map.get(state.meta, :abs_col, 0)
    comp_y = Map.get(state.meta, :abs_row, 0)
    {scroll_row, scroll_col} = state.scroll_offset
    row = max(0, y - comp_y + scroll_row)
    col = max(0, x - comp_x + scroll_col)

    msg = {:move_cursor_to, {row, col}}
    # Return the update message for the component behaviour
    {:update, msg, state}
    # TODO: Handle drag for selection
    # {:noreply, state, nil}
  end

  # Catch-all for unhandled events
  def handle_event(event, state) do
    # Rename _event to event
    Logger.debug("Unhandled event: #{inspect(event)}")
    # Ensure the correct tuple arity is returned
    {:noreply, state, nil}
  end
end
