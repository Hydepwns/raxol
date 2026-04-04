defmodule Raxol.Playground.Demos.TreeDemo do
  @moduledoc "Playground demo: expandable tree view with keyboard navigation."
  use Raxol.Core.Runtime.Application
  alias Raxol.Playground.DemoHelpers

  @indent "  "

  @tree [
    %{
      name: "src",
      children: [
        %{name: "app.ex", children: []},
        %{
          name: "lib",
          children: [
            %{name: "utils.ex", children: []},
            %{name: "core.ex", children: []}
          ]
        }
      ]
    },
    %{
      name: "test",
      children: [
        %{name: "test_helper.exs", children: []}
      ]
    },
    %{name: "mix.exs", children: []},
    %{name: "README.md", children: []}
  ]

  @impl true
  def init(_context) do
    %{expanded: MapSet.new(), cursor: 0}
  end

  @impl true
  def update(message, model) do
    visible = flatten_visible(@tree, model.expanded)
    apply_key(message, model, visible)
  end

  defp apply_key(key_match("j"), model, visible) do
    max_idx = max(length(visible) - 1, 0)
    {%{model | cursor: DemoHelpers.cursor_down(model.cursor, max_idx)}, []}
  end

  defp apply_key(key_match("k"), model, _visible) do
    {%{model | cursor: DemoHelpers.cursor_up(model.cursor)}, []}
  end

  defp apply_key(key_match("l"), model, visible),
    do: {expand_current(model, visible), []}

  defp apply_key(key_match(:right), model, visible),
    do: {expand_current(model, visible), []}

  defp apply_key(key_match("h"), model, visible),
    do: {collapse_current(model, visible), []}

  defp apply_key(key_match(:left), model, visible),
    do: {collapse_current(model, visible), []}

  defp apply_key(key_match("e"), model, _visible) do
    {%{model | expanded: all_dir_names(@tree)}, []}
  end

  defp apply_key(key_match("c"), model, _visible) do
    {%{model | expanded: MapSet.new(), cursor: 0}, []}
  end

  defp apply_key(_message, model, _visible), do: {model, []}

  @impl true
  def view(model) do
    visible = flatten_visible(@tree, model.expanded)
    lines = Enum.map(Enum.with_index(visible), &render_node(&1, model))

    column style: %{gap: 1} do
      [
        text("Tree Demo", style: [:bold]),
        divider(),
        column style: %{gap: 0} do
          lines
        end,
        divider(),
        text(
          "Nodes: #{length(visible)}  Expanded: #{MapSet.size(model.expanded)}"
        ),
        text(
          "[j/k] navigate  [h/l] collapse/expand  [e] expand all  [c] collapse all",
          style: [:dim]
        )
      ]
    end
  end

  defp render_node({{node, depth, has_children}, idx}, model) do
    indent = String.duplicate(@indent, depth)

    prefix =
      node_prefix(has_children, MapSet.member?(model.expanded, node.name))

    style = if idx == model.cursor, do: [:bold], else: []
    marker = if idx == model.cursor, do: "*", else: " "
    text(marker <> indent <> prefix <> node.name, style: style)
  end

  defp node_prefix(true, true), do: "v "
  defp node_prefix(true, false), do: "> "
  defp node_prefix(false, _), do: "  "

  @impl true
  def subscribe(_model), do: []

  defp flatten_visible(nodes, expanded) do
    flatten_visible(nodes, expanded, 0)
  end

  defp flatten_visible(nodes, expanded, depth) do
    Enum.flat_map(nodes, fn node ->
      has_children = node.children != []
      entry = {node, depth, has_children}

      if has_children and MapSet.member?(expanded, node.name) do
        [entry | flatten_visible(node.children, expanded, depth + 1)]
      else
        [entry]
      end
    end)
  end

  defp expand_current(model, visible) do
    case Enum.at(visible, model.cursor) do
      {node, _, true} ->
        %{model | expanded: MapSet.put(model.expanded, node.name)}

      _ ->
        model
    end
  end

  defp collapse_current(model, visible) do
    case Enum.at(visible, model.cursor) do
      {node, _, true} ->
        %{model | expanded: MapSet.delete(model.expanded, node.name)}

      _ ->
        model
    end
  end

  defp all_dir_names(nodes) do
    Enum.reduce(nodes, MapSet.new(), fn node, acc ->
      if node.children != [] do
        acc
        |> MapSet.put(node.name)
        |> MapSet.union(all_dir_names(node.children))
      else
        acc
      end
    end)
  end
end
