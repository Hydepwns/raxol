defmodule Raxol.Components.Input.TextInput do
  @moduledoc """
  A text input component for single-line text entry.

  Features:
  * Cursor management
  * Text selection
  * Copy/paste support
  * Password masking
  * Placeholder text
  """

  use Raxol.UI.Components.Base.Component
  import Raxol.View.Elements
  alias Raxol.UI.Theming.Theme

  @type state :: %{
          value: String.t(),
          cursor: non_neg_integer(),
          selection: {non_neg_integer(), non_neg_integer()} | nil,
          focused: boolean(),
          placeholder: String.t() | nil,
          password: boolean()
        }

  @doc false
  @impl true
  def init(props) do
    %{
      value: props[:value] || "",
      cursor: 0,
      selection: nil,
      focused: false,
      placeholder: props[:placeholder],
      password: props[:password] || false
    }
  end

  @impl true
  def update(msg, state) do
    new_state =
      case msg do
        {:input, char} when is_integer(char) ->
          insert_char(state, char)

        {:backspace} ->
          delete_char_backward(state)

        {:delete} ->
          delete_char_forward(state)

        {:move_cursor, :left} ->
          move_cursor(state, -1)

        {:move_cursor, :right} ->
          move_cursor(state, 1)

        {:move_cursor, :home} ->
          %{state | cursor: 0}

        {:move_cursor, :end} ->
          %{state | cursor: String.length(state.value)}

        {:focus} ->
          %{state | focused: true}

        {:blur} ->
          %{state | focused: false}

        _ ->
          state
      end
    # Return {state, commands}
    {new_state, []}
  end

  @impl true
  def render(%{assigns: assigns}, context) do
    # Get the theme struct using the context config (assuming it's the theme ID)
    # Fallback to default theme if not found
    theme_id = context.theme_config || :default
    theme = Theme.get(theme_id) || Theme.default_theme()

    display_raw = display_value(assigns)
    # Get base style for text_input from the theme
    base_style = Theme.component_style(theme, :text_input)

    # Add dim style if placeholder is shown
    placeholder_style = if assigns.value == "" and assigns.placeholder, do: %{intensity: :dim}, else: %{}
    # Merge base style with placeholder style
    text_style = Map.merge(base_style, placeholder_style)

    # Determine box style based on focus
    box_style = if assigns.focused do
      # Potentially use a focused variant from theme, or just override border/bg
      Map.merge(base_style, %{border_color: Map.get(theme.colors, :primary, :blue)})
    else
      base_style
    end

    # Use the box macro for the container
    box padding: {0, 1}, border: assigns.focused, border_style: :single, style: box_style do
      if assigns.focused and assigns.value != "" do
        # Split text around cursor
        cursor_pos = assigns.cursor
        {before_cursor, at_cursor_and_after} = String.split_at(display_raw, cursor_pos)
        {at_cursor, after_cursor} = String.split_at(at_cursor_and_after, 1)

        # Render parts with cursor highlighted (using label macro)
        [ # Return a list of elements for the box children
          label(content: before_cursor, style: text_style),
          # Render cursor char with inverse style merged into base style
          label(content: at_cursor, style: Map.merge(text_style, %{inverse: true})),
          label(content: after_cursor, style: text_style)
        ]
      else
        # Not focused or empty, render normally (using label macro)
        label(content: display_raw, style: text_style)
      end
    end
  end

  @impl true
  def handle_event(%{type: :key, data: key_data} = _event, %{} = _props, state) do
    handle_key_event(key_data, state)
  end

  @impl true
  def handle_event(%{type: :focus}, %{} = _props, state) do
    {Map.put(state, :focused, true), []}
  end

  @impl true
  def handle_event(%{type: :blur}, %{} = _props, state) do
    {Map.put(state, :focused, false), []}
  end

  @impl true
  def handle_event(_event, %{} = _props, state), do: {state, []}

  # Private helpers

  defp insert_char(state, char) do
    {before_cursor, after_cursor} = String.split_at(state.value, state.cursor)
    new_value = before_cursor <> <<char::utf8>> <> after_cursor
    %{state | value: new_value, cursor: state.cursor + 1}
  end

  defp delete_char_backward(%{cursor: 0} = state), do: state

  defp delete_char_backward(state) do
    {before_cursor, after_cursor} =
      String.split_at(state.value, state.cursor - 1)
    # Delete character *before* cursor
    new_value = String.slice(before_cursor, 0, state.cursor - 1) <> after_cursor
    %{state | value: new_value, cursor: state.cursor - 1}
  end

  defp delete_char_forward(state) do
    cursor = state.cursor
    value = state.value
    len = String.length(value)

    if cursor < len do
      # Delete character *at* cursor
      {before_cursor, after_cursor} = String.split_at(value, cursor)
      new_value = before_cursor <> String.slice(after_cursor, 1..-1)
      # Cursor position doesn't change
      %{state | value: new_value}
    else
      # Cursor at end, nothing to delete
      state
    end
  end

  defp move_cursor(state, offset) do
    new_cursor = max(0, min(String.length(state.value), state.cursor + offset))
    %{state | cursor: new_cursor}
  end

  defp display_value(%{value: "", placeholder: placeholder})
       when not is_nil(placeholder) do
    placeholder
  end

  defp display_value(%{value: value, password: true}) do
    String.duplicate("*", String.length(value))
  end

  defp display_value(%{value: value}) do
    value
  end

  defp handle_key_event(key_data, state) do
    msg =
      case key_data do
        %{key: char, modifiers: []} when is_binary(char) and byte_size(char) == 1 ->
          {:input, char}

        %{key: :backspace, modifiers: []} ->
          {:backspace}

        %{key: :left, modifiers: []} ->
          {:move_cursor, :left}

        %{key: :right, modifiers: []} ->
          {:move_cursor, :right}

        # TODO: Add Home, End, Delete keys
        %{key: :home, modifiers: []} ->
          {:move_cursor, :home}

        %{key: :end, modifiers: []} ->
          {:move_cursor, :end}

        %{key: :delete, modifiers: []} ->
          {:delete}

        _ ->
          nil # Ignore other keys
      end

    if msg do
      {update(msg, state), []}
    else
      {state, []}
    end
  end

  # TODO: Add options for max length, validation regex/function, etc.
end
