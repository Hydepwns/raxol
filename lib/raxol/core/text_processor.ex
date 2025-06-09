defmodule Raxol.Core.TextProcessor do
  @moduledoc """
  Handles text processing and formatting for UI elements.
  """

  @doc """
  Processes a text element map and returns a processed version with proper formatting.
  """
  def process_text_element(text_map, space) do
    text = Map.get(text_map, :text, "")
    style = Map.get(text_map, :style, %{})

    # Calculate text dimensions
    width = String.length(text)
    height = 1

    # Ensure text fits within space
    width = min(width, space.width)

    # Create processed text map
    Map.merge(text_map, %{
      text: text,
      style: style,
      width: width,
      height: height
    })
  end
end
