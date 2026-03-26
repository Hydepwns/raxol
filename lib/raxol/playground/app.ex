defmodule Raxol.Playground.App do
  @moduledoc """
  Terminal playground for Raxol widgets.

  Browse, interact with, and copy code for all playground-ready widgets.
  Launch with `mix raxol.playground` or `Raxol.start_link(Raxol.Playground.App, [])`.

  Controls:
    j/k or arrows  Navigate component list
    Enter          Select component
    Tab            Cycle focus (sidebar / demo)
    /              Search components
    c              Copy code snippet
    q or Ctrl+C    Quit
  """

  use Raxol.Core.Runtime.Application

  alias Raxol.Playground.Catalog

  @impl true
  def init(_context) do
    components = Catalog.list_components()

    %{
      components: components,
      cursor: 0,
      selected: List.first(components),
      focus: :sidebar,
      search: nil,
      show_code: false,
      demo_model: nil,
      copied: false
    }
    |> init_demo()
  end

  @impl true
  def update(message, model) do
    case message do
      # Quit
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}}
      when model.focus != :search ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{
        type: :key,
        data: %{key: :char, char: "c", ctrl: true}
      } ->
        {model, [command(:quit)]}

      # Tab: cycle focus
      %Raxol.Core.Events.Event{type: :key, data: %{key: :tab}} ->
        {cycle_focus(model), []}

      # Sidebar navigation
      %Raxol.Core.Events.Event{type: :key, data: %{key: key}}
      when key in [:up, :down] and model.focus == :sidebar ->
        delta = if key == :up, do: -1, else: 1
        {move_cursor(model, delta), []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: ch}}
      when ch in ["j", "k"] and model.focus == :sidebar ->
        delta = if ch == "k", do: -1, else: 1
        {move_cursor(model, delta), []}

      # Enter: select component
      %Raxol.Core.Events.Event{type: :key, data: %{key: :enter}}
      when model.focus == :sidebar ->
        {select_current(model), []}

      # Toggle code panel
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "c"}}
      when model.focus != :search ->
        {%{model | show_code: not model.show_code, copied: false}, []}

      # Search mode
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "/"}}
      when model.focus != :search ->
        {%{model | focus: :search, search: ""}, []}

      # Search: type characters
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: ch}}
      when model.focus == :search ->
        new_search = (model.search || "") <> ch
        filtered = Catalog.filter(search: new_search)
        {%{model | search: new_search, components: filtered, cursor: 0}, []}

      # Search: backspace
      %Raxol.Core.Events.Event{type: :key, data: %{key: :backspace}}
      when model.focus == :search ->
        new_search = String.slice(model.search || "", 0..-2//1)

        filtered =
          if new_search == "",
            do: Catalog.list_components(),
            else: Catalog.filter(search: new_search)

        {%{model | search: new_search, components: filtered, cursor: 0}, []}

      # Search: escape or enter exits search
      %Raxol.Core.Events.Event{type: :key, data: %{key: key}}
      when key in [:escape, :enter] and model.focus == :search ->
        {%{model | focus: :sidebar}, []}

      # Forward events to demo when focused
      event when model.focus == :demo and model.selected != nil ->
        forward_to_demo(model, event)

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    column style: %{gap: 0} do
      [
        header(),
        divider(),
        row style: %{gap: 0} do
          [
            sidebar(model),
            divider(char: "|"),
            demo_area(model)
          ]
        end,
        divider(),
        footer(model)
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []

  # -- Layout sections --

  defp header do
    row style: %{gap: 2} do
      [
        text("Raxol Playground", style: [:bold]),
        text("-- browse, interact, copy", style: [:dim])
      ]
    end
  end

  defp sidebar(model) do
    items =
      model.components
      |> Enum.with_index()
      |> Enum.map(fn {comp, idx} ->
        prefix = if idx == model.cursor, do: "> ", else: "  "
        style = if idx == model.cursor, do: [:bold], else: []
        text(prefix <> comp.name, style: style)
      end)

    search_line =
      if model.focus == :search do
        text("/ #{model.search || ""}_")
      else
        text("")
      end

    box style: %{width: 22, padding: 1} do
      column style: %{gap: 0} do
        [
          text("Components", style: [:bold, :underline]),
          search_line | items
        ]
      end
    end
  end

  defp demo_area(model) do
    case model.selected do
      nil ->
        box style: %{padding: 2} do
          text("Select a component from the sidebar.")
        end

      comp ->
        column style: %{gap: 1, padding: 1} do
          [
            demo_header(comp),
            divider(),
            demo_content(model),
            if model.show_code do
              code_panel(comp)
            else
              text("")
            end
          ]
        end
    end
  end

  defp demo_header(comp) do
    complexity_label =
      case comp.complexity do
        :basic -> "basic"
        :intermediate -> "intermediate"
        :advanced -> "advanced"
      end

    row style: %{gap: 2} do
      [
        text(comp.name, style: [:bold]),
        text("[#{complexity_label}]", style: [:dim]),
        text(comp.description, style: [:dim])
      ]
    end
  end

  defp demo_content(model) do
    case model.demo_model do
      nil ->
        text("(no demo loaded)")

      demo_model ->
        model.selected.module.view(demo_model)
    end
  end

  defp code_panel(comp) do
    column style: %{gap: 0} do
      [
        divider(),
        text("Code:", style: [:bold]),
        box style: %{border: :single, padding: 1} do
          text(String.trim(comp.code_snippet))
        end
      ]
    end
  end

  defp footer(model) do
    focus_indicator =
      case model.focus do
        :sidebar -> "[sidebar]"
        :demo -> "[demo]"
        :search -> "[search]"
      end

    row style: %{gap: 2} do
      [
        text(focus_indicator, style: [:bold]),
        text(
          "[j/k] nav  [Enter] select  [Tab] focus  [c] code  [/] search  [q] quit",
          style: [:dim]
        )
      ]
    end
  end

  # -- State helpers --

  defp init_demo(model) do
    case model.selected do
      nil ->
        %{model | demo_model: nil}

      comp ->
        demo_model = comp.module.init(nil)
        %{model | demo_model: demo_model}
    end
  end

  defp move_cursor(model, delta) do
    max_idx = length(model.components) - 1
    new_cursor = max(0, min(model.cursor + delta, max_idx))
    %{model | cursor: new_cursor}
  end

  defp select_current(model) do
    case Enum.at(model.components, model.cursor) do
      nil ->
        model

      comp ->
        demo_model = comp.module.init(nil)
        %{model | selected: comp, demo_model: demo_model, focus: :demo}
    end
  end

  defp cycle_focus(%{focus: :sidebar} = model), do: %{model | focus: :demo}
  defp cycle_focus(%{focus: :demo} = model), do: %{model | focus: :sidebar}
  defp cycle_focus(%{focus: :search} = model), do: %{model | focus: :sidebar}

  defp forward_to_demo(model, event) do
    case model.selected.module.update(event, model.demo_model) do
      {new_demo_model, _commands} ->
        {%{model | demo_model: new_demo_model}, []}

      new_demo_model when is_map(new_demo_model) ->
        {%{model | demo_model: new_demo_model}, []}
    end
  end
end
