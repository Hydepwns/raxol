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
  require Raxol.Core.Renderer.View

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
          delete_char(state)

        {:cursor, :left} ->
          move_cursor(state, -1)

        {:cursor, :right} ->
          move_cursor(state, 1)

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
  def render(%{} = _props, state) do
    # Render using basic Raxol.View elements
    display = display_value(state)
    style = if state.focused, do: [:bold], else: []
    # Add placeholder styling if needed
    style =
      if state.value == "" and state.placeholder,
        do: style ++ [:dim],
        else: style

    # TODO: Implement visual cursor rendering (e.g., underscore or inverse)
    # This is complex due to character widths and terminal capabilities.
    # For now, just render the text content with focus style.
    dsl_result = Raxol.Core.Renderer.View.text(display, style: style)
    dsl_result
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

  defp delete_char(%{cursor: 0} = state), do: state

  defp delete_char(state) do
    {before_cursor, after_cursor} =
      String.split_at(state.value, state.cursor - 1)

    %{state | value: before_cursor <> after_cursor, cursor: state.cursor - 1}
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
