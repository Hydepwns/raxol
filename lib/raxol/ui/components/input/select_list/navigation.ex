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
      # Calculate new scroll offset to keep focused item visible
      new_scroll_offset =
        cond do
          # If focused item is above visible area, scroll up
          new_index < state.scroll_offset ->
            new_index

          # If focused item is below visible area, scroll down
          new_index >= state.scroll_offset + state.page_size ->
            new_index - state.page_size + 1

          # Otherwise keep current scroll position
          true ->
            state.scroll_offset
        end

      %{state | focused_index: new_index, scroll_offset: new_scroll_offset}
    end
  end
end
