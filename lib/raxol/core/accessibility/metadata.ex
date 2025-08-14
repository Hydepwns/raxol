defmodule Raxol.Core.Accessibility.Metadata do
  
  @moduledoc """
  Handles accessibility metadata for UI elements and component styles.
  """

  @doc """
  Register metadata for an element to be used for accessibility features.

  ## Parameters

  * `element_id` - Unique identifier for the element
  * `metadata` - Metadata to associate with the element

  ## Examples

      iex> Metadata.register_element_metadata("search_button", %{label: "Search"})
      :ok
  """
  def register_element_metadata(element_id, metadata)
      when is_binary(element_id) and is_map(metadata) do
    # Delegate to the GenServer for metadata storage
    alias Raxol.Core.Accessibility.Server
    Server.register_element_metadata(element_id, metadata)
    :ok
  end

  @doc """
  Get metadata for an element.

  ## Parameters

  * `element_id` - Unique identifier for the element

  ## Returns

  * The metadata map for the element, or `nil` if not found

  ## Examples

      iex> Metadata.get_element_metadata("search_button")
      %{label: "Search"}
  """
  def get_element_metadata(element_id) when is_binary(element_id) do
    # Delegate to the GenServer for metadata retrieval
    alias Raxol.Core.Accessibility.Server
    Server.get_element_metadata(element_id)
  end

  @doc """
  Register style settings for a component type.

  ## Parameters

  * `component_type` - Atom representing the component type
  * `style` - Style map to associate with the component type

  ## Examples

      iex> Metadata.register_component_style(:button, %{background: :blue})
      :ok
  """
  def register_component_style(component_type, style)
      when is_atom(component_type) and is_map(style) do
    # Delegate to the GenServer for component style storage
    alias Raxol.Core.Accessibility.Server
    Server.register_component_style(component_type, style)
    :ok
  end

  @doc """
  Get style settings for a component type.

  ## Parameters

  * `component_type` - Atom representing the component type

  ## Returns

  * The style map for the component type, or empty map if not found

  ## Examples

      iex> Metadata.get_component_style(:button)
      %{background: :blue}
  """
  def get_component_style(component_type) when is_atom(component_type) do
    # Delegate to the GenServer for component style retrieval
    alias Raxol.Core.Accessibility.Server
    Server.get_component_style(component_type)
  end

  @doc """
  Get the accessible name for an element.

  ## Parameters

  * `element` - The element to get the accessible name for

  ## Returns

  * The accessible name as a string, or nil if not found

  ## Examples

      iex> Metadata.get_accessible_name("search_button")
      "Search"
  """
  def get_accessible_name(element) when is_binary(element) do
    # If element is a string ID, look up its metadata
    metadata = get_element_metadata(element)

    if metadata,
      do: safe_map_get(metadata, :label),
      else: nil
  end

  def get_accessible_name(%{label: label}) do
    # If element is a map with a label key, use that
    label
  end

  def get_accessible_name(%{id: id} = element) when not is_map_key(element, :label) do
    # If element has an ID but no label, try to get metadata by ID
    metadata = get_element_metadata(id)

    if metadata,
      do: safe_map_get(metadata, :label),
      else: nil
  end

  def get_accessible_name(_element) do
    # Default fallback
    "Focus changed"
  end

  def get_component_hint(component_id, hint_level) do
    "Hint for #{component_id} at level #{hint_level}"
  end

  defp safe_map_get(data, key, default \\ nil) do
    if is_map(data), do: Map.get(data, key, default), else: default
  end
end
