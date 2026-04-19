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
          optional(:content) => String.t(),
          optional(:animation_hints) => [map()]
        }

  @doc """
  Convert a view tree map to a list of widget summaries.

  Each node retains `:type`, `:id`, `:content` (if text), and recursed
  `:children`. All callbacks and style details are stripped.
  """
  @spec from_view_tree(map() | list() | nil) :: [widget_summary()]
  def from_view_tree(nil), do: []

  def from_view_tree(nodes) when is_list(nodes),
    do: Enum.map(nodes, &summarize_node/1)

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
    children =
      case Map.get(node, :children) do
        nil -> []
        kids when is_list(kids) -> Enum.map(kids, &summarize_node/1)
        _ -> []
      end

    %{
      type: Map.get(node, :type, :unknown),
      id: Map.get(node, :id),
      children: children
    }
    |> maybe_put_content(Map.get(node, :content))
    |> maybe_put_hints(Map.get(node, :animation_hints))
  end

  defp summarize_node(_), do: %{type: :unknown, id: nil, children: []}

  defp maybe_put_content(summary, content) when is_binary(content),
    do: Map.put(summary, :content, content)

  defp maybe_put_content(summary, _), do: summary

  defp maybe_put_hints(summary, [_ | _] = hints) do
    case hints |> Enum.map(&serialize_hint/1) |> Enum.reject(&is_nil/1) do
      [] -> summary
      serialized -> Map.put(summary, :animation_hints, serialized)
    end
  end

  defp maybe_put_hints(summary, _), do: summary

  defp serialize_hint(%{type: :border_beam} = hint) do
    %{
      type: :border_beam,
      variant: Map.get(hint, :variant, :colorful),
      size: Map.get(hint, :size, :full),
      strength: Map.get(hint, :strength, 0.8),
      duration_ms: Map.get(hint, :duration_ms, 2000),
      brightness: Map.get(hint, :brightness, 1.3),
      saturation: Map.get(hint, :saturation, 1.2),
      hue_range: Map.get(hint, :hue_range, 30),
      active: Map.get(hint, :active, true),
      static_colors: Map.get(hint, :static_colors, false)
    }
  end

  defp serialize_hint(%{property: property} = hint) do
    %{
      property: property,
      duration_ms: Map.get(hint, :duration_ms, 300),
      easing: Map.get(hint, :easing, :ease_out_cubic),
      delay_ms: Map.get(hint, :delay_ms, 0)
    }
    |> maybe_put(:from, Map.get(hint, :from))
    |> maybe_put(:to, Map.get(hint, :to))
  end

  defp serialize_hint(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
