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

  alias Raxol.Core.Events.Subscription
  alias Raxol.View

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
      render_item: props[:render_item] || (&to_string/1),
      filter_item: props[:filter_item] || (&default_filter/2),
      on_select: props[:on_select],
      on_submit: props[:on_submit],
      focused: false
    }
  end

  @impl true
  def update({:set_items, items}, state) do
    filtered = filter_items(items, state.filter, state.filter_item)

    %{
      state
      | items: items,
        filtered_items: filtered,
        selected_index: 0,
        scroll_offset: 0
    }
  end

  def update({:set_filter, filter}, state) do
    filtered = filter_items(state.items, filter, state.filter_item)

    %{
      state
      | filter: filter,
        filtered_items: filtered,
        selected_index: 0,
        scroll_offset: 0
    }
  end

  def update({:select_index, index}, state) do
    new_index = clamp(index, 0, length(state.filtered_items) - 1)
    new_scroll = adjust_scroll(new_index, state.scroll_offset, state.height)

    new_state = %{state | selected_index: new_index, scroll_offset: new_scroll}

    if state.on_select do
      _ = state.on_select.(Enum.at(state.filtered_items, new_index))
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
  @dialyzer {:nowarn_function, render: 1}
  def render(state) do
    dsl_result =
      View.box style: %{width: state.width, height: state.height} do
        state.items
        |> Enum.slice(state.scroll_offset, state.height)
        |> Enum.with_index(state.scroll_offset)
        |> Enum.map(fn {item, index} ->
          render_item(item, index, state)
        end)
      end

    Raxol.View.to_element(dsl_result)
  end

  defp render_item(item, index, state) do
    content = state.render_item.(item)
    is_selected = index == state.selected_index
    # Use component's focused state
    is_focused = is_selected and state.focused

    style =
      cond do
        is_focused -> state.style.focused_item_style
        is_selected -> state.style.selected_item_style
        true -> state.style.item_style
      end

    # Prepend cursor if focused
    display_content = if is_focused, do: "> " <> content, else: "  " <> content

    View.text(display_content, style: style)
  end

  @impl true
  def handle_event(%Event{type: :key, data: data} = _event, state) do
    msg =
      case data do
        %{key: :up} ->
          {:move_selection, :up}

        %{key: :down} ->
          {:move_selection, :down}

        %{key: :page_up} ->
          {:move_selection, :page_up}

        %{key: :page_down} ->
          {:move_selection, :page_down}

        %{key: :home} ->
          {:move_selection, :home}

        %{key: :end} ->
          {:move_selection, :end}

        %{key: :enter} ->
          {:select}

        %{key: key} when is_binary(key) and byte_size(key) == 1 ->
          {:filter, key}

        %{key: :backspace} ->
          {:backspace}

        _ ->
          nil
      end

    if msg do
      {update(msg, state), []}
    else
      {state, []}
    end
  end

  @impl true
  def handle_event(%Event{type: :click}, state) do
    {update(:focus, state), []}
  end

  @impl true
  def handle_event(%Event{type: :blur}, state) do
    {update(:blur, state), []}
  end

  @impl true
  def handle_event(%Event{type: :scroll, data: %{direction: :up}}, state) do
    {update(:scroll_up, state), []}
  end

  @impl true
  def handle_event(%Event{type: :scroll, data: %{direction: :down}}, state) do
    {update(:scroll_down, state), []}
  end

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
