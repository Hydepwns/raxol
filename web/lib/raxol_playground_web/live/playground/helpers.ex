defmodule RaxolPlaygroundWeb.Playground.Helpers do
  @moduledoc """
  Helper functions for the Raxol playground.
  Includes component filtering, categorization, and UI helpers.
  """

  @doc """
  Returns CSS classes for complexity badges.
  """
  def complexity_class("Basic"), do: "bg-green-100 text-green-800"
  def complexity_class("Intermediate"), do: "bg-yellow-100 text-yellow-800"
  def complexity_class("Advanced"), do: "bg-red-100 text-red-800"
  def complexity_class(_), do: "bg-gray-100 text-gray-800"

  @doc """
  Extracts unique categories from a list of components, sorted alphabetically.
  """
  def get_categories(components) do
    components
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Filters components by category.
  """
  def get_components_by_category(components, category) do
    Enum.filter(components, &(&1.category == category))
  end

  @doc """
  Filters components by search query.
  Searches in name, description, and tags.
  """
  def filter_components(components, "") do
    components
  end

  def filter_components(components, query) do
    query_lower = String.downcase(query)

    Enum.filter(components, fn component ->
      matches_name?(component, query_lower) ||
        matches_description?(component, query_lower) ||
        matches_tags?(component, query_lower)
    end)
  end

  defp matches_name?(component, query) do
    String.contains?(String.downcase(component.name), query)
  end

  defp matches_description?(component, query) do
    String.contains?(String.downcase(component.description), query)
  end

  defp matches_tags?(component, query) do
    Enum.any?(component.tags, fn tag ->
      String.contains?(String.downcase(tag), query)
    end)
  end

  @doc """
  Returns the initial demo state map.
  """
  def initial_demo_state do
    %{
      button_clicks: 0,
      input_value: "",
      progress_value: 50,
      checkbox_checked: false,
      selected_menu_item: nil,
      modal_open: false,
      table_sort_column: nil,
      table_sort_direction: :asc
    }
  end
end
