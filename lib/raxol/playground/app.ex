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
    f              Cycle category filter
    x              Cycle complexity filter
    c              Toggle code snippet
    ?              Help overlay
    q or Ctrl+C    Quit
  """

  use Raxol.Core.Runtime.Application

  alias Raxol.Playground.Catalog

  @categories [nil] ++ Catalog.list_categories()
  @complexities [nil, :basic, :intermediate, :advanced]

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
      copied: false,
      category_filter: nil,
      complexity_filter: nil,
      show_help: false
    }
    |> init_demo()
  end

  @impl true
  def update(message, model) do
    case message do
      # Help overlay: ? or Escape dismisses, everything else swallowed
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "?"}}
      when model.show_help ->
        {%{model | show_help: false}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :escape}}
      when model.show_help ->
        {%{model | show_help: false}, []}

      _ when model.show_help ->
        {model, []}

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

      # Toggle help overlay
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "?"}}
      when model.focus != :search ->
        {%{model | show_help: true}, []}

      # Category filter
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "f"}}
      when model.focus != :search ->
        {cycle_filter(model, :category_filter, @categories), []}

      # Complexity filter
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "x"}}
      when model.focus != :search ->
        {cycle_filter(model, :complexity_filter, @complexities), []}

      # Search mode
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "/"}}
      when model.focus != :search ->
        {%{model | focus: :search, search: ""}, []}

      # Search: type characters
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: ch}}
      when model.focus == :search ->
        new_search = (model.search || "") <> ch
        {refilter(%{model | search: new_search}), []}

      # Search: backspace
      %Raxol.Core.Events.Event{type: :key, data: %{key: :backspace}}
      when model.focus == :search ->
        new_search = String.slice(model.search || "", 0..-2//1)
        {refilter(%{model | search: new_search}), []}

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
    if model.show_help do
      help_overlay(model)
    else
      main_view(model)
    end
  end

  @impl true
  def subscribe(_model), do: []

  # -- Layout sections --

  defp main_view(model) do
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

  defp header do
    row style: %{gap: 2} do
      [
        text("Raxol Playground", style: [:bold]),
        text("-- browse, interact, copy", style: [:dim])
      ]
    end
  end

  defp sidebar(model) do
    filter_line = filter_indicator(model)

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
          filter_line,
          search_line | items
        ]
      end
    end
  end

  defp filter_indicator(model) do
    parts =
      [
        if(model.category_filter, do: "cat:#{model.category_filter}"),
        if(model.complexity_filter, do: "lvl:#{model.complexity_filter}")
      ]
      |> Enum.reject(&is_nil/1)

    case parts do
      [] -> text("")
      _ -> text(Enum.join(parts, " "), style: [:dim])
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

  defp help_overlay(model) do
    column style: %{gap: 0} do
      [
        header(),
        divider(),
        box style: %{padding: 2, border: :single} do
          column style: %{gap: 1} do
            [
              text("Keybindings", style: [:bold, :underline]),
              text(""),
              text("  j / k / Up / Down   Navigate sidebar"),
              text("  Enter               Select component"),
              text("  Tab                 Cycle focus (sidebar / demo)"),
              text("  /                   Search components"),
              text("  f                   Cycle category filter"),
              text("  x                   Cycle complexity filter"),
              text("  c                   Toggle code snippet"),
              text("  ?                   Toggle this help"),
              text("  q / Ctrl+C          Quit"),
              text(""),
              filter_status(model),
              text(""),
              text("Press ? or Escape to close.", style: [:dim])
            ]
          end
        end
      ]
    end
  end

  defp filter_status(model) do
    cat = if model.category_filter, do: "#{model.category_filter}", else: "all"

    cplx =
      if model.complexity_filter, do: "#{model.complexity_filter}", else: "all"

    text("  Filters: category=#{cat}  complexity=#{cplx}", style: [:dim])
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
          "[j/k] nav  [Tab] focus  [f] filter  [x] level  [c] code  [/] search  [?] help  [q] quit",
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

  defp cycle_filter(model, field, values) do
    current = Map.get(model, field)
    idx = Enum.find_index(values, &(&1 == current)) || 0
    next = Enum.at(values, rem(idx + 1, length(values)))
    refilter(%{model | field => next})
  end

  defp refilter(model) do
    search = if model.search == "", do: nil, else: model.search

    components =
      Catalog.filter(
        category: model.category_filter,
        complexity: model.complexity_filter,
        search: search
      )

    %{model | components: components, cursor: 0}
  end

  defp forward_to_demo(model, event) do
    {new_demo_model, _commands} = model.selected.module.update(event, model.demo_model)
    {%{model | demo_model: new_demo_model}, []}
  end
end
