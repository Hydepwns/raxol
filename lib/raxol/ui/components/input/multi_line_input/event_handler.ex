defmodule Raxol.UI.Components.Input.MultiLineInput.EventHandler do
  @moduledoc """
  Event handler for MultiLineInput component.
  Handles keyboard input and navigation events.
  """

  alias Raxol.Core.Events.Event
  alias Raxol.UI.Components.Input.MultiLineInput

  @doc """
  Handles events for the MultiLineInput component.
  """
  @spec handle_event(Event.t(), MultiLineInput.t()) ::
          {:update, term(), MultiLineInput.t()}
          | {:noreply, MultiLineInput.t()}
          | term()
  def handle_event(
        %Event{type: :key, data: %{key: key, modifiers: modifiers}},
        state
      ) do
    case {key, modifiers} do
      # Character input
      {char, []} when is_binary(char) and byte_size(char) == 1 ->
        {:update, {:input, char}, state}

      # Enter key
      {:enter, []} ->
        {:update, {:enter}, state}

      # Backspace
      {:backspace, []} ->
        {:update, {:backspace}, state}

      # Delete
      {:delete, []} ->
        {:update, {:delete}, state}

      # Arrow keys
      {:up, []} ->
        {:update, {:move_cursor, :up}, state}

      {:down, []} ->
        {:update, {:move_cursor, :down}, state}

      {:left, []} ->
        {:update, {:move_cursor, :left}, state}

      {:right, []} ->
        {:update, {:move_cursor, :right}, state}

      # Arrow keys with shift (selection)
      {:up, [:shift]} ->
        {:update, {:select_and_move, :up}, state}

      {:down, [:shift]} ->
        {:update, {:select_and_move, :down}, state}

      {:left, [:shift]} ->
        {:update, {:select_and_move, :left}, state}

      {:right, [:shift]} ->
        {:update, {:select_and_move, :right}, state}

      # Home/End
      {:home, []} ->
        {:update, {:move_cursor_line_start}, state}

      {:end, []} ->
        {:update, {:move_cursor_line_end}, state}

      # Page up/down (both variants)
      {:page_up, []} ->
        {:update, {:move_cursor_page, :up}, state}

      {:page_down, []} ->
        {:update, {:move_cursor_page, :down}, state}

      {:pageup, []} ->
        {:update, {:move_cursor_page, :up}, state}

      {:pagedown, []} ->
        {:update, {:move_cursor_page, :down}, state}

      # Ctrl combinations
      {"a", [:ctrl]} ->
        {:update, :select_all, state}

      {"c", [:ctrl]} ->
        {:update, :copy, state}

      {"v", [:ctrl]} ->
        {:update, :paste, state}

      {"x", [:ctrl]} ->
        {:update, :cut, state}

      {"z", [:ctrl]} ->
        {:update, :undo, state}

      {"y", [:ctrl]} ->
        {:update, :redo, state}

      # Tab
      {:tab, []} ->
        {:update, {:handle_tab}, state}

      # Default case - no action for unknown key events
      _ ->
        {:noreply, state, nil}
    end
  end

  def handle_event(
        %Event{
          type: :mouse,
          data: %{button: :left, state: :pressed, position: {x, y}}
        },
        state
      ) do
    # Handle mouse click to move cursor (coordinates are swapped: y becomes row, x becomes col)
    {:update, {:move_cursor_to, {y, x}}, state}
  end

  def handle_event(%Event{type: :mouse}, state) do
    # Handle other mouse events (drag, release, etc.)
    {:noreply, state}
  end

  def handle_event(_event, state) do
    # Default case for other event types
    {:noreply, state, nil}
  end
end
