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
          width: non_neg_integer(),
          mounted: boolean(),
          render_count: non_neg_integer(),
          type: atom(),
          text: String.t()
        }

  defstruct id: nil,
            value: "",
            placeholder: "",
            style: %{},
            theme: %{},
            disabled: false,
            secret: false,
            focused: false,
            cursor_pos: 0,
            scroll_offset: 0,
            width: 20,
            mounted: false,
            render_count: 0,
            type: :text_field,
            text: ""

  @doc """
  Initializes the TextField component state from the given props.
  """
  @spec init(map()) :: {:ok, map()}
  @impl true
  def init(props) when is_map(props) do
    id = props[:id] || Raxol.Core.ID.generate()
    width = props[:width] || 20

    state =
      struct!(
        __MODULE__,
        Map.merge(
          %{
            id: id,
            disabled: Map.get(props, :disabled, false),
            focused: Map.get(props, :focused, false),
            type: :text_field,
            text: ""
          },
          props
        )
      )

    state = Map.put(state, :width, width)
    {:ok, state}
  end

  def init(_),
    do:
      {:ok,
       struct!(__MODULE__, %{type: :text_field, mounted: false, render_count: 0})}

  @doc """
  Mounts the TextField component. Performs any setup needed after initialization.
  """
  @spec mount(map()) :: map()
  @impl true
  def mount(state), do: state

  @doc """
  Updates the TextField component state in response to messages or prop changes.
  """
  @spec update(term(), map()) :: {:noreply, map()} | {:noreply, map(), any()}
  @impl true
  def update({:update_props, new_props}, state) do
    updated_state = Map.merge(state, Map.new(new_props))
    # Clamp cursor position if value changed
    cursor_pos =
      clamp(updated_state.cursor_pos, 0, String.length(updated_state.value))

    # Clamp scroll_offset if width changed
    width =
      if is_map(updated_state),
        do: Map.get(updated_state, :width, 20),
        else: if(is_tuple(updated_state), do: elem(updated_state, 0), else: 20)

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

  @doc """
  Handles events for the TextField component, such as keypresses, focus, and blur.
  """
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

    width =
      if is_map(state),
        do: Map.get(state, :width, 20),
        else: if(is_tuple(state), do: elem(state, 0), else: 20)

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

      width =
        if is_map(state),
          do: Map.get(state, :width, 20),
          else: if(is_tuple(state), do: elem(state, 0), else: 20)

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

      width =
        if is_map(state),
          do: Map.get(state, :width, 20),
          else: if(is_tuple(state), do: elem(state, 0), else: 20)

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

    width =
      if is_map(state),
        do: Map.get(state, :width, 20),
        else: if(is_tuple(state), do: elem(state, 0), else: 20)

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

    width =
      if is_map(state),
        do: Map.get(state, :width, 20),
        else: if(is_tuple(state), do: elem(state, 0), else: 20)

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
    _width =
      if is_map(state),
        do: Map.get(state, :width, 20),
        else: if(is_tuple(state), do: elem(state, 0), else: 20)

    {:noreply, %{state | cursor_pos: 0, scroll_offset: 0}}
  end

  defp handle_keypress(state, :end, _modifiers, _context) do
    width =
      if is_map(state),
        do: Map.get(state, :width, 20),
        else: if(is_tuple(state), do: elem(state, 0), else: 20)

    new_cursor_pos = String.length(state.value)

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
  @impl true
  def render(state, _context) do
    theme_styles = Theme.get_component_style(state.theme, :text_field)
    base_style = Map.merge(theme_styles, state.style)

    # Determine text to display (value, placeholder, or secret)
    text_to_display =
      cond do
        String.length(state.value) == 0 and not state.focused and
            state.placeholder != "" ->
          state.placeholder

        state.secret ->
          String.duplicate("•", String.length(state.value))

        true ->
          state.value
      end

    # Calculate visible part of the text based on scroll offset and width
    scroll_offset = state.scroll_offset
    # Ensure width is an integer, default to 20 if not found or invalid
    width =
      cond do
        is_integer(state.width) and state.width > 0 ->
          state.width

        is_map(state.style) and is_integer(state.style[:width]) and
            state.style[:width] > 0 ->
          state.style[:width]

        true ->
          20
      end

    visible_value = String.slice(text_to_display, scroll_offset, width)

    # Determine the style for the text
    current_text_style =
      if String.length(state.value) == 0 and not state.focused and
           state.placeholder != "" do
        # Placeholder is showing, apply placeholder style
        # Merge base_style with placeholder-specific style from theme or props, then with :placeholder key in state.style
        # Default from theme system
        placeholder_theme_style =
          Map.get(theme_styles, :placeholder, %{
            fg: "#888",
            text_decoration: [:italic]
          })

        # Specific :placeholder style from props
        placeholder_prop_style = Map.get(state.style, :placeholder, %{})

        Map.merge(base_style, placeholder_theme_style)
        |> Map.merge(placeholder_prop_style)
      else
        # Normal value or focused, use base style
        base_style
      end

    # Ensure the text content is padded to fill the field width if it's shorter
    # This helps with consistent background rendering.
    padded_visible_value = String.pad_trailing(visible_value || "", width)

    text_children =
      [
        Element.new(:text, %{}, do: [])
        |> Map.put(:content, padded_visible_value)
        |> Map.put(:style, current_text_style)
      ]

    # If focused and not secret, add cursor rendering (simplified example)
    # A real cursor would be an overlay or a special character with distinct styling.
    # This example just appends a pipe, which isn't ideal.
    # A proper cursor might involve splitting text and inserting a styled cursor element.
    # if state.focused and not state.secret and state.cursor_pos >= scroll_offset and state.cursor_pos <= scroll_offset + width do
    #   cursor_display_pos = state.cursor_pos - scroll_offset
    #   # This is a very basic way to show a cursor, real cursor needs better handling
    #   # visible_value_with_cursor = String.slice(visible_value, 0, cursor_display_pos) <> "|" <> String.slice(visible_value, cursor_display_pos, width)
    #   # text_children = [Element.new(:text, current_text_style) |> Map.put(:content, visible_value_with_cursor)]
    # end

    rendered_view =
      Element.new(:view, %{style: base_style, width: width, height: 1},
        do: text_children
      )

    # At the end, ensure :disabled and :focused are present in the returned map if possible
    if is_map(rendered_view) do
      rendered_view
      |> Map.put_new(:disabled, Map.get(state, :disabled, false))
      |> Map.put_new(:focused, Map.get(state, :focused, false))
    else
      rendered_view
    end
  end

  @doc """
  Unmounts the TextField component, performing any necessary cleanup.
  """
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
