defmodule Raxol.UI.Components.Input.TextField do
  @moduledoc '''
  A text field component for single-line text input.

  It supports validation, placeholders, masks, and styling.
  '''
  alias Raxol.Core.Renderer.Element
  alias Raxol.UI.Theming.Theme

  @behaviour Raxol.UI.Components.Base.Component

  @typedoc '''
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
  '''
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

  @doc '''
  Initializes the TextField component state from the given props.
  '''
  @spec init(map()) :: {:ok, map()}
  @impl true
  def init(props) do
    id = props[:id] || Raxol.Core.ID.generate()
    width = props[:width] || 20
    state = struct!(__MODULE__, Map.merge(%{id: id}, props))
    state = Map.put(state, :width, width)
    {:ok, state}
  end

  @doc '''
  Mounts the TextField component. Performs any setup needed after initialization.
  '''
  @spec mount(map()) :: map()
  @impl true
  def mount(state), do: state

  @doc '''
  Updates the TextField component state in response to messages or prop changes.
  '''
  @spec update(term(), map()) :: {:noreply, map()} | {:noreply, map(), any()}
  @impl true
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

  # Handle focus/blur implicitly via context for now
  # TODO: Explicit focus messages?
  # def update(:focus, state), do: {:noreply, %{state | focused: true}}
  # def update(:blur, state), do: {:noreply, %{state | focused: false}}

  @impl true
  def update(message, state) do
    _message = message
    {:noreply, state}
  end

  @doc '''
  Handles events for the TextField component, such as keypresses, focus, and blur.
  '''
  @spec handle_event(map(), term(), map()) ::
          {:noreply, map()} | {:noreply, map(), any()}
  @impl true
  def handle_event(state, {:keypress, key, modifiers}, context) do
    _context = context

    if state.disabled do
      {:noreply, state}
    else
      handle_keypress(state, key, modifiers, context)
    end
  end

  def handle_event(state, {:focus}, _context) do
    {:noreply, %{state | focused: true}}
  end

  def handle_event(state, {:blur}, _context) do
    {:noreply, %{state | focused: false}}
  end

  # TODO: Handle mouse clicks to position cursor
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

  defp handle_keypress(state, :backspace, _modifiers, _context) do
    if state.cursor_pos > 0 do
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
    else
      {:noreply, state}
    end
  end

  defp handle_keypress(state, :delete, _modifiers, _context) do
    if state.cursor_pos < String.length(state.value) do
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
    else
      {:noreply, state}
    end
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

  @doc '''
  Renders the TextField component using the current state and context.
  '''
  @spec render(map(), map()) :: any()
  @impl true
  def render(state, _context) do
    theme = Map.get(state, :theme, %{})
    component_theme_style = Theme.component_style(theme, :text_field)
    style = Raxol.Style.merge(component_theme_style, state.style)

    display_value =
      if state.secret,
        do: String.duplicate("*", String.length(state.value)),
        else: state.value

    # Add placeholder if value is empty and not focused
    showing_placeholder =
      String.length(display_value) == 0 && !state.focused &&
        state.placeholder != ""

    final_value =
      if showing_placeholder do
        # TODO: Style placeholder differently?
        state.placeholder
      else
        display_value
      end

    width = Map.get(state, :width, 20)
    scroll_offset = state.scroll_offset || 0

    visible_value =
      if showing_placeholder do
        String.slice(final_value, 0, width)
      else
        String.slice(final_value, scroll_offset, width)
      end

    # Cursor rendering
    text_children =
      cond do
        showing_placeholder ->
          placeholder_style = %{
            color: Map.get(component_theme_style, :placeholder_color, "#888"),
            text_decoration: [:italic]
          }

          [
            Element.new(:text, placeholder_style, do: [])
            |> Map.put(:content, visible_value)
          ]

        state.focused ->
          # Cursor position relative to visible window
          cursor_in_window = state.cursor_pos - scroll_offset
          cursor_in_window = clamp(cursor_in_window, 0, width)
          {left, right} = String.split_at(visible_value, cursor_in_window)

          cursor_style = %{
            text_decoration: [:underline],
            color: style.color || "#fff",
            background: style.background || "#000"
          }

          [
            Element.new(:text, %{}, do: []) |> Map.put(:content, left),
            Element.new(:text, cursor_style, do: []) |> Map.put(:content, "|"),
            Element.new(:text, %{}, do: []) |> Map.put(:content, right)
          ]

        true ->
          [
            Element.new(:text, %{}, do: [])
            |> Map.put(:content, visible_value || "")
          ]
      end

    Element.new(:view, %{style: style}, do: text_children)
  end

  @doc '''
  Unmounts the TextField component, performing any necessary cleanup.
  '''
  @impl true
  def unmount(state), do: state

  defp clamp(value, min_val, max_val), do: max(min_val, min(value, max_val))

  # Helper to keep the cursor visible in the window
  defp adjust_scroll_offset(cursor_pos, width, value, scroll_offset) do
    cond do
      cursor_pos < scroll_offset ->
        cursor_pos

      cursor_pos > scroll_offset + width - 1 ->
        cursor_pos - width + 1

      String.length(value) - scroll_offset < width ->
        max(0, String.length(value) - width)

      true ->
        scroll_offset
    end
  end
end
