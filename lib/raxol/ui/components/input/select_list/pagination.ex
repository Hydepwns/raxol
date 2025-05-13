defmodule Raxol.UI.Components.Input.SelectList.Pagination do
  @moduledoc """
  Handles pagination functionality for the SelectList component.
  """

  @type option :: {String.t(), any()}
  @type options :: [option()]

  @doc """
  Calculates the total number of pages based on the number of options and page size.
  """
  def calculate_total_pages(num_options, page_size) do
    if num_options == 0 do
      1
    else
      ceil(num_options / page_size)
    end
  end

  @doc """
  Gets the options for a specific page.
  """
  def get_page_options(options, page_num, page_size) do
    start_idx = page_num * page_size
    end_idx = min(start_idx + page_size, length(options))
    Enum.slice(options, start_idx, end_idx - start_idx)
  end

  @doc """
  Updates pagination state based on a new page number.
  """
  def update_page_state(state, page_num) do
    effective_options = get_effective_options(state)

    total_pages =
      calculate_total_pages(length(effective_options), state.page_size)

    # Ensure page number is valid
    valid_page = max(0, min(page_num, total_pages - 1))

    # Calculate new focused index based on page change
    new_focused_index = valid_page * state.page_size

    # Clamp to valid option range
    clamped_focus =
      min(new_focused_index, max(0, length(effective_options) - 1))

    %{
      state
      | current_page: valid_page,
        focused_index: clamped_focus,
        scroll_offset: valid_page * state.page_size
    }
  end

  @doc """
  Gets the effective options list (filtered or original) based on current state.
  """
  def get_effective_options(state) do
    if state.is_filtering and state.filtered_options do
      state.filtered_options
    else
      state.options
    end
  end
end
