defmodule Raxol.UI.Layout.Elements do
  @moduledoc """
  Handles measurement of basic UI elements like text, labels, boxes, and checkboxes.
  """

  @default_height 1
  @default_box_size 1
  # "[x] " prefix before label text
  @checkbox_prefix_width 4

  def measure(:text, attrs_map) do
    text = Map.get(attrs_map, :text, "")
    %{width: String.length(text), height: @default_height}
  end

  def measure(:label, attrs_map) do
    text = Map.get(attrs_map, :content, "")
    %{width: String.length(text), height: @default_height}
  end

  def measure(:box, attrs_map) do
    width = Map.get(attrs_map, :width, @default_box_size)
    height = Map.get(attrs_map, :height, @default_box_size)
    %{width: width, height: height}
  end

  def measure(:checkbox, attrs_map) do
    label = Map.get(attrs_map, :label, "")

    %{
      width: @checkbox_prefix_width + String.length(label),
      height: @default_height
    }
  end
end
