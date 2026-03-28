defmodule Raxol.Agent.SemanticTree do
  @moduledoc """
  Transforms a raw view tree into a semantic tree for agent consumption.

  Strips layout-only keys (style, padding, margin, etc.) and keeps
  semantic content (value, selected, checked, items, etc.). Called
  on-demand from `Agent.Session` -- no GenServer, no caching.
  """

  @layout_keys ~w(style padding margin gap fg bg border position z_index size
                   direction align justify wrap on_click on_change on_toggle
                   on_submit)a

  @doc """
  Transforms a raw view tree into a semantic tree.

  Options:
    - `:focused_id` - element id to mark as focused
  """
  def from_view_tree(tree, opts \\ [])
  def from_view_tree(nil, _opts), do: nil

  def from_view_tree(tree, opts) when is_map(tree) do
    focused_id = Keyword.get(opts, :focused_id)
    transform(tree, focused_id)
  end

  @doc "Depth-first search by `:id`. Returns nil on miss."
  def find(nil, _id), do: nil
  def find(%{id: id} = node, target_id) when id == target_id, do: node

  def find(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, fn child -> find(child, target_id) end)
  end

  def find(_node, _id), do: nil

  @doc "Collect all nodes matching `:type`."
  def find_by_type(nil, _type), do: []

  def find_by_type(%{type: type} = node, target_type) do
    match = if type == target_type, do: [node], else: []
    children = Map.get(node, :children, [])
    match ++ Enum.flat_map(List.wrap(children), &find_by_type(&1, target_type))
  end

  def find_by_type(_node, _type), do: []

  @doc "Flatten all text content into a single string."
  def text_content(nil), do: ""

  def text_content(%{type: :text, content: content}) when is_binary(content) do
    content
  end

  def text_content(%{} = node) do
    own_text = Map.get(node, :content, "") |> to_string()

    child_text =
      node
      |> Map.get(:children, [])
      |> List.wrap()
      |> Enum.map_join(" ", &text_content/1)

    case {own_text, child_text} do
      {"", ""} -> ""
      {own, ""} -> own
      {"", child} -> child
      {own, child} -> own <> " " <> child
    end
  end

  def text_content(_), do: ""

  defp transform(%{} = node, focused_id) do
    node
    |> Map.drop(@layout_keys)
    |> maybe_add_focused(focused_id)
    |> transform_children(focused_id)
  end

  defp maybe_add_focused(%{id: id} = node, focused_id)
       when not is_nil(focused_id) do
    Map.put(node, :focused, id == focused_id)
  end

  defp maybe_add_focused(node, _), do: node

  defp transform_children(%{children: children} = node, focused_id)
       when is_list(children) do
    %{node | children: Enum.map(children, &transform(&1, focused_id))}
  end

  defp transform_children(node, _focused_id), do: node
end
