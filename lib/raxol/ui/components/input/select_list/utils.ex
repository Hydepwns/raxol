defmodule Raxol.UI.Components.Input.SelectList.Utils do
  @moduledoc """
  Shared utility functions for SelectList component modules.
  Eliminates code duplication between Navigation and Selection modules.
  """

  alias Raxol.UI.Components.Input.SelectList

  @doc """
  Gets the effective options based on current filter/search state.
  Returns filtered_options if present, otherwise the full options list.
  """
  @spec get_effective_options(SelectList.t()) :: list()
  def get_effective_options(state) do
    case state.filtered_options do
      nil -> state.options
      filtered -> filtered
    end
  end

  @doc """
  Extracts a display label from a SelectList option.
  Handles strings, tuples, and maps with :label, :text, :name, or :value keys.
  """
  @spec get_option_label(term()) :: String.t()
  def get_option_label(option) when is_binary(option), do: option
  def get_option_label({label, _value}), do: label
  def get_option_label(%{label: label}), do: label
  def get_option_label(%{text: text}), do: text
  def get_option_label(%{name: name}), do: name
  def get_option_label(%{value: value}), do: to_string(value)
  def get_option_label(option), do: to_string(option)

  @doc """
  Filters options by a search query (case-insensitive substring match).
  Returns all options when query is empty.
  """
  @spec filter_options([term()], String.t()) :: [term()]
  def filter_options(options, query) when query == "", do: options

  def filter_options(options, query) do
    normalized_query = String.downcase(query)

    Enum.filter(options, fn option ->
      label = get_option_label(option)
      String.downcase(label) =~ normalized_query
    end)
  end

  @doc """
  Ensures that the selected item is visible within the scroll viewport.
  Adjusts scroll_offset to bring the selected item into view.
  """
  @spec ensure_visible(SelectList.t()) :: SelectList.t()
  def ensure_visible(state) do
    visible_items = state.visible_items || Raxol.Core.Defaults.page_size()

    new_offset =
      Raxol.Core.Utils.Math.scroll_into_view(
        state.focused_index,
        state.scroll_offset,
        visible_items
      )

    %{state | scroll_offset: new_offset}
  end
end
