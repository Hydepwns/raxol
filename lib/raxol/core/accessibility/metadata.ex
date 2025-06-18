defmodule Raxol.Core.Accessibility.Metadata do
  @moduledoc '''
  Handles accessibility metadata for UI elements and component styles.
  '''

  @doc '''
  Register metadata for an element to be used for accessibility features.

  ## Parameters

  * `element_id` - Unique identifier for the element
  * `metadata` - Metadata to associate with the element

  ## Examples

      iex> Metadata.register_element_metadata("search_button", %{label: "Search"})
      :ok
  '''
  def register_element_metadata(element_id, metadata)
      when is_binary(element_id) and is_map(metadata) do
    # Store the metadata in process dictionary for simplicity
    element_metadata = Process.get(:accessibility_element_metadata) || %{}
    updated_metadata = Map.put(element_metadata, element_id, metadata)
    Process.put(:accessibility_element_metadata, updated_metadata)
    :ok
  end

  @doc '''
  Get metadata for an element.

  ## Parameters

  * `element_id` - Unique identifier for the element

  ## Returns

  * The metadata map for the element, or `nil` if not found

  ## Examples

      iex> Metadata.get_element_metadata("search_button")
      %{label: "Search"}
  '''
  def get_element_metadata(element_id) when is_binary(element_id) do
    element_metadata = Process.get(:accessibility_element_metadata) || %{}
    Map.get(element_metadata, element_id)
  end

  @doc '''
  Register style settings for a component type.

  ## Parameters

  * `component_type` - Atom representing the component type
  * `style` - Style map to associate with the component type

  ## Examples

      iex> Metadata.register_component_style(:button, %{background: :blue})
      :ok
  '''
  def register_component_style(component_type, style)
      when is_atom(component_type) and is_map(style) do
    # Store the component styles in process dictionary for simplicity
    component_styles = Process.get(:accessibility_component_styles) || %{}
    updated_styles = Map.put(component_styles, component_type, style)
    Process.put(:accessibility_component_styles, updated_styles)
    :ok
  end

  @doc '''
  Get style settings for a component type.

  ## Parameters

  * `component_type` - Atom representing the component type

  ## Returns

  * The style map for the component type, or empty map if not found

  ## Examples

      iex> Metadata.get_component_style(:button)
      %{background: :blue}
  '''
  def get_component_style(component_type) when is_atom(component_type) do
    component_styles = Process.get(:accessibility_component_styles) || %{}
    Map.get(component_styles, component_type, %{})
  end

  @doc '''
  Get the accessible name for an element.

  ## Parameters

  * `element` - The element to get the accessible name for

  ## Returns

  * The accessible name as a string, or nil if not found

  ## Examples

      iex> Metadata.get_accessible_name("search_button")
      "Search"
  '''
  def get_accessible_name(element) do
    cond do
      is_binary(element) ->
        # If element is a string ID, look up its metadata
        metadata = get_element_metadata(element)

        if metadata,
          do: safe_map_get(metadata, :label) || "Element #{element}",
          else: nil

      is_map(element) && Map.has_key?(element, :label) ->
        # If element is a map with a label key, use that
        element.label

      is_map(element) && Map.has_key?(element, :id) ->
        # If element has an ID, try to get metadata by ID
        metadata = get_element_metadata(element.id)

        if metadata,
          do: safe_map_get(metadata, :label) || "Element #{element.id}",
          else: nil

      true ->
        # Default fallback
        "Focus changed"
    end
  end

  defp safe_map_get(data, key, default \\ nil) do
    if is_map(data), do: Map.get(data, key, default), else: default
  end
end
