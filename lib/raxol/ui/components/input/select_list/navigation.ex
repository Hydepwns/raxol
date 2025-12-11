defmodule Raxol.UI.Components.Input.SelectList.Navigation do
  @moduledoc """
  Navigation helper for SelectList component.
  Handles arrow key navigation, home/end, and page up/down.
  """

  alias Raxol.UI.Components.Input.SelectList.Utils

  @doc """
  Handles arrow down navigation.
  """
  def handle_arrow_down(state) do
    max_index = length(state.options) - 1
    new_index = min(state.focused_index + 1, max_index)

    %{state | focused_index: new_index}
    |> ensure_visible()
  end

  @doc """
  Handles arrow up navigation.
  """
  def handle_arrow_up(state) do
    new_index = max(state.focused_index - 1, 0)

    %{state | focused_index: new_index}
    |> ensure_visible()
  end

  @doc """
  Handles home key navigation (go to first item).
  """
  def handle_home(state) do
    %{state | focused_index: 0, scroll_offset: 0}
  end

  @doc """
  Handles end key navigation (go to last item).
  """
  def handle_end(state) do
    max_index = length(state.options) - 1

    %{state | focused_index: max_index}
    |> ensure_visible()
  end

  @doc """
  Handles page up navigation.
  """
  def handle_page_up(state) do
    page_size = state.visible_items || 10
    new_index = max(state.focused_index - page_size, 0)

    %{state | focused_index: new_index}
    |> ensure_visible()
  end

  @doc """
  Handles page down navigation.
  """
  def handle_page_down(state) do
    page_size = state.visible_items || 10
    max_index = length(state.options) - 1
    new_index = min(state.focused_index + page_size, max_index)

    %{state | focused_index: new_index}
    |> ensure_visible()
  end

  @doc """
  Handles search/filter navigation.
  """
  def handle_search(state, query) do
    filtered_options = filter_options(state.options, query)

    %{
      state
      | filtered_options: filtered_options,
        search_query: query,
        focused_index: 0,
        scroll_offset: 0
    }
  end

  @doc """
  Clears the current search filter.
  """
  def clear_search(state) do
    %{
      state
      | filtered_options: nil,
        search_query: "",
        focused_index: 0,
        scroll_offset: 0
    }
  end

  @doc """
  Updates the scroll position to ensure selected item is visible.
  """
  def update_scroll_position(state) do
    ensure_visible(state)
  end

  # Private functions

  defp ensure_visible(state) do
    Utils.ensure_visible(state)
  end

  defp filter_options(options, query) when query == "", do: options

  defp filter_options(options, query) do
    normalized_query = String.downcase(query)

    Enum.filter(options, fn option ->
      label = get_option_label(option)
      String.downcase(label) =~ normalized_query
    end)
  end

  defp get_option_label(option) when is_binary(option), do: option
  defp get_option_label({label, _value}), do: label
  defp get_option_label(%{label: label}), do: label
  defp get_option_label(%{text: text}), do: text
  defp get_option_label(%{name: name}), do: name
  defp get_option_label(option), do: to_string(option)
end
