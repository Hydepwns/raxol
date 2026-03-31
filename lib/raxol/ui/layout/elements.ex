defmodule Raxol.UI.Layout.Elements do
  @moduledoc """
  Handles measurement of basic UI elements like text, labels, boxes, and checkboxes.
  """

  alias Raxol.UI.Layout.Engine, as: LayoutEngine

  @default_height 1
  @default_box_size 1
  # "[x] " prefix before label text
  @checkbox_prefix_width 4

  def measure(:text, attrs_map) do
    text = Map.get(attrs_map, :text, "")

    case LayoutEngine.lookup_prepared(:text, text) do
      {w, h} ->
        %{width: w, height: h}

      nil ->
        %{
          width: Raxol.UI.TextMeasure.display_width(text),
          height: @default_height
        }
    end
  end

  def measure(:label, attrs_map) do
    text = Map.get(attrs_map, :content, "")

    case LayoutEngine.lookup_prepared(:label, text) do
      {w, _h} ->
        %{width: w, height: @default_height}

      nil ->
        %{
          width: Raxol.UI.TextMeasure.display_width(text),
          height: @default_height
        }
    end
  end

  def measure(:box, attrs_map) do
    width = Map.get(attrs_map, :width, @default_box_size)
    height = Map.get(attrs_map, :height, @default_box_size)
    %{width: width, height: height}
  end

  def measure(:checkbox, attrs_map) do
    label = Map.get(attrs_map, :label, "")

    case LayoutEngine.lookup_prepared(:checkbox, label) do
      {w, _h} ->
        %{width: w, height: @default_height}

      nil ->
        %{
          width:
            @checkbox_prefix_width + Raxol.UI.TextMeasure.display_width(label),
          height: @default_height
        }
    end
  end
end
