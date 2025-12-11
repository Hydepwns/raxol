defmodule Raxol.UI.Components.Input.SelectList.Search do
  @moduledoc """
  Search/filter functionality for SelectList component.
  """

  @doc """
  Updates the search state with a new query.
  """
  def update_search_state(state, query) do
    is_filtering = query != ""

    filtered_options =
      if is_filtering do
        filter_options(state.options, query)
      else
        nil
      end

    %{
      state
      | search_query: query,
        filtered_options: filtered_options,
        is_filtering: is_filtering,
        selected_index: 0,
        scroll_offset: 0
    }
  end

  @doc """
  Clears the current search.
  """
  def clear_search(state) do
    %{
      state
      | search_query: "",
        filtered_options: nil,
        selected_index: 0,
        scroll_offset: 0
    }
  end

  @doc """
  Checks if search is active.
  """
  def search_active?(state) do
    state.search_query != "" and state.search_query != nil
  end

  @doc """
  Gets the current search results count.
  """
  def get_results_count(state) do
    case state.filtered_options do
      nil -> length(state.options)
      filtered -> length(filtered)
    end
  end

  @doc """
  Appends a character to the search query.
  """
  def append_to_search(state, char) do
    new_query = (state.search_query || "") <> char
    update_search_state(state, new_query)
  end

  @doc """
  Removes the last character from the search query.
  """
  def backspace_search(state) do
    query = state.search_query || ""

    new_query =
      if String.length(query) > 0 do
        String.slice(query, 0..-2//1)
      else
        ""
      end

    update_search_state(state, new_query)
  end

  # Private functions

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
  defp get_option_label(%{value: value}), do: to_string(value)
  defp get_option_label(option), do: to_string(option)
end
