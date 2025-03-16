defmodule Raxol.Components.Selection.List do
  @moduledoc """
  A list component with keyboard navigation, selection handling, and filtering support.

  ## Props
    * `:items` - List of items to display
    * `:selected_index` - Index of the selected item (default: 0)
    * `:height` - Height of the list (default: 10)
    * `:width` - Width of the list (default: 40)
    * `:style` - Style map for customizing appearance
      * `:text_color` - Color of the text (default: :white)
      * `:selected_color` - Color of selected item (default: :blue)
      * `:selected_text_color` - Color of text in selected item (default: :white)
    * `:filter` - Current filter text (default: "")
    * `:render_item` - Function to render an item (default: &to_string/1)
    * `:filter_item` - Function to filter an item (default: string contains)
    * `:on_select` - Function called when an item is selected
    * `:on_submit` - Function called when Enter is pressed
  """

  use Raxol.Component
  alias Raxol.Core.Style.Color

  @default_height 10
  @default_width 40
  @default_style %{
    text_color: :white,
    selected_color: :blue,
    selected_text_color: :white
  }

  @impl true
  def init(props) do
    items = props[:items] || []
    %{
      items: items,
      filtered_items: items,
      selected_index: props[:selected_index] || 0,
      height: props[:height] || @default_height,
      width: props[:width] || @default_width,
      style: Map.merge(@default_style, props[:style] || %{}),
      filter: props[:filter] || "",
      scroll_offset: 0,
      render_item: props[:render_item] || &to_string/1,
      filter_item: props[:filter_item] || &default_filter/2,
      on_select: props[:on_select],
      on_submit: props[:on_submit],
      focused: false
    }
  end

  @impl true
  def update({:set_items, items}, state) do
    filtered = filter_items(items, state.filter, state.filter_item)
    %{state |
      items: items,
      filtered_items: filtered,
      selected_index: 0,
      scroll_offset: 0
    }
  end

  def update({:set_filter, filter}, state) do
    filtered = filter_items(state.items, filter, state.filter_item)
    %{state |
      filter: filter,
      filtered_items: filtered,
      selected_index: 0,
      scroll_offset: 0
    }
  end

  def update({:select_index, index}, state) do
    new_index = clamp(index, 0, length(state.filtered_items) - 1)
    new_scroll = adjust_scroll(new_index, state.scroll_offset, state.height)
    
    new_state = %{state |
      selected_index: new_index,
      scroll_offset: new_scroll
    }

    if state.on_select do
      state.on_select.(Enum.at(state.filtered_items, new_index))
    end

    new_state
  end

  def update(:scroll_up, state) do
    new_scroll = max(0, state.scroll_offset - 1)
    %{state | scroll_offset: new_scroll}
  end

  def update(:scroll_down, state) do
    max_scroll = max(0, length(state.filtered_items) - state.height)
    new_scroll = min(max_scroll, state.scroll_offset + 1)
    %{state | scroll_offset: new_scroll}
  end

  def update(:focus, state), do: %{state | focused: true}
  def update(:blur, state), do: %{state | focused: false}
  def update(_msg, state), do: state

  @impl true
  def render(state) do
    visible_items = Enum.slice(state.filtered_items, state.scroll_offset, state.height)
    
    box do
      column do
        for {item, index} <- Enum.with_index(visible_items) do
          actual_index = index + state.scroll_offset
          render_item(item, actual_index == state.selected_index, state)
        end
      end
    end
  end

  defp render_item(item, selected?, state) do
    text = state.render_item.(item)
    padded_text = String.pad_trailing(text, state.width)

    if selected? do
      text(
        content: padded_text,
        color: state.style.selected_text_color,
        background: state.style.selected_color
      )
    else
      text(content: padded_text, color: state.style.text_color)
    end
  end

  @impl true
  def handle_event(%Event{type: :key} = event, state) when state.focused do
    case event do
      %{key: "ArrowUp"} ->
        {update({:select_index, state.selected_index - 1}, state), []}

      %{key: "ArrowDown"} ->
        {update({:select_index, state.selected_index + 1}, state), []}

      %{key: "PageUp"} ->
        {update({:select_index, state.selected_index - state.height}, state), []}

      %{key: "PageDown"} ->
        {update({:select_index, state.selected_index + state.height}, state), []}

      %{key: "Home"} ->
        {update({:select_index, 0}, state), []}

      %{key: "End"} ->
        {update({:select_index, length(state.filtered_items) - 1}, state), []}

      %{key: "Enter"} ->
        if state.on_submit do
          state.on_submit.(Enum.at(state.filtered_items, state.selected_index))
        end
        {state, []}

      %{key: key} when byte_size(key) == 1 ->
        # Type-ahead search
        new_filter = state.filter <> key
        {update({:set_filter, new_filter}, state), []}

      %{key: "Backspace"} ->
        if String.length(state.filter) > 0 do
          new_filter = String.slice(state.filter, 0, -1)
          {update({:set_filter, new_filter}, state), []}
        else
          {state, []}
        end

      _ ->
        {state, []}
    end
  end

  def handle_event(%Event{type: :click}, state) do
    {update(:focus, state), []}
  end

  def handle_event(%Event{type: :blur}, state) do
    {update(:blur, state), []}
  end

  def handle_event(%Event{type: :scroll, direction: :up}, state) do
    {update(:scroll_up, state), []}
  end

  def handle_event(%Event{type: :scroll, direction: :down}, state) do
    {update(:scroll_down, state), []}
  end

  def handle_event(_event, state), do: {state, []}

  # Helper functions
  defp clamp(value, min, max) do
    value |> max(min) |> min(max)
  end

  defp adjust_scroll(selected_index, scroll_offset, height) do
    cond do
      selected_index < scroll_offset ->
        selected_index
      selected_index >= scroll_offset + height ->
        selected_index - height + 1
      true ->
        scroll_offset
    end
  end

  defp filter_items(items, filter, filter_fn) do
    if filter == "" do
      items
    else
      Enum.filter(items, &filter_fn.(&1, filter))
    end
  end

  defp default_filter(item, filter) do
    item_str = to_string(item)
    filter_str = String.downcase(filter)
    String.contains?(String.downcase(item_str), filter_str)
  end
end 