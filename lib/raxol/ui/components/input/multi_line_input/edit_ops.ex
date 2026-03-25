defmodule Raxol.UI.Components.Input.MultiLineInput.EditOps do
  @moduledoc false

  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.NavigationHelper
  alias Raxol.UI.Components.Input.MultiLineInput.TextHelper

  def handle_input(char_codepoint, state) do
    state = MultiLineInput.push_history(state)

    new_state = TextHelper.insert_char(state, char_codepoint)

    MultiLineInput.trigger_on_change(
      {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil},
      state
    )
  end

  def handle_backspace(state) do
    state = MultiLineInput.push_history(state)
    new_state = process_backspace_with_selection_check(state)

    MultiLineInput.trigger_on_change(
      {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil},
      state
    )
  end

  def handle_delete(state) do
    state = MultiLineInput.push_history(state)
    new_state = process_delete_with_selection_check(state)

    MultiLineInput.trigger_on_change(
      {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil},
      state
    )
  end

  def handle_enter(state) do
    state = MultiLineInput.push_history(state)
    {state_after_delete, _} = handle_enter_selection_delete(state)

    new_state = TextHelper.insert_char(state_after_delete, 10)

    MultiLineInput.trigger_on_change(
      {:noreply, MultiLineInput.ensure_cursor_visible(new_state), nil},
      state
    )
  end

  defp process_backspace_with_selection_check(state) do
    selection_result = NavigationHelper.normalize_selection(state)
    do_backspace_with_selection(elem(selection_result, 0), state)
  end

  defp do_backspace_with_selection(nil, state) do
    TextHelper.handle_backspace_no_selection(state)
  end

  defp do_backspace_with_selection(_selection, state) do
    TextHelper.delete_selection(state)
  end

  defp process_delete_with_selection_check(state) do
    selection_result = NavigationHelper.normalize_selection(state)
    do_delete_with_selection(elem(selection_result, 0), state)
  end

  defp do_delete_with_selection(nil, state) do
    TextHelper.handle_delete_no_selection(state)
  end

  defp do_delete_with_selection(_selection, state) do
    TextHelper.delete_selection(state)
  end

  defp handle_enter_selection_delete(state) do
    selection_result = NavigationHelper.normalize_selection(state)
    do_enter_selection_delete(elem(selection_result, 0), state)
  end

  defp do_enter_selection_delete(nil, state), do: {state, ""}

  defp do_enter_selection_delete(_selection, state) do
    TextHelper.delete_selection(state)
  end
end
