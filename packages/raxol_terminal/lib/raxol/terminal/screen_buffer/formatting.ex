defmodule Raxol.Terminal.ScreenBuffer.Formatting do
  @moduledoc false

  def init do
    %{
      current_style: %{
        foreground: :default,
        background: :default,
        attributes: MapSet.new()
      }
    }
  end

  def get_style(state) do
    state.current_style
  end

  def update_style(state, style) do
    %{state | current_style: Map.merge(state.current_style, style)}
  end

  def set_attribute(state, attribute) do
    attributes = MapSet.put(state.current_style.attributes, attribute)
    update_style(state, %{attributes: attributes})
  end

  def reset_attribute(state, attribute) do
    attributes = MapSet.delete(state.current_style.attributes, attribute)
    update_style(state, %{attributes: attributes})
  end

  def set_foreground(state, color) do
    update_style(state, %{foreground: color})
  end

  def set_background(state, color) do
    update_style(state, %{background: color})
  end

  def reset_all(_state) do
    init()
  end

  def get_foreground(state) do
    state.current_style.foreground
  end

  def get_background(state) do
    state.current_style.background
  end

  def attribute_set?(state, attribute) do
    MapSet.member?(state.current_style.attributes, attribute)
  end

  def get_set_attributes(state) do
    state.current_style.attributes
  end
end
