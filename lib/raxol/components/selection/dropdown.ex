defmodule Raxol.Components.Selection.Dropdown do
  @moduledoc """
  A dropdown component that combines a trigger button with a popup list of options.

  ## Props
    * `:items` - List of items to display in the dropdown
    * `:selected_item` - Currently selected item
    * `:placeholder` - Text to display when no item is selected (default: "Select...")
    * `:width` - Width of the dropdown (default: 30)
    * `:max_height` - Maximum height of the dropdown list when open (default: 10)
    * `:style` - Style map for customizing appearance
      * `:text_color` - Color of the text (default: :white)
      * `:placeholder_color` - Color of placeholder text (default: :gray)
      * `:border_color` - Color of the border (default: :white)
      * `:selected_color` - Color of selected item (default: :blue)
      * `:selected_text_color` - Color of text in selected item (default: :white)
    * `:render_item` - Function to render an item (default: &to_string/1)
    * `:filter_item` - Function to filter an item (default: string contains)
    * `:on_change` - Function called when selection changes
  """

  use Raxol.Component
  alias Raxol.Components.Selection.List
  alias Raxol.View.Layout
  alias Raxol.View.Components

  @default_width 30
  @default_max_height 10
  @default_style %{
    text_color: :white,
    placeholder_color: :gray,
    border_color: :white,
    selected_color: :blue,
    selected_text_color: :white
  }

  @impl true
  def init(props) do
    items = props[:items] || []

    %{
      items: items,
      selected_item: props[:selected_item],
      placeholder: props[:placeholder] || "Select...",
      width: props[:width] || @default_width,
      max_height: props[:max_height] || @default_max_height,
      style: Map.merge(@default_style, props[:style] || %{}),
      is_open: false,
      filter: "",
      render_item: props[:render_item] || (&to_string/1),
      filter_item: props[:filter_item] || (&default_filter/2),
      on_change: props[:on_change],
      focused: false,
      list_state: init_list_state(props)
    }
  end

  defp init_list_state(props) do
    List.init(%{
      items: props[:items] || [],
      # Account for borders
      width: (props[:width] || @default_width) - 2,
      height: props[:max_height] || @default_max_height,
      style: Map.merge(@default_style, props[:style] || %{}),
      render_item: props[:render_item] || (&to_string/1),
      filter_item: props[:filter_item] || (&default_filter/2),
      # We'll set this in the update function
      on_select: nil,
      # We'll set this in the update function
      on_submit: nil
    })
  end

  @impl true
  def update({:set_items, items}, state) do
    list_state = List.update({:set_items, items}, state.list_state)
    %{state | items: items, list_state: list_state}
  end

  def update({:select_item, item}, state) do
    new_state = %{state | selected_item: item, is_open: false, filter: ""}
    if state.on_change, do: state.on_change.(item)
    new_state
  end

  def update({:set_filter, filter}, state) do
    list_state = List.update({:set_filter, filter}, state.list_state)
    %{state | filter: filter, list_state: list_state}
  end

  def update(:toggle, state) do
    %{state | is_open: not state.is_open, filter: "", focused: true}
  end

  def update(:close, state) do
    %{state | is_open: false, filter: ""}
  end

  def update(:focus, state), do: %{state | focused: true}
  def update(:blur, state), do: %{state | focused: false, is_open: false}
  def update(_msg, state), do: state

  @impl true
  @spec render(map()) :: Raxol.Core.Renderer.Element.t() | nil
  @dialyzer {:nowarn_function, render: 1}
  def render(state) do
    if state.is_open do
      dsl_result_expanded = render_expanded(state)
      Raxol.View.to_element(dsl_result_expanded)
    else
      dsl_result_collapsed = render_collapsed(state)
      Raxol.View.to_element(dsl_result_collapsed)
    end
  end

  @dialyzer {:nowarn_function, render_collapsed: 1}
  @spec render_collapsed(map()) :: map()
  defp render_collapsed(state) do
    selected_label = get_selected_label(state)
    # Render a box that looks like a closed dropdown
    Layout.box style: %{border: :single, width: state.width} do
      [
        Layout.row style: %{width: :fill} do
          [
            Components.text(selected_label, style: %{width: :fill}),
            # Down arrow indicator
            Components.text(" ▼")
          ]
        end
      ]
    end
  end

  @dialyzer {:nowarn_function, render_expanded: 1}
  @spec render_expanded(map()) :: map()
  defp render_expanded(state) do
    Layout.column do
      # Explicitly return a list for the column's children
      [
        # Show the collapsed view first
        _collapsed_view = render_collapsed(state),
        # Then render the list of options below
        Layout.box style: %{border: :single, width: state.width} do
          # Determine the selected index
          selected_index =
            cond do
              is_integer(state.selected_item) ->
                state.selected_item

              not is_nil(state.selected_item) ->
                # Find index of the item in the list
                Enum.find_index(state.items, fn item ->
                  item == state.selected_item
                end)

              true ->
                nil
            end

          # Capture the result of List.render
          list_elements =
            List.render(%{
              items: state.items,
              render_item: state.render_item,
              selected_index: selected_index,
              # Adjust for border
              width: state.width - 2,
              # Or a max height
              height: Enum.count(state.items)
            })

          # Return the result
          list_elements
        end
      ]
    end
  end

  defp get_selected_label(state) do
    cond do
      is_integer(state.selected_item) ->
        # If selected_item is an index
        selected_item = Enum.at(state.items, state.selected_item)

        if selected_item,
          do: state.render_item.(selected_item),
          else: state.placeholder

      not is_nil(state.selected_item) ->
        # If selected_item is the actual item value
        state.render_item.(state.selected_item)

      true ->
        # Default case
        state.placeholder
    end
  end

  @impl true
  def handle_event(%Event{type: :key, data: key_data} = event, state) do
    cond do
      # Delegate to List component when open and focused?
      # Assuming List component handles Up/Down/Enter/Selection internally
      state.is_open and state.focused ->
        {new_list_state, commands} = List.handle_event(event, state.list_state)

        # Check if List component selected an item (emitted command? Or changed state?)
        # Need to know how List signals selection back up. Assuming it calls on_select/on_submit.
        # For now, just update list_state.
        # If list selection triggers on_select/on_submit which calls our update(:select_item, ...)
        # then this might work.
        {%{state | list_state: new_list_state}, commands}

      # Toggle open/closed with Enter/Space when closed
      (key_data == %{key: :enter} or key_data == %{key: " "}) and
          not state.is_open ->
        {update(:toggle, state), []}

      # Close with Escape when open
      key_data == %{key: :escape} and state.is_open ->
        {update(:close, state), []}

      # Ignore other keys when closed or not focused
      true ->
        {state, []}
    end
  end

  def handle_event(%Event{type: :click}, state) do
    # Toggle on click regardless of focus?
    {update(:toggle, state), []}
  end

  def handle_event(%Event{type: :blur}, state) do
    {update(:blur, state), []}
  end

  def handle_event(_event, state), do: {state, []}

  # Helper functions
  defp default_filter(item, filter) do
    item_str = to_string(item)
    filter_str = String.downcase(filter)
    String.contains?(String.downcase(item_str), filter_str)
  end
end
