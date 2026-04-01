defmodule Raxol.UI.Components.Input.SelectList.Utils do
  @moduledoc """
  Shared utility functions for SelectList component modules.
  Eliminates code duplication between Navigation and Selection modules.
  """

  alias Raxol.UI.Components.Input.SelectList

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
    # Use focused_index since that's what Selection module updates
    index = state.focused_index

    cond do
      index < state.scroll_offset ->
        # Selected item is above visible area
        %{state | scroll_offset: index}

      index >= state.scroll_offset + visible_items ->
        # Selected item is below visible area
        %{state | scroll_offset: index - visible_items + 1}

      true ->
        # Selected item is already visible
        state
    end
  end
end
