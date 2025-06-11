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

    if num_options == 0 do
      state
    else
      new_index = max(0, state.focused_index - 1)
      update_focus_and_scroll(state, new_index)
    end
  end

  @doc """
  Handles arrow down key press, moving focus down one item.
  """
  def handle_arrow_down(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    if num_options == 0 do
      state
    else
      new_index = min(num_options - 1, state.focused_index + 1)
      update_focus_and_scroll(state, new_index)
    end
  end

  @doc """
  Handles page up key press, moving focus up one page.
  """
  def handle_page_up(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    if num_options == 0 do
      state
    else
      new_index = max(0, state.focused_index - state.page_size)
      update_focus_and_scroll(state, new_index)
    end
  end

  @doc """
  Handles page down key press, moving focus down one page.
  """
  def handle_page_down(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    if num_options == 0 do
      state
    else
      new_index = min(num_options - 1, state.focused_index + state.page_size)
      update_focus_and_scroll(state, new_index)
    end
  end

  @doc """
  Handles home key press, moving focus to the first item.
  """
  def handle_home(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    if num_options == 0 do
      state
    else
      update_focus_and_scroll(state, 0)
    end
  end

  @doc """
  Handles end key press, moving focus to the last item.
  """
  def handle_end(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    if num_options == 0 do
      state
    else
      update_focus_and_scroll(state, num_options - 1)
    end
  end

  @doc """
  Updates focus index and scroll position to ensure the focused item is visible.
  """
  def update_focus_and_scroll(state, new_index) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)

    if num_options == 0 do
      state
    else
      clamped_index = min(max(new_index, 0), num_options - 1)
      # Calculate new scroll offset to keep focused item visible
      new_scroll_offset =
        cond do
          clamped_index < state.scroll_offset ->
            clamped_index

          clamped_index >= state.scroll_offset + state.page_size ->
            clamped_index - state.page_size + 1

          true ->
            state.scroll_offset
        end

      %{state | focused_index: clamped_index, scroll_offset: new_scroll_offset}
    end
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

    if index >= 0 and index < length(effective_options) do
      index
    else
      -1
    end
  end

  @doc """
  Recalculates scroll position to ensure the focused item is visible after a resize or visible_height change.
  Always returns a valid state map.
  """
  def update_scroll_position(state) do
    effective_options = Pagination.get_effective_options(state)
    num_options = length(effective_options)
    visible_height = state.visible_height || state.page_size
    focused_index = state.focused_index

    # Clamp scroll_offset so focused_index is visible
    new_scroll_offset =
      cond do
        focused_index < state.scroll_offset ->
          focused_index

        focused_index >= state.scroll_offset + visible_height ->
          max(0, focused_index - visible_height + 1)

        true ->
          state.scroll_offset
      end

    %{state | scroll_offset: new_scroll_offset}
  end
end
