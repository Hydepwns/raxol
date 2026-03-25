defmodule Raxol.UI.Components.Input.MultiLineInput.CursorMovement do
  @moduledoc false

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper

  def handle_move_cursor(direction, state) do
    new_state =
      NavigationHelper.move_cursor(state, direction)
      |> NavigationHelper.clear_selection()

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_line_start(state) do
    new_state =
      NavigationHelper.move_cursor_line_start(state)
      |> NavigationHelper.clear_selection()

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_line_end(state) do
    new_state =
      NavigationHelper.move_cursor_line_end(state)
      |> NavigationHelper.clear_selection()

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_page(direction, state) do
    new_state =
      NavigationHelper.move_cursor_page(state, direction)
      |> NavigationHelper.clear_selection()

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_doc_start(state) do
    new_state =
      NavigationHelper.move_cursor_doc_start(state)
      |> NavigationHelper.clear_selection()

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_doc_end(state) do
    new_state =
      NavigationHelper.move_cursor_doc_end(state)
      |> NavigationHelper.clear_selection()

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_to({row, col}, state) do
    new_state =
      %{state | cursor_pos: {row, col}}
      |> NavigationHelper.clear_selection()

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_word_left(state) do
    new_state =
      NavigationHelper.move_cursor(state, :word_left)
      |> NavigationHelper.clear_selection()

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_move_cursor_word_right(state) do
    new_state =
      NavigationHelper.move_cursor(state, :word_right)
      |> NavigationHelper.clear_selection()

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_selection_move(state, direction) do
    original_cursor_pos = state.cursor_pos
    moved_state = move_cursor_by_direction(state, direction)
    new_cursor_pos = moved_state.cursor_pos
    selection_start = state.selection_start || original_cursor_pos

    final_state = %{
      moved_state
      | selection_start: selection_start,
        selection_end: new_cursor_pos
    }

    {:noreply, MultiLineInput.ensure_cursor_visible(final_state), nil}
  end

  def move_cursor_by_direction(state, direction) do
    direction_handlers = %{
      :left => fn ->
        NavigationHelper.move_cursor(state, :left)
      end,
      :right => fn ->
        NavigationHelper.move_cursor(state, :right)
      end,
      :up => fn ->
        NavigationHelper.move_cursor(state, :up)
      end,
      :down => fn ->
        NavigationHelper.move_cursor(state, :down)
      end,
      :line_start => fn ->
        NavigationHelper.move_cursor_line_start(state)
      end,
      :line_end => fn ->
        NavigationHelper.move_cursor_line_end(state)
      end,
      :page_up => fn ->
        NavigationHelper.move_cursor_page(state, :up)
      end,
      :page_down => fn ->
        NavigationHelper.move_cursor_page(state, :down)
      end,
      :doc_start => fn ->
        NavigationHelper.move_cursor_doc_start(state)
      end,
      :doc_end => fn ->
        NavigationHelper.move_cursor_doc_end(state)
      end
    }

    case Map.get(direction_handlers, direction) do
      nil -> state
      handler -> handler.()
    end
  end
end
