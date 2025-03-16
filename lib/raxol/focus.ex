defmodule Raxol.Focus do
  @moduledoc """
  Manages focus traversal within terminal UIs.
  
  This module handles keyboard navigation between interactive elements
  within a terminal UI, providing a consistent way to move focus using
  tab, arrow keys, or other keyboard shortcuts.
  
  ## Usage
  
  The focus system is integrated into the Raxol application lifecycle
  and requires no explicit initialization. Interactive components like
  buttons and text inputs automatically register with the focus system.
  
  Users navigate between focusable elements using Tab/Shift+Tab or
  arrow keys, depending on the navigation mode.
  """
  
  @doc """
  Creates a new focus state.
  
  This is typically used in the application's init function to initialize
  the focus state as part of the application model.
  
  ## Example
  
  ```elixir
  def init(_) do
    %{
      # ... other state ...
      focus: Raxol.Focus.new()
    }
  end
  ```
  """
  def new do
    %{
      current_key: nil,
      elements: [],
      navigation_mode: :tab,
      cycle: true
    }
  end
  
  @doc """
  Updates focus state based on the rendered view.
  
  This function scans a view for focusable elements and updates the
  focus state accordingly. It preserves the currently focused element
  when possible.
  
  ## Parameters
  
  * `focus_state` - The current focus state
  * `view` - The rendered view to analyze
  
  ## Returns
  
  Updated focus state.
  
  ## Example
  
  ```elixir
  def render(model) do
    view = view do
      # ... UI elements ...
    end
    
    # Update focus state based on the current view
    model = %{model | focus: Raxol.Focus.update_from_view(model.focus, view)}
    
    view
  end
  ```
  """
  def update_from_view(focus_state, view) do
    # Extract focusable elements from the view
    focusable_elements = extract_focusable_elements(view)
    
    # Determine the current focus key
    current_key = 
      case {focus_state.current_key, focusable_elements} do
        {nil, [first | _]} -> first.focus_key # No focus yet, focus first element
        {key, elements} -> 
          # Try to keep current focus if element still exists
          if Enum.any?(elements, &(&1.focus_key == key)) do
            key
          else
            case elements do
              [] -> nil
              [first | _] -> first.focus_key
            end
          end
      end
    
    %{
      focus_state |
      elements: focusable_elements,
      current_key: current_key
    }
  end
  
  @doc """
  Handles a keyboard event and updates focus accordingly.
  
  This function processes keyboard input for focus navigation,
  such as Tab, Shift+Tab, and arrow keys.
  
  ## Parameters
  
  * `focus_state` - The current focus state
  * `event` - Keyboard event to process
  
  ## Returns
  
  Updated focus state.
  
  ## Example
  
  ```elixir
  def update(model, msg) do
    case msg do
      {:event, {:key, meta, key}} ->
        %{model | focus: Raxol.Focus.handle_key_event(model.focus, {meta, key})}
      # ... other message handlers ...
    end
  end
  ```
  """
  def handle_key_event(focus_state, {meta, key}) do
    case {focus_state.navigation_mode, meta, key} do
      # Tab navigation
      {:tab, :none, :tab} -> move_focus(focus_state, :next)
      {:tab, :shift, :tab} -> move_focus(focus_state, :prev)
      
      # Arrow navigation
      {:arrow, :none, :arrow_down} -> move_focus(focus_state, :down)
      {:arrow, :none, :arrow_up} -> move_focus(focus_state, :up)
      {:arrow, :none, :arrow_right} -> move_focus(focus_state, :right)
      {:arrow, :none, :arrow_left} -> move_focus(focus_state, :left)
      
      # Not a focus navigation key
      _ -> focus_state
    end
  end
  
  @doc """
  Moves focus in the specified direction.
  
  ## Parameters
  
  * `focus_state` - The current focus state
  * `direction` - Direction to move (:next, :prev, :up, :down, :left, :right)
  
  ## Returns
  
  Updated focus state.
  
  ## Example
  
  ```elixir
  # Move focus to next element
  new_focus = Raxol.Focus.move_focus(model.focus, :next)
  ```
  """
  def move_focus(focus_state, direction) when direction in [:next, :prev] do
    case focus_state.elements do
      [] -> focus_state
      elements ->
        current_index = find_element_index(elements, focus_state.current_key)
        next_index = get_next_index(current_index, length(elements), direction, focus_state.cycle)
        
        case Enum.at(elements, next_index) do
          nil -> focus_state
          element -> %{focus_state | current_key: element.focus_key}
        end
    end
  end
  
  def move_focus(focus_state, direction) when direction in [:up, :down, :left, :right] do
    # This is a simplified version, a real implementation would need
    # to calculate positions and find the nearest element in the given direction
    move_focus(focus_state, (if direction in [:down, :right], do: :next, else: :prev))
  end
  
  @doc """
  Returns the currently focused element, if any.
  
  ## Parameters
  
  * `focus_state` - The current focus state
  
  ## Returns
  
  The focused element or nil if no element is focused.
  
  ## Example
  
  ```elixir
  case Raxol.Focus.get_focused_element(model.focus) do
    nil -> # No element is focused
    element -> # Handle focused element
  end
  ```
  """
  def get_focused_element(focus_state) do
    Enum.find(focus_state.elements, &(&1.focus_key == focus_state.current_key))
  end
  
  @doc """
  Sets the focus navigation mode.
  
  ## Parameters
  
  * `focus_state` - The current focus state
  * `mode` - Navigation mode (:tab or :arrow)
  
  ## Returns
  
  Updated focus state.
  
  ## Example
  
  ```elixir
  # Switch to arrow key navigation
  new_focus = Raxol.Focus.set_navigation_mode(model.focus, :arrow)
  ```
  """
  def set_navigation_mode(focus_state, mode) when mode in [:tab, :arrow] do
    %{focus_state | navigation_mode: mode}
  end
  
  @doc """
  Sets whether focus should cycle when reaching the end of the focusable elements.
  
  ## Parameters
  
  * `focus_state` - The current focus state
  * `cycle` - Whether to cycle (boolean)
  
  ## Returns
  
  Updated focus state.
  
  ## Example
  
  ```elixir
  # Disable focus cycling
  new_focus = Raxol.Focus.set_cycle(model.focus, false)
  ```
  """
  def set_cycle(focus_state, cycle) when is_boolean(cycle) do
    %{focus_state | cycle: cycle}
  end
  
  # Private functions
  
  defp extract_focusable_elements(view) do
    # This is a simplified version, a real implementation would traverse
    # the entire view tree to find all focusable elements
    case view do
      %{children: children} when is_list(children) ->
        Enum.flat_map(children, &extract_focusable_elements/1)
      
      %{type: :button} = element ->
        [%{type: :focusable, element_type: :button, focus_key: Map.get(element, :focus_key, "button-#{:erlang.unique_integer([:positive])}")}]
      
      %{type: :text_input} = element ->
        [%{type: :focusable, element_type: :text_input, focus_key: Map.get(element, :focus_key, "input-#{:erlang.unique_integer([:positive])}")}]
      
      %{type: :checkbox} = element ->
        [%{type: :focusable, element_type: :checkbox, focus_key: Map.get(element, :focus_key, "checkbox-#{:erlang.unique_integer([:positive])}")}]
      
      _ -> []
    end
  end
  
  defp find_element_index(elements, key) do
    Enum.find_index(elements, &(&1.focus_key == key)) || 0
  end
  
  defp get_next_index(current, total, :next, cycle) do
    next = current + 1
    if next >= total do
      if cycle, do: 0, else: current
    else
      next
    end
  end
  
  defp get_next_index(current, total, :prev, cycle) do
    prev = current - 1
    if prev < 0 do
      if cycle, do: total - 1, else: current
    else
      prev
    end
  end
end 