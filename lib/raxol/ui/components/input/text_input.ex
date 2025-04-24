defmodule Raxol.UI.Components.Input.TextInput do
  @moduledoc """
  A text input component for capturing user text input.

  Features:
  * Customizable placeholder text
  * Value binding
  * Focus handling
  * Character validation
  * Input masking (for password fields)
  * Event callbacks
  """

  alias Raxol.UI.Components.Base.Component
  alias Raxol.UI.Theming.Theme
  alias Raxol.UI.Theming.Colors

  @behaviour Component

  @type props :: %{
          optional(:id) => String.t(),
          optional(:value) => String.t(),
          optional(:placeholder) => String.t(),
          optional(:on_change) => (String.t() -> any()),
          optional(:on_submit) => (String.t() -> any()),
          optional(:max_length) => integer(),
          optional(:width) => integer(),
          optional(:is_password) => boolean(),
          optional(:validate) => (String.t() -> boolean()),
          optional(:theme) => map()
        }

  @type state :: %{
          value: String.t(),
          focused: boolean(),
          cursor_pos: integer(),
          scroll_offset: integer()
        }

  @type t :: %{
          props: props(),
          state: state()
        }

  @impl Component
  def create(props) do
    %{
      props: normalize_props(props),
      state: %{
        value: props[:value] || "",
        focused: false,
        cursor_pos: 0,
        scroll_offset: 0
      }
    }
  end

  @impl Component
  def update(component, new_props) do
    # Update props and recalculate anything dependent on props
    updated_props = Map.merge(component.props, normalize_props(new_props))

    # Update value if changed externally (e.g. from a binding)
    state =
      if Map.has_key?(new_props, :value) && new_props.value != component.state.value do
        %{component.state | value: new_props.value || ""}
      else
        component.state
      end

    %{component | props: updated_props, state: state}
  end

  @impl Component
  def handle_event(component, {:key_press, key, modifiers}, _context) do
    case {key, modifiers} do
      {:backspace, _} ->
        # Handle backspace
        if component.state.cursor_pos > 0 do
          {before_cursor, after_cursor} = split_at_cursor(component)
          new_value = String.slice(before_cursor, 0..-2) <> after_cursor
          new_cursor_pos = component.state.cursor_pos - 1
          updated = update_value(component, new_value, new_cursor_pos)
          {:ok, updated}
        else
          {:ok, component}
        end

      {:delete, _} ->
        # Handle delete
        {before_cursor, after_cursor} = split_at_cursor(component)
        if String.length(after_cursor) > 0 do
          new_value = before_cursor <> String.slice(after_cursor, 1..-1)
          updated = update_value(component, new_value, component.state.cursor_pos)
          {:ok, updated}
        else
          {:ok, component}
        end

      {:left, _} ->
        # Move cursor left
        if component.state.cursor_pos > 0 do
          new_cursor_pos = component.state.cursor_pos - 1
          {:ok, %{component | state: %{component.state | cursor_pos: new_cursor_pos}}}
        else
          {:ok, component}
        end

      {:right, _} ->
        # Move cursor right
        if component.state.cursor_pos < String.length(component.state.value) do
          new_cursor_pos = component.state.cursor_pos + 1
          {:ok, %{component | state: %{component.state | cursor_pos: new_cursor_pos}}}
        else
          {:ok, component}
        end

      {:home, _} ->
        # Move cursor to beginning
        {:ok, %{component | state: %{component.state | cursor_pos: 0}}}

      {:end, _} ->
        # Move cursor to end
        new_cursor_pos = String.length(component.state.value)
        {:ok, %{component | state: %{component.state | cursor_pos: new_cursor_pos}}}

      {:enter, _} ->
        # Submit the input
        if on_submit = component.props[:on_submit] do
          on_submit.(component.state.value)
        end
        {:ok, component}

      {:escape, _} ->
        # Blur the input
        {:ok, %{component | state: %{component.state | focused: false}}}

      {char, _} when is_binary(char) and byte_size(char) == 1 ->
        # Handle character input
        max_length = component.props[:max_length]
        if max_length && String.length(component.state.value) >= max_length do
          {:ok, component}
        else
          {before_cursor, after_cursor} = split_at_cursor(component)
          new_value = before_cursor <> char <> after_cursor

          # Validate if needed
          if validate = component.props[:validate] do
            if validate.(new_value) do
              new_cursor_pos = component.state.cursor_pos + 1
              updated = update_value(component, new_value, new_cursor_pos)
              {:ok, updated}
            else
              {:ok, component}
            end
          else
            new_cursor_pos = component.state.cursor_pos + 1
            updated = update_value(component, new_value, new_cursor_pos)
            {:ok, updated}
          end
        end

      _ ->
        {:ok, component}
    end
  end

  @impl Component
  def handle_event(component, {:mouse_event, :click, _x, _y, _button}, _context) do
    # Handle click - focus the text input
    {:ok, %{component | state: %{component.state | focused: true}}}
  end

  @impl Component
  def handle_event(component, _event, _context) do
    {:ok, component}
  end

  @impl Component
  def render(component, _context) do
    props = component.props
    state = component.state
    theme = props[:theme] || Theme.get_current()
    colors = theme[:input] || %{fg: :white, bg: :black, placeholder: :gray, border: :blue}

    # Get the displayed text
    display_value =
      if state.value == "" do
        %{text: props[:placeholder] || "", fg: colors.placeholder}
      else
        if props[:is_password] do
          # Mask password input with asterisks
          %{text: String.duplicate("*", String.length(state.value)), fg: colors.fg}
        else
          %{text: state.value, fg: colors.fg}
        end
      end

    # Calculate the visible portion if text is longer than width
    width = props[:width] || 20
    visible_width = width - 2  # Accounting for borders

    {visible_text, cursor_x} = calculate_visible_text(
      display_value.text,
      state.cursor_pos,
      state.scroll_offset,
      visible_width
    )

    # Create the input box with border
    input_elements = [
      # Box border
      %{
        type: :box,
        width: width,
        height: 1,
        attrs: %{
          fg: if(state.focused, do: colors.border, else: colors.fg),
          bg: colors.bg,
          border: %{
            top_left: "[",
            top_right: "]",
            bottom_left: "[",
            bottom_right: "]",
            horizontal: " ",
            vertical: "|"
          }
        }
      },
      # Input text
      %{
        type: :text,
        x: 1,  # Inside the box
        y: 0,
        text: visible_text,
        attrs: %{
          fg: display_value.fg,
          bg: colors.bg
        }
      }
    ]

    # Add cursor if focused
    input_elements =
      if state.focused do
        cursor_element = %{
          type: :cursor,
          x: cursor_x + 1,  # +1 to account for left border
          y: 0,
          attrs: %{
            fg: colors.fg,
            bg: colors.bg
          }
        }
        [cursor_element | input_elements]
      else
        input_elements
      end

    input_elements
  end

  # Private helper functions

  defp normalize_props(props) do
    # Ensure props have expected types and defaults
    props = Map.new(props)

    props
    |> Map.put_new(:placeholder, "")
    |> Map.put_new(:max_length, nil)
    |> Map.put_new(:is_password, false)
  end

  defp update_value(component, new_value, new_cursor_pos) do
    # Update the value and trigger on_change callback
    if on_change = component.props[:on_change] do
      on_change.(new_value)
    end

    # Update component state
    updated_state = %{
      component.state |
      value: new_value,
      cursor_pos: new_cursor_pos
    }

    %{component | state: updated_state}
  end

  defp split_at_cursor(component) do
    value = component.state.value
    pos = component.state.cursor_pos

    before_cursor = String.slice(value, 0, pos)
    after_cursor = String.slice(value, pos..-1)

    {before_cursor, after_cursor}
  end

  defp calculate_visible_text(text, cursor_pos, scroll_offset, visible_width) do
    text_length = String.length(text)

    # Adjust scroll_offset if cursor would be outside visible area
    scroll_offset = cond do
      cursor_pos < scroll_offset ->
        # Cursor moved left of visible area
        cursor_pos
      cursor_pos >= scroll_offset + visible_width ->
        # Cursor moved right of visible area
        cursor_pos - visible_width + 1
      true ->
        # Cursor is within visible area
        scroll_offset
    end

    # Calculate end of visible area
    end_offset = min(scroll_offset + visible_width, text_length)

    # Get visible portion of text
    visible_text = String.slice(text, scroll_offset, visible_width)

    # Calculate cursor position within visible area
    visible_cursor_pos = cursor_pos - scroll_offset

    {visible_text, visible_cursor_pos}
  end
end
