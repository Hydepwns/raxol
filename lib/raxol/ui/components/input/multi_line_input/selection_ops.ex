defmodule Raxol.UI.Components.Input.MultiLineInput.SelectionOps do
  @moduledoc false

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper
  alias Raxol.UI.Components.Input.MultiLineInput.ClipboardHelper

  def handle_select_all(state) do
    new_state = NavigationHelper.select_all(state)
    {:noreply, new_state, nil}
  end

  def handle_copy(state) do
    _result = handle_copy_if_selection_exists(state)
    {:noreply, state, nil}
  end

  def handle_cut(state) do
    handle_cut_with_selection_check(state)
  end

  def handle_paste(state) do
    ClipboardHelper.paste(state)
  end

  def handle_clipboard_content(content, state) do
    state = MultiLineInput.push_history(state)
    {start_pos, end_pos} = get_clipboard_position_range(state)

    updated_state =
      TextHelper.replace_text_range(state, start_pos, end_pos, content)

    {start_row, start_col} = start_pos

    {new_row, new_col} =
      TextHelper.calculate_new_position(state, content, {start_row, start_col})

    new_state = %{
      updated_state
      | cursor_pos: {new_row, new_col},
        selection_start: nil,
        selection_end: nil
    }

    MultiLineInput.trigger_on_change({:noreply, new_state, nil}, state)
  end

  def handle_delete_selection(_direction, state) do
    handle_delete_selection_if_exists(state)
  end

  def handle_copy_selection(state) do
    _ = handle_copy_if_selection_exists(state)
    {:noreply, state}
  end

  def handle_select_to({row, col}, state) do
    original_cursor_pos = state.cursor_pos
    selection_start = state.selection_start || original_cursor_pos

    new_state = %{
      state
      | selection_start: selection_start,
        selection_end: {row, col},
        cursor_pos: {row, col}
    }

    {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil}
  end

  def handle_copy_if_selection_exists(state) do
    selection_result = NavigationHelper.normalize_selection(state)
    do_copy_if_selection_exists(elem(selection_result, 0), state)
  end

  defp do_copy_if_selection_exists(nil, _state), do: :ok

  defp do_copy_if_selection_exists(_selection, state) do
    ClipboardHelper.copy_selection(state)
  end

  defp handle_cut_with_selection_check(state) do
    selection_result = NavigationHelper.normalize_selection(state)
    do_cut_with_selection(elem(selection_result, 0), state)
  end

  defp do_cut_with_selection(nil, state), do: {:noreply, state, nil}

  defp do_cut_with_selection(_selection, state) do
    new_state = ClipboardHelper.cut_selection(state)

    MultiLineInput.trigger_on_change(
      {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil},
      state
    )
  end

  defp get_clipboard_position_range(%{selection_start: nil} = state),
    do: {state.cursor_pos, state.cursor_pos}

  defp get_clipboard_position_range(%{selection_end: nil} = state),
    do: {state.cursor_pos, state.cursor_pos}

  defp get_clipboard_position_range(state) do
    NavigationHelper.normalize_selection(state)
  end

  defp handle_delete_selection_if_exists(state) do
    selection_result = NavigationHelper.normalize_selection(state)
    do_delete_selection_if_exists(elem(selection_result, 0), state)
  end

  defp do_delete_selection_if_exists(nil, state), do: {:noreply, state}

  defp do_delete_selection_if_exists(_selection, state) do
    TextHelper.delete_selection(state)
  end
end
