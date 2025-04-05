defmodule Raxol.Components.HintDisplay do
  use Raxol.Component
  import Raxol.View.Components
  import Raxol.View.Layout
  
  @moduledoc """
  A component for displaying hints and tooltips.
  
  This component works with the `Raxol.Core.UXRefinement` module to display
  registered hints for components in the UI.
  
  ## Features
  
  * Multiple hint styles (minimal, standard, detailed)
  * Keyboard shortcut highlighting
  * Multi-level hints (basic, detailed, examples)
  * Automatic transitioning between hint levels
  * Support for HTML-like markup in hints
  
  ## Usage
  
  ```elixir
  # In your view
  def render(model, _opts) do
    column do
      # Your other components
      row do
        text_input(id: "search_input", placeholder: "Search...")
      end
      
      # Place the hint display at the bottom of the UI
      HintDisplay.render(model.focused_component)
    end
  end
  ```
  """
  
  alias Raxol.Core.UXRefinement
  import Raxol.View
  
  @doc """
  Render a hint display for the currently focused component.
  
  ## Options
  
  * `:style` - Style of the hint display (`:minimal`, `:standard`, `:detailed`) (default: `:standard`)
  * `:position` - Position of the hint display (`:bottom`, `:top`, `:float`) (default: `:bottom`)
  * `:always_show` - Always show the hint display, even when no hints are available (default: `false`)
  * `:max_width` - Maximum width of the hint display (default: `nil` - full width)
  * `:help_level` - Level of detail to show (`:basic`, `:detailed`, `:examples`) (default: `:basic`)
  * `:highlight_shortcuts` - Highlight keyboard shortcuts in the hint text (default: `true`)
  
  ## Examples
  
      iex> HintDisplay.render("search_input")
      # Renders a hint display for the search_input component
      
      iex> HintDisplay.render(model.focused_component, style: :minimal, position: :float)
      # Renders a minimal floating hint display
  """
  def render(focused_component, opts \\ []) do
    style = Keyword.get(opts, :style, :standard)
    position = Keyword.get(opts, :position, :bottom)
    always_show = Keyword.get(opts, :always_show, false)
    max_width = Keyword.get(opts, :max_width, nil)
    help_level = Keyword.get(opts, :help_level, :basic)
    highlight_shortcuts = Keyword.get(opts, :highlight_shortcuts, true)
    
    hint_info = UXRefinement.get_component_hint(focused_component, help_level)
    
    if hint_info || always_show do
      render_hint_display(hint_info, style, position, max_width, highlight_shortcuts)
    else
      # Return empty element when no hint and not always_show
      nil
    end
  end
  
  @doc """
  Register a keyboard shortcut for display in hints.
  
  This allows highlighting keyboard shortcuts in the hint display.
  
  ## Parameters
  
  * `shortcut_text` - Text representation of the shortcut (e.g., "Ctrl+F")
  * `description` - Brief description of what the shortcut does
  
  ## Examples
  
      iex> HintDisplay.register_shortcut("Ctrl+F", "Search")
      :ok
  """
  def register_shortcut(shortcut_text, description) do
    shortcuts = Process.get(:hint_display_shortcuts) || %{}
    updated_shortcuts = Map.put(shortcuts, shortcut_text, description)
    Process.put(:hint_display_shortcuts, updated_shortcuts)
    :ok
  end
  
  @doc """
  Cycle through help levels for the current component.
  
  This allows users to see more detailed help when needed.
  
  ## Examples
  
      iex> HintDisplay.cycle_help_level()
      :ok
  """
  def cycle_help_level do
    current_level = Process.get(:hint_display_help_level) || :basic
    
    next_level = 
      case current_level do
        :basic -> :detailed
        :detailed -> :examples
        :examples -> :basic
      end
    
    Process.put(:hint_display_help_level, next_level)
    
    # Dispatch event to update hint display
    # In a real system, this would trigger an update to the UI
    :ok
  end
  
  # Private functions
  
  defp render_hint_display(hint_info, style, position, max_width, highlight_shortcuts) do
    content = 
      case hint_info do
        nil -> "No hints available for this component"
        %{text: text} -> text
        text when is_binary(text) -> text
      end
    
    # Process shortcuts in content if highlighting is enabled
    processed_content = 
      if highlight_shortcuts do
        highlight_shortcuts_in_text(content)
      else
        content
      end
    
    # Get keyboard shortcuts if available in hint info
    shortcuts = 
      if hint_info && Map.has_key?(hint_info, :shortcuts) && hint_info.shortcuts != nil do
        hint_info.shortcuts
      else
        []
      end
    
    container_attrs = [
      padding: 1,
      background: :black,
      color: {:rgb, 180, 180, 180},
      border: [color: :blue, type: :light],
      width: max_width
    ]
    
    container_attrs = 
      case position do
        :bottom -> Keyword.merge(container_attrs, [bottom: 0, left: 0, height: calculate_height(style, shortcuts)])
        :top -> Keyword.merge(container_attrs, [top: 0, left: 0, height: calculate_height(style, shortcuts)])
        :float -> Keyword.merge(container_attrs, [center: true])
      end
      
    Layout.panel(container_attrs) do
      Layout.column do
        # Main hint text
        Components.text(processed_content)
        
        # Render shortcuts if available
        if style != :minimal && length(shortcuts) > 0 do
          Layout.row(padding_top: 1) do
            render_shortcuts(shortcuts)
          end
        end
      end
    end
  end
  
  defp calculate_height(style, shortcuts) do
    base_height = 
      case style do
        :minimal -> 3
        :standard -> 3
        :detailed -> 4
      end
    
    # Add height for shortcuts
    if shortcuts && length(shortcuts) > 0 && style != :minimal do
      base_height + div(length(shortcuts) + 1, 2) # +1 to account for the header
    else
      base_height
    end
  end
  
  defp render_shortcuts(shortcuts) do
    column do
      # Header
      Components.text("Keyboard Shortcuts:", bold: true)
      
      # Show shortcuts in a grid-like layout
      row do
        column(width: "50%") do
          Enum.with_index(shortcuts)
          |> Enum.filter(fn {_, i} -> rem(i, 2) == 0 end) # Even indices
          |> Enum.map(fn {{key, desc}, _} -> 
            Components.text([{:bold, key}, ": " <> desc]) 
          end)
        end
        
        column(width: "50%") do
          Enum.with_index(shortcuts)
          |> Enum.filter(fn {_, i} -> rem(i, 2) == 1 end) # Odd indices
          |> Enum.map(fn {{key, desc}, _} -> 
            Components.text([{:bold, key}, ": " <> desc]) 
          end)
        end
      end
    end
  end
  
  defp highlight_shortcuts_in_text(text) do
    # Get registered shortcuts
    shortcuts = Process.get(:hint_display_shortcuts) || %{}
    shortcut_keys = Map.keys(shortcuts)
    
    # Find and highlight shortcuts in text
    Enum.reduce(shortcut_keys, text, fn shortcut, acc ->
      if String.contains?(acc, shortcut) do
        String.replace(acc, shortcut, "<b>#{shortcut}</b>")
      else
        acc
      end
    end)
    |> format_markup()
  end
  
  defp format_markup(text) do
    # Simple parsing of markup tags
    # In a real implementation, this would be more robust
    cond do
      String.contains?(text, "<b>") ->
        parts = String.split(text, ~r{<b>(.*?)</b>}, include_captures: true)
        Enum.map(parts, fn part ->
          case Regex.run(~r{<b>(.*?)</b>}, part) do
            [_, content] -> {:bold, content}
            _ -> part
          end
        end)
        |> List.flatten()
        
      true ->
        text
    end
  end
  
  @doc """
  Initialize the hint display component.
  
  This function is called when the component is first created.
  
  ## Options
  
  * `:visible` - Whether the hint display is initially visible (default: `true`)
  * `:style` - Style of the hint display (default: `:standard`)
  * `:position` - Position of the hint display (default: `:bottom`) 
  * `:always_show` - Always show hint display (default: `false`)
  * `:max_width` - Maximum width (default: `nil`)
  * `:help_level` - Initial help detail level (default: `:basic`)
  """
  def init(opts \\ []) do
    # Initialize the help level
    Process.put(:hint_display_help_level, Keyword.get(opts, :help_level, :basic))
    
    %{
      visible: Keyword.get(opts, :visible, true),
      style: Keyword.get(opts, :style, :standard),
      position: Keyword.get(opts, :position, :bottom),
      always_show: Keyword.get(opts, :always_show, false),
      max_width: Keyword.get(opts, :max_width, nil),
      help_level: Keyword.get(opts, :help_level, :basic)
    }
  end
  
  @doc """
  Update the hint display component state based on events.
  """
  def update(model, msg) do
    case msg do
      {:toggle_visibility} ->
        %{model | visible: !model.visible}
        
      {:set_style, style} ->
        %{model | style: style}
        
      {:set_position, position} ->
        %{model | position: position}
        
      {:set_help_level, level} when level in [:basic, :detailed, :examples] ->
        Process.put(:hint_display_help_level, level)
        %{model | help_level: level}
        
      {:cycle_help_level} ->
        next_level = 
          case model.help_level do
            :basic -> :detailed
            :detailed -> :examples
            :examples -> :basic
          end
        Process.put(:hint_display_help_level, next_level)
        %{model | help_level: next_level}
        
      _ ->
        model
    end
  end
  
  @doc """
  Subscribe to relevant events for the hint display.
  """
  def subscriptions(_model) do
    # Subscribe to focus change events to update hints
    [{:focus_change, :global}]
  end
end 