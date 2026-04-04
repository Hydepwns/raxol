defmodule Raxol.Playground.Demos.MenuDemo do
  @moduledoc "Playground demo: selectable menu with keyboard navigation."
  use Raxol.Core.Runtime.Application
  alias Raxol.Playground.DemoHelpers

  @items ["File", "Edit", "View", "Tools", "Help"]
  @info_box_width 35
  @submenu_width 20

  @sub_menus %{
    "File" => ["New", "Open", "Save", "Save As", "Exit"],
    "Edit" => ["Undo", "Redo", "Cut", "Copy", "Paste"],
    "View" => ["Sidebar", "Terminal", "Minimap", "Fullscreen"],
    "Tools" => ["Extensions", "Settings", "Keybindings"],
    "Help" => ["About", "Docs", "Report Issue"]
  }

  @impl true
  def init(_context) do
    %{selected: 0, sub_selected: 0, expanded: false}
  end

  @impl true
  def update(message, model) do
    case message do
      key_match("h") ->
        {move_menu(model, -1), []}

      key_match(:left) ->
        {move_menu(model, -1), []}

      key_match("l") ->
        {move_menu(model, 1), []}

      key_match(:right) ->
        {move_menu(model, 1), []}

      key_match(:enter) ->
        {%{model | expanded: not model.expanded, sub_selected: 0}, []}

      _ ->
        handle_sub_or_passthrough(message, model)
    end
  end

  defp handle_sub_or_passthrough(message, %{expanded: true} = model) do
    case message do
      key_match("j") -> {sub_menu_down(model), []}
      key_match(:down) -> {sub_menu_down(model), []}
      key_match("k") -> {sub_menu_up(model), []}
      key_match(:up) -> {sub_menu_up(model), []}
      key_match(:escape) -> {%{model | expanded: false}, []}
      _ -> {model, []}
    end
  end

  defp handle_sub_or_passthrough(_message, model), do: {model, []}

  defp sub_menu_down(model) do
    items = current_sub_items(model)

    %{
      model
      | sub_selected:
          DemoHelpers.cursor_down(model.sub_selected, length(items) - 1)
    }
  end

  defp sub_menu_up(model) do
    %{model | sub_selected: DemoHelpers.cursor_up(model.sub_selected)}
  end

  @impl true
  def view(model) do
    column style: %{gap: 1} do
      [
        text("Menu Demo", style: [:bold]),
        divider(),
        menu_bar(model),
        if model.expanded do
          sub_menu(model)
        else
          text("")
        end,
        divider(),
        box style: %{border: :single, padding: 1, width: @info_box_width} do
          column style: %{gap: 0} do
            [
              text("Menu: #{current_item(model)}", style: [:bold]),
              if model.expanded do
                text("Item: #{current_sub_item(model)}")
              else
                text("(press Enter to expand)")
              end
            ]
          end
        end,
        text("[h/l] menu  [j/k] items  [Enter] expand  [Esc] close",
          style: [:dim]
        )
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []

  defp menu_bar(model) do
    items =
      @items
      |> Enum.with_index()
      |> Enum.map(fn {item, idx} ->
        label = " #{item} "

        if idx == model.selected do
          text(label, style: [:bold, :underline])
        else
          text(label)
        end
      end)

    row style: %{gap: 0} do
      items
    end
  end

  defp sub_menu(model) do
    items = current_sub_items(model)

    rendered =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, idx} ->
        prefix = DemoHelpers.cursor_prefix(idx, model.sub_selected)
        style = if idx == model.sub_selected, do: [:bold], else: []
        text(prefix <> item, style: style)
      end)

    box style: %{border: :single, padding: 1, width: @submenu_width} do
      column style: %{gap: 0} do
        rendered
      end
    end
  end

  defp current_item(model), do: Enum.at(@items, model.selected)

  defp current_sub_items(model) do
    Map.get(@sub_menus, current_item(model), [])
  end

  defp current_sub_item(model) do
    Enum.at(current_sub_items(model), model.sub_selected, "")
  end

  defp move_menu(model, delta) do
    new_idx = rem(model.selected + delta + length(@items), length(@items))
    %{model | selected: new_idx, sub_selected: 0}
  end
end
