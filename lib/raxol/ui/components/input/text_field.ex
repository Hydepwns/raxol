defmodule Raxol.UI.Components.Input.TextField do
  @moduledoc """
  A text field component for single-line text input.

  It supports validation, placeholders, masks, and styling.
  """
  alias Raxol.Core.Renderer.Element
  alias Raxol.UI.Theming.Theme

  @behaviour Raxol.UI.Components.Base.Component

  @typedoc """
  State for the TextField component.

  - :id - unique identifier
  - :value - current text value
  - :placeholder - placeholder text
  - :style - style map
  - :theme - theme map
  - :disabled - whether the field is disabled
  - :secret - whether to mask input (e.g., password)
  - :focused - whether the field is focused
  - :cursor_pos - cursor position
  - :scroll_offset - horizontal scroll offset
  - :width - visible width of the field (not in defstruct, but added in init)
  """
  @type t :: %__MODULE__{
          id: any(),
          value: String.t(),
          placeholder: String.t(),
          style: map(),
          theme: map(),
          disabled: boolean(),
          secret: boolean(),
          focused: boolean(),
          cursor_pos: non_neg_integer(),
          scroll_offset: non_neg_integer(),
          width: non_neg_integer()
        }

  defstruct id: nil,
            value: "",
            placeholder: "",
            style: %{},
            theme: %{},
            disabled: false,
            secret: false,
            # Internal state
            focused: false,
            cursor_pos: 0,
            scroll_offset: 0,
            width: 20

  @doc """
  Initializes the TextField component state from the given props.
  """
  @spec init(map()) :: {:ok, map()}
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    id = props[:id] || Raxol.Core.ID.generate()
    width = props[:width] || 20
    state = struct!(__MODULE__, Map.merge(%{id: id}, props))
    state = Map.put(state, :width, width)
    {:ok, state}
  end

  @doc """
  Mounts the TextField component. Performs any setup needed after initialization.
  """
  @spec mount(map()) :: map()
  @impl Raxol.UI.Components.Base.Component
  def mount(state), do: state

  @doc """
  Updates the TextField component state in response to messages or prop changes.
  """
  @spec update(term(), map()) :: {:noreply, map()} | {:noreply, map(), any()}
  @impl Raxol.UI.Components.Base.Component
  def update({:update_props, new_props}, state) do
    updated_state = Map.merge(state, Map.new(new_props))
    # Clamp cursor position if value changed
    cursor_pos =
      clamp(updated_state.cursor_pos, 0, String.length(updated_state.value))

    # Clamp scroll_offset if width changed
    width = Map.get(updated_state, :width, 20)

    scroll_offset =
      clamp(
        updated_state.scroll_offset,
        0,
        max(0, String.length(updated_state.value) - width)
      )

    {:noreply,
     %{
       updated_state
       | cursor_pos: cursor_pos,
         scroll_offset: scroll_offset,
         width: width
     }}
  end

  def update({:move_cursor_to, {_row, col}}, state) do
    # Convert column position to cursor position, accounting for scroll offset
    new_cursor_pos =
      clamp(col + state.scroll_offset, 0, String.length(state.value))

    width = Map.get(state, :width, 20)

    new_scroll_offset =
      adjust_scroll_offset(
        new_cursor_pos,
        width,
        state.value,
        state.scroll_offset
      )

    {:noreply,
     %{
       state
       | cursor_pos: new_cursor_pos,
         scroll_offset: new_scroll_offset
     }}
  end

  # Handle focus/blur implicitly via context for now
  # def update(:focus, state), do: {:noreply, %{state | focused: true}}
  # def update(:blur, state), do: {:noreply, %{state | focused: false}}

  @impl Raxol.UI.Components.Base.Component
  def update(message, state) do
    _message = message
    {:noreply, state}
  end

  @doc """
  Handles events for the TextField component, such as keypresses, focus, and blur.
  """
  @spec handle_event(map(), term(), map()) ::
          {:noreply, map()} | {:noreply, map(), any()}
  @impl Raxol.UI.Components.Base.Component
  def handle_event(
        %{disabled: true} = state,
        {:keypress, _key, _modifiers},
        _context
      ) do
    {:noreply, state}
  end

  def handle_event(state, {:keypress, key, modifiers}, context) do
    handle_keypress(state, key, modifiers, context)
  end

  def handle_event(state, {:focus}, _context) do
    {:noreply, %{state | focused: true}}
  end

  def handle_event(state, {:blur}, _context) do
    {:noreply, %{state | focused: false}}
  end

  def handle_event(state, {:mouse, {:click, {_x, y}}}, _context) do
    # Handle mouse clicks to position cursor
    {:update, {:move_cursor_to, {0, y}}, state}
  end

  def handle_event(state, _event, _context) do
    {:noreply, state}
  end

  defp handle_keypress(state, key, _modifiers, context) when is_binary(key) do
    _context = context
    # Insert character
    {left, right} = String.split_at(state.value, state.cursor_pos)
    new_value = left <> key <> right
    new_cursor_pos = state.cursor_pos + String.length(key)
    width = Map.get(state, :width, 20)

    new_scroll_offset =
      adjust_scroll_offset(
        new_cursor_pos,
        width,
        new_value,
        state.scroll_offset
      )

    {:noreply,
     %{
       state
       | value: new_value,
         cursor_pos: new_cursor_pos,
         scroll_offset: new_scroll_offset
     }}
  end

  defp handle_keypress(
         %{cursor_pos: 0} = state,
         :backspace,
         _modifiers,
         _context
       ) do
    {:noreply, state}
  end

  defp handle_keypress(state, :backspace, _modifiers, _context) do
    {left, right} = String.split_at(state.value, state.cursor_pos)
    new_value = String.slice(left, 0, String.length(left) - 1) <> right
    new_cursor_pos = state.cursor_pos - 1
    width = Map.get(state, :width, 20)

    new_scroll_offset =
      adjust_scroll_offset(
        new_cursor_pos,
        width,
        new_value,
        state.scroll_offset
      )

    {:noreply,
     %{
       state
       | value: new_value,
         cursor_pos: new_cursor_pos,
         scroll_offset: new_scroll_offset
     }}
  end

  defp handle_keypress(state, :delete, _modifiers, _context)
       when state.cursor_pos >= byte_size(state.value) do
    {:noreply, state}
  end

  defp handle_keypress(state, :delete, _modifiers, _context) do
    {left, right} = String.split_at(state.value, state.cursor_pos)
    new_value = left <> String.slice(right, 1, String.length(right) - 1)
    width = Map.get(state, :width, 20)

    new_scroll_offset =
      adjust_scroll_offset(
        state.cursor_pos,
        width,
        new_value,
        state.scroll_offset
      )

    {:noreply, %{state | value: new_value, scroll_offset: new_scroll_offset}}
  end

  defp handle_keypress(state, :arrow_left, _modifiers, _context) do
    new_cursor_pos = clamp(state.cursor_pos - 1, 0, String.length(state.value))
    width = Map.get(state, :width, 20)

    new_scroll_offset =
      adjust_scroll_offset(
        new_cursor_pos,
        width,
        state.value,
        state.scroll_offset
      )

    {:noreply,
     %{state | cursor_pos: new_cursor_pos, scroll_offset: new_scroll_offset}}
  end

  defp handle_keypress(state, :arrow_right, _modifiers, _context) do
    new_cursor_pos = clamp(state.cursor_pos + 1, 0, String.length(state.value))
    width = Map.get(state, :width, 20)

    new_scroll_offset =
      adjust_scroll_offset(
        new_cursor_pos,
        width,
        state.value,
        state.scroll_offset
      )

    {:noreply,
     %{state | cursor_pos: new_cursor_pos, scroll_offset: new_scroll_offset}}
  end

  defp handle_keypress(state, :home, _modifiers, _context) do
    {:noreply, %{state | cursor_pos: 0, scroll_offset: 0}}
  end

  defp handle_keypress(state, :end, _modifiers, _context) do
    new_cursor_pos = String.length(state.value)
    width = Map.get(state, :width, 20)

    new_scroll_offset =
      adjust_scroll_offset(
        new_cursor_pos,
        width,
        state.value,
        state.scroll_offset
      )

    {:noreply,
     %{state | cursor_pos: new_cursor_pos, scroll_offset: new_scroll_offset}}
  end

  # Ignore other key presses for now
  defp handle_keypress(state, _key, _modifiers, _context) do
    {:noreply, state}
  end

  @doc """
  Renders the TextField component using the current state and context.
  """
  @spec render(map(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  def render(state, _context) do
    merged_style = get_merged_style(state)
    {visible_value, showing_placeholder} = get_visible_value(state)

    text_children =
      build_text_children(
        state,
        visible_value,
        showing_placeholder,
        merged_style
      )

    Element.new(:view, %{style: merged_style}, do: text_children)
  end

  defp get_merged_style(state) do
    theme = Map.get(state, :theme, %{})
    component_theme_style = Theme.component_style(theme, :text_field)

    case component_theme_style do
      %Raxol.Style{} = style_struct ->
        Raxol.Style.merge(style_struct, state.style)

      plain_map when is_map(plain_map) ->
        Map.merge(plain_map, state.style || %{})

      _ ->
        state.style || %{}
    end
  end

  defp get_visible_value(state) do
    display_value = get_display_value(state.secret, state.value)

    showing_placeholder =
      should_show_placeholder(display_value, state.focused, state.placeholder)

    final_value =
      get_final_value(showing_placeholder, state.placeholder, display_value)

    width = Map.get(state, :width, 20)
    scroll_offset = state.scroll_offset || 0

    visible_value =
      slice_visible_value(
        showing_placeholder,
        final_value,
        scroll_offset,
        width
      )

    {visible_value, showing_placeholder}
  end

  defp get_display_value(true, value),
    do: String.duplicate("•", String.length(value))

  defp get_display_value(false, value), do: value

  defp should_show_placeholder(display_value, focused, placeholder) do
    String.length(display_value) == 0 && !focused && placeholder != ""
  end

  defp get_final_value(true, placeholder, _display_value), do: placeholder
  defp get_final_value(false, _placeholder, display_value), do: display_value

  defp slice_visible_value(true, final_value, _scroll_offset, width) do
    String.slice(final_value, 0, width)
  end

  defp slice_visible_value(false, final_value, scroll_offset, width) do
    String.slice(final_value, scroll_offset, width)
  end

  defp build_text_children(
         state,
         visible_value,
         showing_placeholder,
         merged_style
       ) do
    select_text_children(
      showing_placeholder,
      state.focused,
      state,
      visible_value,
      merged_style
    )
  end

  defp select_text_children(true, _focused, _state, visible_value, merged_style) do
    build_placeholder_children(visible_value, merged_style)
  end

  defp select_text_children(false, true, state, visible_value, merged_style) do
    build_focused_children(state, visible_value, merged_style)
  end

  defp select_text_children(false, false, _state, visible_value, _merged_style) do
    build_normal_children(visible_value)
  end

  defp build_placeholder_children(visible_value, merged_style) do
    placeholder_style = %{
      color: Map.get(merged_style, :placeholder_color, "#888"),
      text_decoration: [:italic]
    }

    [
      Element.new(:text, placeholder_style, do: [])
      |> Map.put(:content, visible_value)
    ]
  end

  defp build_focused_children(state, visible_value, merged_style) do
    width = Map.get(state, :width, 20)
    scroll_offset = state.scroll_offset || 0
    cursor_in_window = state.cursor_pos - scroll_offset
    cursor_in_window = clamp(cursor_in_window, 0, width)
    {left, right} = String.split_at(visible_value, cursor_in_window)

    cursor_style = %{
      text_decoration: [:underline],
      color: merged_style.color || "#fff",
      background: merged_style.background || "#000"
    }

    [
      Element.new(:text, %{}, do: []) |> Map.put(:content, left),
      Element.new(:text, cursor_style, do: []) |> Map.put(:content, "|"),
      Element.new(:text, %{}, do: []) |> Map.put(:content, right)
    ]
  end

  defp build_normal_children(visible_value) do
    [
      Element.new(:text, %{}, do: [])
      |> Map.put(:content, visible_value || "")
    ]
  end

  @doc """
  Unmounts the TextField component, performing any necessary cleanup.
  """
  @impl Raxol.UI.Components.Base.Component
  def unmount(state), do: state

  defp clamp(value, min_val, max_val), do: max(min_val, min(value, max_val))

  # Helper to keep the cursor visible in the window
  defp adjust_scroll_offset(cursor_pos, width, value, scroll_offset) do
    calculate_new_scroll_offset(cursor_pos, width, value, scroll_offset)
  end

  defp calculate_new_scroll_offset(cursor_pos, _width, _value, scroll_offset)
       when cursor_pos < scroll_offset,
       do: cursor_pos

  defp calculate_new_scroll_offset(cursor_pos, width, _value, scroll_offset)
       when cursor_pos > scroll_offset + width - 1,
       do: cursor_pos - width + 1

  defp calculate_new_scroll_offset(_cursor_pos, width, value, scroll_offset)
       when byte_size(value) - scroll_offset < width,
       do: max(0, String.length(value) - width)

  defp calculate_new_scroll_offset(_cursor_pos, _width, _value, scroll_offset),
    do: scroll_offset
end
