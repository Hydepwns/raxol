defmodule Raxol.UI.Layout.Elements do
  @moduledoc """
  Handles measurement of basic UI elements like text, labels, boxes, and checkboxes.
  """

  def measure(:text, attrs_map) do
    text = Map.get(attrs_map, :text, "")
    %{width: String.length(text), height: 1}
  end

  def measure(:label, attrs_map) do
    text = Map.get(attrs_map, :content, "")
    %{width: String.length(text), height: 1}
  end

  def measure(:box, attrs_map) do
    width = Map.get(attrs_map, :width, 1)
    height = Map.get(attrs_map, :height, 1)
    %{width: width, height: height}
  end

  def measure(:checkbox, attrs_map) do
    label = Map.get(attrs_map, :label, "")
    width = 4 + String.length(label)
    height = 1
    %{width: width, height: height}
  end
end
