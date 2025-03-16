defmodule Raxol.Components.Dropdown do
  @moduledoc """
  A dropdown (select) component for terminal UI applications.
  
  This component provides a way to select an option from a list of possible values.
  It supports keyboard navigation, custom rendering of options, and various styling options.
  
  ## Examples
  
  ```elixir
  alias Raxol.Components.Dropdown
  
  # Simple dropdown
  Dropdown.render(
    model.options,
    model.selected_option,
    fn selected_value -> {:select_option, selected_value} end,
    id: "country_dropdown",
    label: "Select Country:"
  )
  
  # Dropdown with custom option rendering
  Dropdown.render(
    model.users,
    model.selected_user,
    fn selected_user -> {:select_user, selected_user} end,
    id: "user_dropdown",
    label: "Assign to:",
    option_display: fn user -> "#{user.name} (#{user.role})" end,
    option_value: fn user -> user.id end
  )
  ```
  """
  
  alias Raxol.View
  alias Raxol.Event
  
  @doc """
  Renders a dropdown component.
  
  ## Parameters
  
  * `options` - List of options to display
  * `selected` - Currently selected option
  * `on_change` - Function called when selection changes
  * `opts` - Additional options for customizing the dropdown
  
  ## Options
  
  * `:id` - Unique identifier for the dropdown (default: "dropdown")
  * `:label` - Optional label to display before the dropdown
  * `:style` - Style for the dropdown container
  * `:option_style` - Style for dropdown options
  * `:selected_style` - Style for the selected option
  * `:placeholder` - Text to display when no option is selected
  * `:option_display` - Function to convert an option to display text
  * `:option_value` - Function to extract a value from an option
  * `:dropdown_width` - Width of the dropdown (default: 20)
  * `:max_height` - Maximum height of the dropdown when open (default: 10)
  
  ## Returns
  
  A view element representing the dropdown.
  
  ## Example
  
  ```elixir
  Dropdown.render(
    ["Red", "Green", "Blue"],
    "Green",
    fn color -> {:select_color, color} end,
    id: "color_picker",
    label: "Choose color:",
    selected_style: %{fg: :green}
  )
  ```
  """
  def render(options, selected, on_change, opts \\ []) do
    # Extract options with defaults
    id = Keyword.get(opts, :id, "dropdown")
    label_text = Keyword.get(opts, :label, nil)
    style = Keyword.get(opts, :style, %{})
    option_style = Keyword.get(opts, :option_style, %{})
    selected_style = Keyword.get(opts, :selected_style, %{fg: :white, bg: :blue})
    placeholder = Keyword.get(opts, :placeholder, "Select an option...")
    option_display = Keyword.get(opts, :option_display, & &1)
    option_value = Keyword.get(opts, :option_value, & &1)
    dropdown_width = Keyword.get(opts, :dropdown_width, 20)
    max_height = Keyword.get(opts, :max_height, 10)
    
    # Set metadata in the model to store dropdown state
    dropdown_key = "dropdown_#{id}"
    # Get dropdown state (is_open, etc.) from the model context
    is_open = View.get_context(dropdown_key, :is_open, false)
    
    # Display the currently selected option
    selected_text = case selected do
      nil -> placeholder
      _ -> option_display.(selected)
    end
    
    # Truncate text if necessary
    display_text = if String.length(selected_text) > dropdown_width - 4 do
      String.slice(selected_text, 0, dropdown_width - 7) <> "..."
    else
      selected_text
    end
    
    # Define the toggle function for opening/closing dropdown
    toggle_dropdown = fn ->
      View.update_context(dropdown_key, :is_open, !is_open)
    end
    
    # Define the selection function
    select_option = fn option ->
      on_change.(option_value.(option))
      View.update_context(dropdown_key, :is_open, false)
    end
    
    # Build the dropdown
    View.column([id: id, style: style], fn ->
      # Optional label
      if label_text, do: View.text(label_text)
      
      # Dropdown trigger button
      View.button(
        [
          id: "#{id}_trigger",
          style: Map.merge(%{width: dropdown_width}, style),
          on_click: toggle_dropdown
        ],
        "#{display_text} #{if is_open, do: "▲", else: "▼"}"
      )
      
      # Dropdown options list (only shown when open)
      if is_open do
        options_count = Enum.count(options)
        visible_count = min(options_count, max_height)
        
        View.panel(
          [
            id: "#{id}_options",
            style: Map.merge(%{width: dropdown_width, height: visible_count}, style),
            on_key: fn key ->
              case key do
                {key, _} when key in [:escape, :enter] -> 
                  View.update_context(dropdown_key, :is_open, false)
                  true
                _ -> false
              end
            end
          ],
          fn ->
            View.column([], fn ->
              Enum.map(options, fn option ->
                option_value = option_value.(option)
                is_selected = option_value == option_value.(selected)
                option_text = option_display.(option)
                
                # Compute style for this option
                final_style = if is_selected do
                  Map.merge(option_style, selected_style)
                else
                  option_style
                end
                
                View.button(
                  [
                    id: "#{id}_option_#{option_value}",
                    style: Map.merge(%{width: dropdown_width - 2}, final_style),
                    on_click: fn -> select_option.(option) end
                  ],
                  option_text
                )
              end)
            end)
          end
        )
      end
    end)
  end
  
  @doc """
  Creates a dropdown with a custom filter input.
  
  This is a more advanced version of the dropdown that includes
  a text input for filtering the available options.
  
  ## Parameters
  
  * `options` - List of options to display
  * `selected` - Currently selected option
  * `filter_text` - Current filter text
  * `on_change` - Function called when selection changes
  * `on_filter_change` - Function called when filter text changes
  * `opts` - Additional options for customizing the dropdown
  
  ## Options
  
  Same as `render/4` with these additions:
  * `:filter_placeholder` - Placeholder text for the filter input
  * `:filter_style` - Style for the filter input
  * `:filter_fn` - Function to determine if an option matches the filter
  
  ## Returns
  
  A view element representing the filterable dropdown.
  
  ## Example
  
  ```elixir
  Dropdown.filterable(
    model.users,
    model.selected_user,
    model.filter_text,
    fn user -> {:select_user, user} end,
    fn text -> {:filter_changed, text} end,
    id: "user_selector",
    option_display: fn user -> "#{user.name} (#{user.email})" end,
    filter_fn: fn user, filter ->
      String.contains?(String.downcase(user.name), String.downcase(filter)) ||
      String.contains?(String.downcase(user.email), String.downcase(filter))
    end
  )
  ```
  """
  def filterable(options, selected, filter_text, on_change, on_filter_change, opts \\ []) do
    # Extract additional options with defaults
    id = Keyword.get(opts, :id, "filterable_dropdown")
    filter_placeholder = Keyword.get(opts, :filter_placeholder, "Type to filter...")
    filter_style = Keyword.get(opts, :filter_style, %{})
    filter_fn = Keyword.get(opts, :filter_fn, fn option, filter ->
      option_display = Keyword.get(opts, :option_display, & &1)
      text = option_display.(option)
      String.contains?(String.downcase("#{text}"), String.downcase(filter))
    end)
    
    # Filter options based on the current filter text
    filtered_options =
      if filter_text && filter_text != "" do
        Enum.filter(options, &filter_fn.(&1, filter_text))
      else
        options
      end
    
    # Set dropdown open when user starts typing
    dropdown_key = "dropdown_#{id}"
    is_open = View.get_context(dropdown_key, :is_open, false)
    if filter_text && filter_text != "" && !is_open do
      View.update_context(dropdown_key, :is_open, true)
    end
    
    # Create a combined component with filter input and dropdown
    View.column([id: id], fn ->
      # Filter input
      View.row([], fn ->
        View.text_input(
          [
            id: "#{id}_filter",
            style: filter_style,
            placeholder: filter_placeholder,
            value: filter_text,
            on_change: on_filter_change
          ]
        )
      end)
      
      # Render the dropdown with filtered options
      render(
        filtered_options,
        selected,
        on_change,
        Keyword.put(opts, :id, "#{id}_dropdown")
      )
    end)
  end
end 