defmodule Raxol.Playground.Catalog do
  @moduledoc """
  Single source of truth for Raxol's widget catalog.

  Provides metadata, demo modules, and code snippets for all playground-ready
  widgets. Used by the terminal playground, web playground, and SSH playground.
  """

  alias Raxol.Playground.Demos

  @type component :: %{
          name: String.t(),
          module: module(),
          category: atom(),
          description: String.t(),
          complexity: :basic | :intermediate | :advanced,
          tags: [String.t()],
          code_snippet: String.t()
        }

  @components [
    %{
      name: "Button",
      module: Demos.ButtonDemo,
      category: :input,
      description: "Interactive button with click handling",
      complexity: :basic,
      tags: ["input", "interactive", "click"],
      code_snippet: """
      button("Click Me", on_click: :clicked)
      button("Submit", on_click: :submit, style: [:bold])
      """
    },
    %{
      name: "TextInput",
      module: Demos.TextInputDemo,
      category: :input,
      description: "Single-line text input with placeholder",
      complexity: :basic,
      tags: ["input", "form", "text"],
      code_snippet: """
      text_input(value: model.name, placeholder: "Enter name...")
      """
    },
    %{
      name: "Table",
      module: Demos.TableDemo,
      category: :display,
      description: "Data table with sortable columns and row selection",
      complexity: :intermediate,
      tags: ["data", "display", "sorting", "rows"],
      code_snippet: """
      table(
        headers: ["Name", "Language", "Stars"],
        rows: [
          ["Raxol", "Elixir", "500"],
          ["Ratatui", "Rust", "19k"],
          ["Bubble Tea", "Go", "39k"]
        ]
      )
      """
    },
    %{
      name: "Progress",
      module: Demos.ProgressDemo,
      category: :feedback,
      description: "Progress bar with value tracking",
      complexity: :basic,
      tags: ["feedback", "loading", "progress"],
      code_snippet: """
      progress(value: 65, max: 100)
      """
    },
    %{
      name: "Modal",
      module: Demos.ModalDemo,
      category: :overlay,
      description: "Modal dialog with title and content",
      complexity: :intermediate,
      tags: ["overlay", "dialog", "focus"],
      code_snippet: """
      modal(
        title: "Confirm",
        content: text("Are you sure?"),
        visible: model.show_modal
      )
      """
    },
    %{
      name: "Menu",
      module: Demos.MenuDemo,
      category: :navigation,
      description: "Selectable menu with keyboard navigation",
      complexity: :intermediate,
      tags: ["navigation", "keyboard", "selection"],
      code_snippet: """
      list(
        items: ["File", "Edit", "View", "Help"],
        selected: model.selected
      )
      """
    }
  ]

  @doc "Returns all playground components."
  @spec list_components() :: [component()]
  def list_components, do: @components

  @doc "Returns a component by name."
  @spec get_component(String.t()) :: component() | nil
  def get_component(name) do
    Enum.find(@components, &(&1.name == name))
  end

  @doc "Returns unique categories in display order."
  @spec list_categories() :: [atom()]
  def list_categories do
    @components
    |> Enum.map(& &1.category)
    |> Enum.uniq()
  end

  @doc "Filters components by keyword options."
  @spec filter(keyword()) :: [component()]
  def filter(opts \\ []) do
    @components
    |> filter_by_category(opts[:category])
    |> filter_by_complexity(opts[:complexity])
    |> filter_by_search(opts[:search])
  end

  defp filter_by_category(components, nil), do: components

  defp filter_by_category(components, category) do
    Enum.filter(components, &(&1.category == category))
  end

  defp filter_by_complexity(components, nil), do: components

  defp filter_by_complexity(components, complexity) do
    Enum.filter(components, &(&1.complexity == complexity))
  end

  defp filter_by_search(components, nil), do: components
  defp filter_by_search(components, ""), do: components

  defp filter_by_search(components, query) do
    q = String.downcase(query)

    Enum.filter(components, fn c ->
      String.contains?(String.downcase(c.name), q) or
        String.contains?(String.downcase(c.description), q) or
        Enum.any?(c.tags, &String.contains?(&1, q))
    end)
  end
end
