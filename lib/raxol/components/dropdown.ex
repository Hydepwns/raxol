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
    option_display: fn item -> "\#{item.name} (\#{item.email})" end,
    option_value: fn item -> item.id end
  )
  """

  # alias Raxol.View # Unused
  alias Raxol.Core.Events.Event

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
  def render(dropdown_key, options, selected, _on_change) do
    # TODO: Raxol.View context API seems changed. Commenting out context logic.
    # is_open = View.get_context(dropdown_key, :is_open, false)
    is_open = false # Assume closed for now

    content = fn ->
      trigger = render_trigger(selected, is_open)
      list = if is_open, do: render_list(options, selected, dropdown_key)

      # TODO: Raxol.View.Components.box/1 seems undefined. Commenting out layout.
      # Components.box style: @trigger_style do
      #   trigger
      # end
      # list

      # Placeholder rendering
      [trigger, list]
    end

    # TODO: Raxol.View context API seems changed. Commenting out context logic.
    # click_handler = fn ->
    #   View.update_context(dropdown_key, :is_open, !is_open)
    #   on_change.(selected) # Notify parent about potential selection change (or lack thereof)
    # end
    # blur_handler = fn ->
    #   View.update_context(dropdown_key, :is_open, false)
    # end

    # Placeholder element - return map instead of calling View.element
    %{type: :div, attrs: [], children: content.()}

    # TODO: Original implementation used View DSL, needs refactoring
    # View.element :div, \"dropdown\",
    #   on_click: click_handler,
    #   on_blur: blur_handler,
    #   content: content
  end

  defp render_trigger(selected, is_open) do
    icon = if is_open, do: "▲", else: "▼"

    # TODO: Raxol.View.Components.row/1 seems undefined. Commenting out layout.
    # Components.row do
    #   Components.text selected
    #   Components.text icon, style: %{margin_left: 1}
    # end

    # Placeholder rendering
    Raxol.Core.Renderer.View.text("#{selected} #{icon}")
  end

  defp render_list(_options, _selected, _dropdown_key) do
    # placeholder
    nil
  end

  # TODO: Raxol.View context API seems changed.
  # defp select_item(dropdown_key, option) do
  #   View.update_context(dropdown_key, :is_open, false)
  #   # Trigger parent on_change callback
  # end

  # @impl true
  def handle_event(%Event{type: :key, data: %{key: key}} = _event, state) do
    _dropdown_key = state.dropdown_key
    is_open = false # TODO: Need context -> View.get_context(dropdown_key, :is_open, false)

    case key do
      # Match on key directly from event.data
      " " when not is_open ->
        # TODO: Need context -> View.update_context(dropdown_key, :is_open, true)
        {state, []}

      "Escape" ->
        # TODO: Need context -> View.update_context(dropdown_key, :is_open, false)
        {state, []}

      key when byte_size(key) == 1 and is_open ->
        # Basic filtering logic (example)
        new_filter = state.filter <> key
        # TODO: Apply filter, update list, etc.
        {Map.put(state, :filter, new_filter), []}

      "Backspace" when is_open ->
        new_filter = String.slice(state.filter, 0..-2//-1)
        {Map.put(state, :filter, new_filter), []}

      _ ->
        # Pass through other key events
        {state, []}
    end
  end
  # Handle non-key events
  def handle_event(_event, state), do: {state, []} # Default case

  def filterable(
         filterable?,
         options,
         selected,
         dropdown_key,
         _content,
         _render_opts \\ []
       ) do
    if filterable? do
      # Placeholder for filterable dropdown rendering
      render_list(options, selected, dropdown_key)
    else
      render_list(options, selected, dropdown_key)
    end
  end
end
