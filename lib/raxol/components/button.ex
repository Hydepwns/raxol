defmodule Raxol.Components.Button do
  @moduledoc """
  A customizable button component.
  
  This module provides a more sophisticated button component than the basic
  button element, with support for various styles and behaviors.
  
  ## Example
  
  ```elixir
  alias Raxol.Components.Button
  
  Button.new("Save Changes", on_click: :save_clicked, style: :primary)
  ```
  """
  
  alias Raxol.Style
  
  @type t :: map()
  
  @doc """
  Creates a new button with the given label and options.
  
  ## Options
  
  * `:on_click` - Message to send when the button is clicked
  * `:style` - Button style (:primary, :secondary, :danger, :success, or a custom style map)
  * `:disabled` - Whether the button is disabled
  * `:icon` - Icon to display before the label
  * `:full_width` - Whether the button should take full width
  * `:size` - Button size (:small, :medium, :large)
  * `:tooltip` - Tooltip text to show on hover
  
  ## Returns
  
  A button component that can be used in a Raxol view.
  
  ## Example
  
  ```elixir
  Button.new("Delete", 
    on_click: {:delete, item_id},
    style: :danger,
    icon: :trash
  )
  ```
  """
  def new(label, opts \\ []) do
    # Extract options with defaults
    on_click = Keyword.get(opts, :on_click)
    button_style = Keyword.get(opts, :style, :primary)
    disabled = Keyword.get(opts, :disabled, false)
    icon = Keyword.get(opts, :icon)
    full_width = Keyword.get(opts, :full_width, false)
    size = Keyword.get(opts, :size, :medium)
    tooltip = Keyword.get(opts, :tooltip)
    
    # Create the button with merged styles
    %{
      type: :component,
      component_type: :button,
      label: label,
      on_click: on_click,
      disabled: disabled,
      icon: icon,
      full_width: full_width,
      size: size,
      tooltip: tooltip,
      style: get_button_style(button_style, size, full_width, disabled),
      focus_key: Keyword.get(opts, :focus_key, generate_focus_key())
    }
  end
  
  @doc """
  Renders the button as a basic element.
  
  This is typically called by the renderer, not directly by users.
  """
  def render(button) do
    content = get_button_content(button)
    
    Style.render(button.style, %{
      type: :button,
      attrs: %{
        content: content,
        on_click: button.on_click,
        disabled: button.disabled,
        focus_key: button.focus_key,
        tooltip: button.tooltip
      }
    })
  end
  
  # Private functions
  
  defp get_button_style(style_type, size, full_width, disabled) when is_atom(style_type) do
    base_style = Style.style([
      padding: get_padding_for_size(size),
      align: :center,
      width: if(full_width, do: :fill, else: :auto),
      border: :rounded
    ])
    
    color_style = get_color_style(style_type)
    size_style = get_size_style(size)
    
    combined_style = Style.combine([base_style, color_style, size_style])
    
    if disabled do
      Style.merge(combined_style, Style.style(color: :gray, background: :dark_gray))
    else
      combined_style
    end
  end
  
  defp get_button_style(custom_style, size, full_width, disabled) when is_map(custom_style) do
    base_style = Style.style([
      padding: get_padding_for_size(size),
      align: :center,
      width: if(full_width, do: :fill, else: :auto),
      border: :rounded
    ])
    
    combined_style = Style.merge(base_style, custom_style)
    
    if disabled do
      Style.merge(combined_style, Style.style(color: :gray, background: :dark_gray))
    else
      combined_style
    end
  end
  
  defp get_color_style(:primary) do
    Style.style(color: :white, background: :blue)
  end
  
  defp get_color_style(:secondary) do
    Style.style(color: :black, background: :light_gray)
  end
  
  defp get_color_style(:danger) do
    Style.style(color: :white, background: :red)
  end
  
  defp get_color_style(:success) do
    Style.style(color: :white, background: :green)
  end
  
  defp get_color_style(_) do
    Style.style(color: :white, background: :blue)
  end
  
  defp get_size_style(:small) do
    Style.style(padding: [0, 1])
  end
  
  defp get_size_style(:medium) do
    Style.style(padding: [1, 2])
  end
  
  defp get_size_style(:large) do
    Style.style(padding: [1, 3])
  end
  
  defp get_padding_for_size(:small), do: [0, 1]
  defp get_padding_for_size(:medium), do: [1, 2]
  defp get_padding_for_size(:large), do: [1, 3]
  
  defp get_button_content(%{icon: nil, label: label}), do: label
  
  defp get_button_content(%{icon: icon, label: label}) do
    icon_str = get_icon_str(icon)
    "#{icon_str} #{label}"
  end
  
  defp get_icon_str(:trash), do: "🗑️"
  defp get_icon_str(:check), do: "✓"
  defp get_icon_str(:x), do: "✗"
  defp get_icon_str(:warning), do: "⚠️"
  defp get_icon_str(:info), do: "ℹ️"
  defp get_icon_str(other) when is_binary(other), do: other
  defp get_icon_str(_), do: ""
  
  defp generate_focus_key do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end 