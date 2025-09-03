defmodule Raxol.Renderer.Layout.Utils do
  @moduledoc """
  Provides utility functions for layout calculations.

  This module contains helper functions for:
  - Size calculations
  - Element normalization
  - Child processing
  - Panel layout utilities
  """

  @doc """
  Calculates the size of an element based on its size specification and available space.

  ## Parameters

  * `size` - The size specification (tuple, :auto, or other)
  * `space` - Available space for layout

  ## Returns

  A tuple {width, height} representing the calculated size.
  """
  def calculate_size({w, h}, _space) when is_integer(w) and is_integer(h),
    do: {max(0, w), max(0, h)}

  def calculate_size({w, :auto}, space) when is_integer(w),
    do: {max(0, w), max(0, space.height)}

  def calculate_size({:auto, h}, space) when is_integer(h),
    do: {max(0, space.width), max(0, h)}

  def calculate_size(:auto, space),
    do: {max(0, space.width), max(0, space.height)}

  def calculate_size(_, space), do: {max(0, space.width), max(0, space.height)}

  @doc """
  Ensures that an element has all required keys for processing.

  ## Parameters

  * `child` - The child element to normalize
  * `space` - Available space for layout
  * `default_type` - Default type to use if not specified

  ## Returns

  A normalized element with all required keys.
  """
  def ensure_required_keys(child, space, default_type \\ :box) do
    case child do
      %{type: type, position: position, size: size}
      when not is_nil(type) and not is_nil(position) and not is_nil(size) ->
        child

      %{type: type, position: position}
      when not is_nil(type) and not is_nil(position) ->
        Map.put(child, :size, {space.width, space.height})

      %{type: type, size: size} when not is_nil(type) and not is_nil(size) ->
        Map.put(child, :position, {space.x, space.y})

      %{type: type} when not is_nil(type) ->
        Map.merge(child, %{
          position: {space.x, space.y},
          size: {space.width, space.height}
        })

      %{position: position, size: size}
      when not is_nil(position) and not is_nil(size) ->
        Map.put(child, :type, default_type)

      %{position: position} when not is_nil(position) ->
        Map.merge(child, %{
          type: default_type,
          size: {space.width, space.height}
        })

      %{size: size} when not is_nil(size) ->
        Map.merge(child, %{
          type: default_type,
          position: {space.x, space.y}
        })

      _ ->
        Map.merge(child, %{
          type: default_type,
          position: {space.x, space.y},
          size: {space.width, space.height}
        })
    end
  end

  @doc """
  Normalizes a child element for layout processing.

  ## Parameters

  * `child` - The child element to normalize
  * `space` - Available space for layout
  * `default_type` - Default type to use if not specified
  * `is_root` - Whether this is a root element

  ## Returns

  A normalized child element or list of elements.
  """
  def deep_normalize_child(child, space, default_type, is_root) do
    case child do
      # Handle text, number, and atom types
      text when is_binary(text) ->
        normalize_text(child, space, default_type)

      number when is_number(number) ->
        normalize_number(child, space, default_type)

      atom when is_atom(atom) ->
        normalize_atom(child, space, default_type)

      # Handle list of children
      list when is_list(list) ->
        if is_root and length(list) == 1 do
          [first_child | _] = list
          deep_normalize_child(first_child, space, default_type, false)
        else
          Enum.flat_map(list, fn child_node ->
            case child_node do
              %{type: type} when not is_nil(type) ->
                [ensure_required_keys(child_node, space, type)]

              _ ->
                ensure_required_keys(child_node, space, default_type)
            end
          end)
        end

      # Handle map with type
      %{type: type} = child_map when not is_nil(type) ->
        [ensure_required_keys(child_map, space, type)]

      # Handle map without type
      child_map when is_map(child_map) ->
        [ensure_required_keys(child_map, space, default_type)]

      # Handle other types
      _other ->
        [ensure_required_keys(child, space, default_type)]
    end
  end

  @doc """
  Creates a default view when no valid view is provided.

  ## Parameters

  * `dimensions` - Terminal dimensions

  ## Returns

  A default view configuration.
  """
  def create_default_view(dimensions) do
    %{
      type: :box,
      position: {0, 0},
      size: {dimensions.width, dimensions.height},
      children: []
    }
  end

  @doc """
  Applies panel layout to available space.

  ## Parameters

  * `space` - Available space for layout
  * `attrs` - Panel attributes

  ## Returns

  Modified space for panel layout.
  """
  def apply_panel_layout(space, _attrs) do
    # This function would contain panel-specific layout logic
    # For now, return the space as-is
    space
  end

  @doc """
  Creates panel elements.

  ## Parameters

  * `space` - Available space for layout
  * `attrs` - Panel attributes

  ## Returns

  A list of panel elements.
  """
  def create_panel_elements(_space, _attrs) do
    # This function would create panel-specific elements
    # For now, return an empty list
    []
  end

  # Add normalization helpers for text, number, and atom
  defp normalize_text(child, space, _default_type) do
    [
      %{
        type: :text,
        content: child,
        position: {space.x, space.y},
        size: {space.width, 1}
      }
    ]
  end

  defp normalize_number(child, space, _default_type) do
    [
      %{
        type: :number,
        value: child,
        position: {space.x, space.y},
        size: {space.width, 1}
      }
    ]
  end

  defp normalize_atom(child, space, _default_type) do
    [
      %{
        type: :atom,
        value: child,
        position: {space.x, space.y},
        size: {space.width, 1}
      }
    ]
  end
end
