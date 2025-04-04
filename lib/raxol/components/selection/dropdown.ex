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
  alias Raxol.View.Components
  alias Raxol.View.Layout
  alias Raxol.Core.Style.Color
  alias Raxol.Components.Selection.List

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
      render_item: props[:render_item] || &to_string/1,
      filter_item: props[:filter_item] || &default_filter/2,
      on_change: props[:on_change],
      focused: false,
      list_state: init_list_state(props)
    }
  end

  defp init_list_state(props) do
    List.init(%{
      items: props[:items] || [],
      width: (props[:width] || @default_width) - 2, # Account for borders
      height: props[:max_height] || @default_max_height,
      style: Map.merge(@default_style, props[:style] || %{}),
      render_item: props[:render_item] || &to_string/1,
      filter_item: props[:filter_item] || &default_filter/2,
      on_select: nil, # We'll set this in the update function
      on_submit: nil  # We'll set this in the update function
    })
  end

  @impl true
  def update({:set_items, items}, state) do
    list_state = List.update({:set_items, items}, state.list_state)
    %{state | items: items, list_state: list_state}
  end

  def update({:select_item, item}, state) do
    new_state = %{state |
      selected_item: item,
      is_open: false,
      filter: ""
    }
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
  def render(state) do
    Layout.column do
      render_trigger(state)
      if state.is_open do
        render_list(state)
      end
    end
  end

  defp render_trigger(state) do
    display_text = if state.selected_item do
      state.render_item.(state.selected_item)
    else
      Components.text(content: state.placeholder, color: state.style.placeholder_color)
    end

    Components.box style: %{border_color: state.style.border_color} do
      Components.row do
        Components.text(content: display_text, color: state.style.text_color)
        Components.text(content: " ▼", color: state.style.text_color) # Dropdown arrow
      end
    end
  end

  defp render_list(state) do
    Components.box style: %{border_color: state.style.border_color} do
      List.render(%{state.list_state |
        focused: state.focused,
        on_select: fn item -> update({:select_item, item}, state) end,
        on_submit: fn item -> update({:select_item, item}, state) end
      })
    end
  end

  @impl true
  def handle_event(%Event{type: :key} = event, state) when state.focused do
    case event do
      %{key: " "} when not state.is_open ->
        {update(:toggle, state), []}

      %{key: "Escape"} ->
        {update(:close, state), []}

      %{key: key} when byte_size(key) == 1 and state.is_open ->
        # Type-ahead search when open
        new_filter = state.filter <> key
        {update({:set_filter, new_filter}, state), []}

      %{key: "Backspace"} when state.is_open ->
        if String.length(state.filter) > 0 do
          new_filter = String.slice(state.filter, 0, -1)
          {update({:set_filter, new_filter}, state), []}
        else
          {state, []}
        end

      _ when state.is_open ->
        # Delegate to list component when open
        {new_list_state, commands} = List.handle_event(event, state.list_state)
        {%{state | list_state: new_list_state}, commands}

      _ ->
        {state, []}
    end
  end

  def handle_event(%Event{type: :click}, state) do
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