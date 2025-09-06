defmodule Raxol.UI.Components.Input.SelectList.Navigation do
  @moduledoc """
  Handles keyboard navigation functionality for the SelectList component.
  """

  alias Raxol.UI.Components.Input.SelectList.Pagination

  @doc """
  Handles arrow up key press, moving focus up one item.
  """
  def handle_arrow_up(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    has_options = num_options > 0
    handle_arrow_up_navigation(has_options, state)
  end

  defp handle_arrow_up_navigation(false, state), do: state

  defp handle_arrow_up_navigation(true, state) do
    new_index = max(0, state.focused_index - 1)
    update_focus_and_scroll(state, new_index)
  end

  @doc """
  Handles arrow down key press, moving focus down one item.
  """
  def handle_arrow_down(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    has_options = num_options > 0
    handle_arrow_down_navigation(has_options, state, num_options)
  end

  defp handle_arrow_down_navigation(false, state, _num_options), do: state

  defp handle_arrow_down_navigation(true, state, num_options) do
    new_index = min(num_options - 1, state.focused_index + 1)
    update_focus_and_scroll(state, new_index)
  end

  @doc """
  Handles page up key press, moving focus up one page.
  """
  def handle_page_up(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    has_options = num_options > 0
    handle_page_up_navigation(has_options, state)
  end

  defp handle_page_up_navigation(false, state), do: state

  defp handle_page_up_navigation(true, state) do
    new_index = max(0, state.focused_index - state.page_size)
    update_focus_and_scroll(state, new_index)
  end

  @doc """
  Handles page down key press, moving focus down one page.
  """
  def handle_page_down(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    has_options = num_options > 0
    handle_page_down_navigation(has_options, state, num_options)
  end

  defp handle_page_down_navigation(false, state, _num_options), do: state

  defp handle_page_down_navigation(true, state, num_options) do
    new_index = min(num_options - 1, state.focused_index + state.page_size)
    update_focus_and_scroll(state, new_index)
  end

  @doc """
  Handles home key press, moving focus to the first item.
  """
  def handle_home(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    has_options = num_options > 0
    handle_home_navigation(has_options, state)
  end

  defp handle_home_navigation(false, state), do: state

  defp handle_home_navigation(true, state) do
    update_focus_and_scroll(state, 0)
  end

  @doc """
  Handles end key press, moving focus to the last item.
  """
  def handle_end(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    has_options = num_options > 0
    handle_end_navigation(has_options, state, num_options)
  end

  defp handle_end_navigation(false, state, _num_options), do: state

  defp handle_end_navigation(true, state, num_options) do
    update_focus_and_scroll(state, num_options - 1)
  end

  @doc """
  Updates focus index and scroll position to ensure the focused item is visible.
  """
  def update_focus_and_scroll(state, new_index) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    has_options = num_options > 0
    handle_focus_scroll_update(has_options, state, new_index, num_options)
  end

  defp handle_focus_scroll_update(false, state, _new_index, _num_options),
    do: state

  defp handle_focus_scroll_update(true, state, new_index, num_options) do
    clamped_index = min(max(new_index, 0), num_options - 1)
    # Calculate new scroll offset to keep focused item visible
    new_scroll_offset =
      calculate_scroll_offset(
        clamped_index,
        state.scroll_offset,
        state.page_size
      )

    %{state | focused_index: clamped_index, scroll_offset: new_scroll_offset}
  end

  @doc """
  Calculates the index of the option clicked based on the y position and current state.
  Returns the index, or -1 if out of bounds.
  """
  def calculate_clicked_index(y, state) do
    # Assume y is the vertical position relative to the top of the options list.
    # If there is a header/search input, y should be offset accordingly by the caller.
    # Each option is assumed to take 1 row (can be adjusted if needed).
    index = state.scroll_offset + y
    effective_options = Pagination.get_effective_options(state)

    is_valid_index = index >= 0 and index < length(effective_options)
    handle_clicked_index_result(is_valid_index, index)
  end

  defp handle_clicked_index_result(true, index), do: index
  defp handle_clicked_index_result(false, _index), do: -1

  @doc """
  Recalculates scroll position to ensure the focused item is visible after a resize or visible_height change.
  Always returns a valid state map.
  """
  def update_scroll_position(state) do
    visible_height = state.visible_height || state.page_size
    focused_index = state.focused_index

    # Clamp scroll_offset so focused_index is visible
    new_scroll_offset =
      calculate_scroll_offset_with_max(
        focused_index,
        state.scroll_offset,
        visible_height
      )

    %{state | scroll_offset: new_scroll_offset}
  end

  defp calculate_scroll_offset(index, scroll_offset, _page_size)
       when index < scroll_offset,
       do: index

  defp calculate_scroll_offset(index, scroll_offset, page_size)
       when index >= scroll_offset + page_size,
       do: index - page_size + 1

  defp calculate_scroll_offset(_index, scroll_offset, _page_size),
    do: scroll_offset

  defp calculate_scroll_offset_with_max(index, scroll_offset, _visible_height)
       when index < scroll_offset,
       do: index

  defp calculate_scroll_offset_with_max(index, scroll_offset, visible_height)
       when index >= scroll_offset + visible_height,
       do: max(0, index - visible_height + 1)

  defp calculate_scroll_offset_with_max(_index, scroll_offset, _visible_height),
    do: scroll_offset
end
