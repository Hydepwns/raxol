defmodule Raxol.MCP.StructuredScreenshot do
  @moduledoc """
  Converts a view tree into a clean, JSON-friendly widget summary.

  Used by the `raxol_screenshot` MCP tool to return structured content
  alongside the plain text capture. Strips callbacks and normalizes
  widget nodes to a consistent shape.
  """

  @type widget_summary :: %{
          required(:type) => atom(),
          required(:id) => String.t() | nil,
          required(:children) => [widget_summary()],
          optional(:content) => String.t()
        }

  @doc """
  Convert a view tree map to a list of widget summaries.

  Each node retains `:type`, `:id`, `:content` (if text), and recursed
  `:children`. All callbacks and style details are stripped.
  """
  @spec from_view_tree(map() | list() | nil) :: [widget_summary()]
  def from_view_tree(nil), do: []
  def from_view_tree(nodes) when is_list(nodes), do: Enum.map(nodes, &summarize_node/1)
  def from_view_tree(node) when is_map(node), do: [summarize_node(node)]

  @doc """
  Encode a widget summary list to a JSON string.
  """
  @spec to_json([widget_summary()]) :: String.t()
  def to_json(summaries) do
    case Jason.encode(summaries, pretty: true) do
      {:ok, json} -> json
      {:error, _} -> "[]"
    end
  end

  # -- Private -----------------------------------------------------------------

  defp summarize_node(node) when is_map(node) do
    base = %{
      type: Map.get(node, :type, :unknown),
      id: Map.get(node, :id)
    }

    base =
      case Map.get(node, :content) do
        nil -> base
        content when is_binary(content) -> Map.put(base, :content, content)
        _ -> base
      end

    children =
      case Map.get(node, :children) do
        nil -> []
        kids when is_list(kids) -> Enum.map(kids, &summarize_node/1)
        _ -> []
      end

    Map.put(base, :children, children)
  end

  defp summarize_node(_), do: %{type: :unknown, id: nil, children: []}
end
