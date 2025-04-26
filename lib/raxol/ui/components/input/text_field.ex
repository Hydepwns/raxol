defmodule Raxol.UI.Components.Input.TextField do
  @moduledoc """
  A text field component for single-line text input.

  It supports validation, placeholders, masks, and styling.
  """
  alias Raxol.Core.Renderer.Element
  alias Raxol.UI.Theming.Theme

  @behaviour Raxol.UI.Components.Base.Component

  defstruct id: nil,
            value: "",
            placeholder: "",
            style: %{},
            disabled: false,
            secret: false,
            # Internal state
            focused: false,
            cursor_pos: 0

  @impl true
  def init(props) do
    id = props[:id] || Raxol.Core.ID.generate()
    state = struct!(__MODULE__, Keyword.merge([id: id], props))
    {:ok, state}
  end

  @impl true
  def mount(_state), do: {:ok, []}

  @impl true
  def update({:update_props, new_props}, state) do
    updated_state = Map.merge(state, Map.new(new_props))
    # Clamp cursor position if value changed
    cursor_pos =
      clamp(updated_state.cursor_pos, 0, String.length(updated_state.value))

    {:noreply, %{updated_state | cursor_pos: cursor_pos}}
  end

  # Handle focus/blur implicitly via context for now
  # TODO: Explicit focus messages?
  # def update(:focus, state), do: {:noreply, %{state | focused: true}}
  # def update(:blur, state), do: {:noreply, %{state | focused: false}}

  @impl true
  def update(message, state) do
    IO.inspect(message, label: "Unhandled TextField update")
    {:noreply, state}
  end

  @impl true
  def handle_event(state, {:keypress, key, modifiers}, context) do
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

  defp handle_keypress(state, key, _modifiers, _context) when is_binary(key) do
    # Insert character
    {left, right} = String.split_at(state.value, state.cursor_pos)
    new_value = left <> key <> right
    new_cursor_pos = state.cursor_pos + String.length(key)
    {:noreply, %{state | value: new_value, cursor_pos: new_cursor_pos}}
  end

  defp handle_keypress(state, :backspace, _modifiers, _context) do
    if state.cursor_pos > 0 do
      {left, right} = String.split_at(state.value, state.cursor_pos)
      new_value = String.slice(left, 0, String.length(left) - 1) <> right
      new_cursor_pos = state.cursor_pos - 1
      {:noreply, %{state | value: new_value, cursor_pos: new_cursor_pos}}
    else
      {:noreply, state}
    end
  end

  defp handle_keypress(state, :delete, _modifiers, _context) do
    if state.cursor_pos < String.length(state.value) do
      {left, right} = String.split_at(state.value, state.cursor_pos)
      new_value = left <> String.slice(right, 1, String.length(right) - 1)
      {:noreply, %{state | value: new_value}}
    else
      {:noreply, state}
    end
  end

  defp handle_keypress(state, :arrow_left, _modifiers, _context) do
    new_cursor_pos = clamp(state.cursor_pos - 1, 0, String.length(state.value))
    {:noreply, %{state | cursor_pos: new_cursor_pos}}
  end

  defp handle_keypress(state, :arrow_right, _modifiers, _context) do
    new_cursor_pos = clamp(state.cursor_pos + 1, 0, String.length(state.value))
    {:noreply, %{state | cursor_pos: new_cursor_pos}}
  end

  defp handle_keypress(state, :home, _modifiers, _context) do
    {:noreply, %{state | cursor_pos: 0}}
  end

  defp handle_keypress(state, :end, _modifiers, _context) do
    {:noreply, %{state | cursor_pos: String.length(state.value)}}
  end

  # Ignore other key presses for now
  defp handle_keypress(state, _key, _modifiers, _context) do
    {:noreply, state}
  end

  @impl true
  def render(state, context) do
    theme = context.theme
    component_theme_style = Theme.component_style(theme, :text_field)
    style = Raxol.Style.merge(component_theme_style, state.style)

    display_value =
      if state.secret,
        do: String.duplicate("*", String.length(state.value)),
        else: state.value

    # Add placeholder if value is empty and not focused
    final_value =
      if String.length(display_value) == 0 && !state.focused &&
           state.placeholder != "" do
        # TODO: Style placeholder differently?
        state.placeholder
      else
        display_value
      end

    # TODO: Add cursor rendering
    # TODO: Add scrolling for long text
    Element.new(
      :view,
      %{style: style},
      [Element.new(:text, %{}, final_value)]
    )
  end

  @impl true
  def unmount(_state), do: :ok

  defp clamp(value, min_val, max_val), do: max(min_val, min(value, max_val))
end
