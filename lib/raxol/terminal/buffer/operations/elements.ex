defmodule Raxol.Terminal.Buffer.Operations.Elements do
  @moduledoc """
  Element manipulation operations for the terminal buffer.

  Provides functions for moving, resizing, and modifying visual properties
  of UI elements in the terminal buffer for Svelte transitions and animations.
  """

  alias Raxol.Terminal.Buffer.Operations.{Utils, Text}

  @doc """
  Moves an element to a new position in the terminal buffer.

  ## Parameters
  - element: The element to move (must have :x, :y properties)
  - new_x: New X coordinate
  - new_y: New Y coordinate

  ## Returns
  Updated element with new position
  """
  def move_element(element, new_x, new_y)
      when is_map(element) and is_integer(new_x) and is_integer(new_y) do
    # Clear element from old position
    clear_element_at_position(element)

    # Update element position
    updated_element =
      element
      |> Map.put(:x, new_x)
      |> Map.put(:y, new_y)

    # Render element at new position
    render_element_at_position(updated_element)

    updated_element
  end

  @doc """
  Sets the opacity of an element in the terminal buffer.

  ## Parameters
  - element: The element to modify
  - opacity: Opacity value between 0.0 (transparent) and 1.0 (opaque)

  ## Returns
  Updated element with new opacity
  """
  def set_element_opacity(element, opacity)
      when is_map(element) and is_number(opacity) and opacity >= 0.0 and
             opacity <= 1.0 do
    updated_element = Map.put(element, :opacity, opacity)

    # Re-render element with new opacity
    render_element_with_opacity(updated_element)

    updated_element
  end

  @doc """
  Resizes an element in the terminal buffer.

  ## Parameters
  - element: The element to resize
  - new_width: New width in terminal columns
  - new_height: New height in terminal rows

  ## Returns
  Updated element with new dimensions
  """
  def resize_element(element, new_width, new_height)
      when is_map(element) and is_integer(new_width) and is_integer(new_height) and
             new_width > 0 and new_height > 0 do
    # Clear element from old dimensions
    clear_element_at_position(element)

    # Update element dimensions
    updated_element =
      element
      |> Map.put(:width, new_width)
      |> Map.put(:height, new_height)

    # Render element with new dimensions
    render_element_at_position(updated_element)

    updated_element
  end

  # Private helper functions

  defp clear_element_at_position(element) do
    case get_buffer_for_element(element) do
      {:ok, buffer} ->
        # Clear the area occupied by the element
        x = Map.get(element, :x, 0)
        y = Map.get(element, :y, 0)
        width = Map.get(element, :width, 1)
        height = Map.get(element, :height, 1)

        # Create empty cell for clearing
        empty_cell = %{
          char: " ",
          style: %{
            foreground: :default,
            background: :default,
            bold: false,
            italic: false,
            underline: false
          }
        }

        Utils.fill_region(buffer, x, y, width, height, empty_cell)

      {:error, _reason} ->
        # Element not in buffer, nothing to clear
        :ok
    end
  end

  defp render_element_at_position(element) do
    case get_buffer_for_element(element) do
      {:ok, buffer} ->
        # Render the element content at its position
        render_element_content(buffer, element)

      {:error, _reason} ->
        # Buffer not available, skip rendering
        :ok
    end
  end

  defp render_element_with_opacity(element) do
    case get_buffer_for_element(element) do
      {:ok, buffer} ->
        # Apply opacity to element style and re-render
        render_element_content_with_opacity(buffer, element)

      {:error, _reason} ->
        # Buffer not available, skip rendering
        :ok
    end
  end

  defp get_buffer_for_element(element) do
    # Try to get buffer from element context
    case Map.get(element, :buffer_pid) do
      nil ->
        # Try global buffer manager
        case Process.whereis(Raxol.Terminal.Buffer.Manager) do
          nil -> {:error, :no_buffer_manager}
          pid -> {:ok, pid}
        end

      buffer_pid when is_pid(buffer_pid) ->
        {:ok, buffer_pid}

      _ ->
        {:error, :invalid_buffer}
    end
  end

  defp render_element_content(buffer, element) do
    # Basic element rendering - can be extended for different element types
    x = Map.get(element, :x, 0)
    y = Map.get(element, :y, 0)
    content = Map.get(element, :content, " ")
    style = Map.get(element, :style, default_style())

    # For now, render as simple text content
    # This can be extended for more complex element types
    case buffer do
      pid when is_pid(pid) ->
        GenServer.cast(pid, {:write_char, x, y, content, style})

      _ ->
        # Direct buffer manipulation
        Text.write_char(buffer, x, y, content, style)
    end
  end

  defp render_element_content_with_opacity(buffer, element) do
    opacity = Map.get(element, :opacity, 1.0)
    base_style = Map.get(element, :style, default_style())

    # Apply opacity to style (terminal approximation)
    style_with_opacity = apply_opacity_to_style(base_style, opacity)

    x = Map.get(element, :x, 0)
    y = Map.get(element, :y, 0)
    content = Map.get(element, :content, " ")

    case buffer do
      pid when is_pid(pid) ->
        GenServer.cast(pid, {:write_char, x, y, content, style_with_opacity})

      _ ->
        Text.write_char(buffer, x, y, content, style_with_opacity)
    end
  end

  defp apply_opacity_to_style(style, opacity)
       when opacity >= 0.0 and opacity <= 1.0 do
    # Terminal opacity approximation - adjust colors based on opacity
    # For full transparency (opacity 0), use background color
    # For partial transparency, blend with background

    cond do
      opacity == 0.0 ->
        # Fully transparent - use background color for foreground
        %{style | foreground: Map.get(style, :background, :default)}

      opacity == 1.0 ->
        # Fully opaque - use original style
        style

      true ->
        # Partial transparency - this is a simplified approximation
        # In a real terminal, true transparency isn't available,
        # so we approximate by dimming colors
        apply_opacity_dimming(style, opacity)
    end
  end

  defp apply_opacity_dimming(style, opacity) do
    # Approximate opacity by making colors dimmer
    # This is a simple approach - could be enhanced with better color blending
    dimmed_style = Map.put(style, :dim, true)

    # If opacity is very low, make text color closer to background
    if opacity < 0.3 do
      Map.put(dimmed_style, :foreground, :dark_gray)
    else
      dimmed_style
    end
  end

  defp default_style do
    %{
      foreground: :default,
      background: :default,
      bold: false,
      italic: false,
      underline: false,
      dim: false
    }
  end
end
