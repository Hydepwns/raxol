defmodule Raxol.UI.Components.Input.SelectList.Search do
  @moduledoc """
  Handles search and filtering functionality for the SelectList component.
  """

  @type option :: {String.t(), any()}
  @type options :: [option()]

  @doc """
  Filters options based on search text and optional searchable fields.
  Returns nil if no search text is provided, otherwise returns filtered options.
  """
  def filter_options(options, search_text, searchable_fields) do
    unless search_text != "" do
      nil
    else
      filtered =
        Enum.filter(options, fn option ->
          search_matches?(option, search_text, searchable_fields)
        end)

      filtered
    end
  end

  @doc """
  Checks if an option matches the search text.
  If searchable_fields is provided, only those fields are searched.
  Otherwise, the option label is searched.
  """
  def search_matches?({label, _value}, search_text, nil) do
    String.contains?(String.downcase(label), String.downcase(search_text))
  end

  def search_matches?({label, value}, search_text, searchable_fields) do
    # Always search the label
    label_match =
      String.contains?(String.downcase(label), String.downcase(search_text))

    # Search specified fields in the value if it's a map
    value_match =
      if is_map(value) do
        Enum.any?(searchable_fields, fn field ->
          case Map.get(value, field) do
            nil ->
              false

            field_value ->
              String.contains?(
                String.downcase(to_string(field_value)),
                String.downcase(search_text)
              )
          end
        end)
      else
        false
      end

    label_match or value_match
  end

  @doc """
  Updates search-related state based on new search text.
  """
  def update_search_state(state, search_text) do
    %{
      state
      | search_text: search_text,
        is_filtering: search_text != "",
        filtered_options:
          filter_options(state.options, search_text, state.searchable_fields),
        # Reset focus to first matching item
        focused_index: 0,
        # Reset scroll position
        scroll_offset: 0
    }
  end
end
