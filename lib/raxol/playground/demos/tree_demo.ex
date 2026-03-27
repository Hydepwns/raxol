defmodule Raxol.Playground.Demos.TreeDemo do
  @moduledoc "Playground demo: expandable tree view with keyboard navigation."
  use Raxol.Core.Runtime.Application

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
    max_idx = max(length(visible) - 1, 0)

    case message do
      key_match("j") ->
        {%{model | cursor: min(model.cursor + 1, max_idx)}, []}

      key_match("k") ->
        {%{model | cursor: max(model.cursor - 1, 0)}, []}

      key_match("l") ->
        {expand_current(model, visible), []}

      key_match(:right) ->
        {expand_current(model, visible), []}

      key_match("h") ->
        {collapse_current(model, visible), []}

      key_match(:left) ->
        {collapse_current(model, visible), []}

      key_match("e") ->
        {%{model | expanded: all_dir_names(@tree)}, []}

      key_match("c") ->
        {%{model | expanded: MapSet.new(), cursor: 0}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    visible = flatten_visible(@tree, model.expanded)

    lines =
      visible
      |> Enum.with_index()
      |> Enum.map(fn {{node, depth, has_children}, idx} ->
        indent = String.duplicate("  ", depth)

        prefix =
          cond do
            has_children and MapSet.member?(model.expanded, node.name) -> "v "
            has_children -> "> "
            true -> "  "
          end

        style = if idx == model.cursor, do: [:bold], else: []
        marker = if idx == model.cursor, do: "*", else: " "
        text(marker <> indent <> prefix <> node.name, style: style)
      end)

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
