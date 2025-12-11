defmodule RaxolPlaygroundWeb.Live.ComponentHelpers do
  @moduledoc """
  Shared helper functions for component filtering and manipulation.
  """

  @doc """
  Filters components by search query.

  Searches across component name, description, and tags.
  Empty query returns all components.
  """
  def filter_by_search(components, ""), do: components

  def filter_by_search(components, query) do
    query = String.downcase(query)

    Enum.filter(components, fn component ->
      String.contains?(String.downcase(component.name), query) ||
        String.contains?(String.downcase(component.description), query) ||
        Enum.any?(component.tags, &String.contains?(String.downcase(&1), query))
    end)
  end
end
