defmodule Raxol.Renderer.Layout do
  @moduledoc """
  Handles layout calculations for UI elements.
  
  This module translates the logical layout (panels, rows, columns)
  into absolute positions for rendering.
  """
  
  @doc """
  Applies layout to a view, calculating absolute positions for all elements.
  
  ## Parameters
  
  * `view` - The view to calculate layout for
  * `dimensions` - Terminal dimensions `%{width: w, height: h}`
  
  ## Returns
  
  A list of positioned elements with absolute coordinates.
  """
  def apply_layout(view, dimensions) do
    # Start with the full screen as available space
    available_space = %{
      x: 0,
      y: 0,
      width: dimensions.width,
      height: dimensions.height
    }
    
    # Process the view tree
    process_element(view, available_space, [])
    |> List.flatten()
  end
  
  # Process a view element
  defp process_element(%{type: :view, children: children}, space, acc) when is_list(children) do
    # Process children with the available space
    process_children(children, space, acc)
  end
  
  defp process_element(%{type: :view, children: children}, space, acc) do
    # Handle case where children is not a list
    process_element(children, space, acc)
  end
  
  defp process_element(%{type: :panel, attrs: attrs, children: children}, space, acc) when is_list(children) do
    # Apply panel specific layout (add border, title, etc)
    panel_space = apply_panel_layout(space, attrs)
    
    # Add the panel border to the accumulator
    panel_elements = create_panel_elements(space, attrs)
    
    # Process panel children with the new available space
    inner_elements = process_children(children, panel_space, [])
    
    [panel_elements, inner_elements | acc]
  end
  
  defp process_element(%{type: :row, attrs: _attrs, children: children}, space, acc) when is_list(children) do
    # Process row element
    # TODO: Implement row layout processing
    {space, acc}
  end
  
  defp process_element(%{type: :column, attrs: _attrs, children: children}, space, acc) when is_list(children) do
    # Divide vertical space among children
    child_count = length(children)
    child_height = div(space.height, max(child_count, 1))
    
    # Process each child with its allocated space
    children
    |> Enum.with_index()
    |> Enum.map(fn {child, index} ->
      child_space = %{
        x: space.x,
        y: space.y + (index * child_height),
        width: space.width,
        height: child_height
      }
      process_element(child, child_space, [])
    end)
    |> Enum.concat(acc)
  end
  
  defp process_element(%{type: :label, attrs: attrs}, space, acc) do
    # Create a text element at the given position
    text_element = %{
      type: :text,
      x: space.x,
      y: space.y,
      text: Map.get(attrs, :content, ""),
      attrs: %{fg: :white, bg: :black}
    }
    
    [text_element | acc]
  end
  
  defp process_element(%{type: :button, attrs: attrs}, space, acc) do
    # Create a button element
    text = Map.get(attrs, :label, "Button")
    
    button_elements = [
      # Button box
      %{
        type: :box,
        x: space.x,
        y: space.y,
        width: min(String.length(text) + 4, space.width),
        height: 3,
        attrs: %{fg: :white, bg: :blue}
      },
      # Button text
      %{
        type: :text,
        x: space.x + 2,
        y: space.y + 1,
        text: text,
        attrs: %{fg: :white, bg: :blue}
      }
    ]
    
    button_elements ++ acc
  end
  
  defp process_element(%{type: :text_input, attrs: attrs}, space, acc) do
    # Create a text input element
    value = Map.get(attrs, :value, "")
    placeholder = Map.get(attrs, :placeholder, "")
    text = if value == "", do: placeholder, else: value
    
    text_input_elements = [
      # Input box
      %{
        type: :box,
        x: space.x,
        y: space.y,
        width: min(max(String.length(text) + 4, 10), space.width),
        height: 3,
        attrs: %{fg: :white, bg: :black}
      },
      # Input text
      %{
        type: :text,
        x: space.x + 2,
        y: space.y + 1,
        text: text,
        attrs: %{
          fg: if(value == "", do: :gray, else: :white),
          bg: :black
        }
      }
    ]
    
    text_input_elements ++ acc
  end
  
  defp process_element(%{type: :checkbox, attrs: attrs}, space, acc) do
    # Create a checkbox element
    checked = Map.get(attrs, :checked, false)
    label = Map.get(attrs, :label, "")
    
    checkbox_text = if checked, do: "[✓]", else: "[ ]"
    
    checkbox_elements = [
      # Checkbox text
      %{
        type: :text,
        x: space.x,
        y: space.y,
        text: "#{checkbox_text} #{label}",
        attrs: %{fg: :white, bg: :black}
      }
    ]
    
    checkbox_elements ++ acc
  end
  
  defp process_element(%{type: :table, attrs: attrs}, space, acc) do
    # Create a table element
    headers = Map.get(attrs, :headers, [])
    data = Map.get(attrs, :data, [])
    
    # Calculate table dimensions
    table_width = space.width
    row_height = 1
    header_y = space.y
    data_start_y = space.y + 2  # After header and separator
    
    # Create table elements
    header_elements = 
      if headers != [] do
        [
          # Header row
          %{
            type: :text,
            x: space.x,
            y: header_y,
            text: Enum.join(headers, " | "),
            attrs: %{fg: :white, bg: :black}
          },
          # Separator line
          %{
            type: :text,
            x: space.x,
            y: header_y + 1,
            text: String.duplicate("-", table_width),
            attrs: %{fg: :white, bg: :black}
          }
        ]
      else
        []
      end
    
    # Create data rows
    data_elements = 
      data
      |> Enum.with_index()
      |> Enum.map(fn {row, index} ->
        %{
          type: :text,
          x: space.x,
          y: data_start_y + (index * row_height),
          text: Enum.join(row, " | "),
          attrs: %{fg: :white, bg: :black}
        }
      end)
    
    header_elements ++ data_elements ++ acc
  end
  
  defp process_element(element, _space, acc) do
    # Default case for unhandled elements
    [element | acc]
  end
  
  # Process a list of children
  defp process_children(children, space, acc) when is_list(children) do
    Enum.reduce(children, acc, fn child, acc ->
      process_element(child, space, acc)
    end)
  end
  
  defp process_children(child, space, acc) do
    process_element(child, space, acc)
  end
  
  # Apply panel layout, adjusting available space for contents
  defp apply_panel_layout(space, _attrs) do
    # Apply panel layout
    # TODO: Implement panel layout processing
    space
  end
  
  # Create panel border elements
  defp create_panel_elements(space, attrs) do
    title = Map.get(attrs, :title, "")
    
    box = %{
      type: :box,
      x: space.x,
      y: space.y,
      width: space.width,
      height: space.height,
      attrs: %{fg: :white, bg: :black}
    }
    
    title_element = 
      if title != "" do
        %{
          type: :text,
          x: space.x + 2,
          y: space.y,
          text: " #{title} ",
          attrs: %{fg: :white, bg: :black}
        }
      else
        nil
      end
    
    if title_element, do: [box, title_element], else: [box]
  end
end 