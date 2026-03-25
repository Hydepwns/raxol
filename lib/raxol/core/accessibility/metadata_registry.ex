defmodule Raxol.Core.Accessibility.MetadataRegistry do
  @moduledoc """
  Pure-functional helpers for accessibility metadata and component style
  registration within the AccessibilityServer state.
  """

  @doc "Puts element/component metadata into state."
  def put_metadata(state, component_id, metadata) do
    %{state | metadata: Map.put(state.metadata, component_id, metadata)}
  end

  @doc "Gets element/component metadata from state."
  def get_metadata(state, component_id) do
    Map.get(state.metadata, component_id)
  end

  @doc "Removes element/component metadata from state."
  def remove_metadata(state, component_id) do
    %{state | metadata: Map.delete(state.metadata, component_id)}
  end

  @doc "Registers a component style keyed by `{:component_style, type}`."
  def register_component_style(state, component_type, style) do
    key = {:component_style, component_type}
    %{state | metadata: Map.put(state.metadata, key, style)}
  end

  @doc "Gets a component style keyed by `{:component_style, type}`."
  def get_component_style(state, component_type) do
    Map.get(state.metadata, {:component_style, component_type}, %{})
  end

  @doc "Unregisters a component style."
  def unregister_component_style(state, component_type) do
    %{state | metadata: Map.delete(state.metadata, {:component_style, component_type})}
  end
end
