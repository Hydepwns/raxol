defmodule Raxol.UI.Layout.Inputs do
  @moduledoc '''
  Handles measurement of input elements like buttons and text inputs.
  '''

  def measure(:button, attrs_map, available_space) do
    text = Map.get(attrs_map, :label, "Button")
    padding = 4
    width = min(String.length(text) + padding, available_space.width)
    height = 3
    %{width: width, height: height}
  end

  def measure(:text_input, attrs_map, available_space) do
    value = Map.get(attrs_map, :value, "")
    placeholder = Map.get(attrs_map, :placeholder, "")
    display_text = if value == "", do: placeholder, else: value
    padding = 4
    width = min(String.length(display_text) + padding, available_space.width)
    height = 3
    %{width: width, height: height}
  end
end
