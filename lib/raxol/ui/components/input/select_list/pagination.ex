defmodule Raxol.UI.Components.Input.SelectList.Pagination do
  @moduledoc """
  Pagination helper for SelectList component.
  Handles page-based navigation and state management.
  """

  alias Raxol.UI.Components.Input.SelectList

  @doc """
  Gets the effective options based on current filter/search state.
  """
  @spec get_effective_options(SelectList.t()) :: list()
  def get_effective_options(state) do
    case state.filtered_options do
      nil -> state.options
      filtered -> filtered
    end
  end

  @doc """
  Updates the page state based on page number.
  """
  @spec update_page_state(SelectList.t(), non_neg_integer()) :: SelectList.t()
  def update_page_state(state, page_num) do
    page_size = state.page_size || 10
    effective_options = get_effective_options(state)
    max_pages = calculate_max_pages(effective_options, page_size)

    # Clamp page number to valid range
    page = min(max(page_num, 0), max_pages - 1)

    # Update focused index to first item on the page
    new_index = page * page_size

    %{
      state
      | current_page: page,
        focused_index: new_index,
        scroll_offset: new_index
    }
  end

  @doc """
  Calculates the total number of pages.
  """
  @spec calculate_total_pages(SelectList.t()) :: non_neg_integer()
  def calculate_total_pages(state) do
    effective_options = get_effective_options(state)
    calculate_max_pages(effective_options, state.page_size)
  end

  @doc """
  Gets the current page number.
  """
  @spec get_current_page(SelectList.t()) :: non_neg_integer()
  def get_current_page(state) do
    div(state.focused_index, state.page_size)
  end

  @doc """
  Checks if there's a next page.
  """
  @spec has_next_page?(SelectList.t()) :: boolean()
  def has_next_page?(state) do
    current_page = get_current_page(state)
    total_pages = calculate_total_pages(state)
    current_page < total_pages - 1
  end

  @doc """
  Checks if there's a previous page.
  """
  @spec has_prev_page?(SelectList.t()) :: boolean()
  def has_prev_page?(state) do
    get_current_page(state) > 0
  end

  @doc """
  Moves to the next page.
  """
  @spec next_page(SelectList.t()) :: SelectList.t()
  def next_page(state) do
    if has_next_page?(state) do
      current_page = get_current_page(state)
      update_page_state(state, current_page + 1)
    else
      state
    end
  end

  @doc """
  Moves to the previous page.
  """
  @spec prev_page(SelectList.t()) :: SelectList.t()
  def prev_page(state) do
    if has_prev_page?(state) do
      current_page = get_current_page(state)
      update_page_state(state, current_page - 1)
    else
      state
    end
  end

  @doc """
  Gets the options for the current page.
  """
  @spec get_page_options(SelectList.t()) :: list()
  def get_page_options(state) do
    effective_options = get_effective_options(state)
    page = get_current_page(state)
    start_index = page * state.visible_items

    Enum.slice(effective_options, start_index, state.visible_items)
  end

  # Private functions

  defp calculate_max_pages(options, visible_items) when visible_items > 0 do
    total = length(options)
    div(total + visible_items - 1, visible_items)
  end

  defp calculate_max_pages(_, _), do: 1
end
