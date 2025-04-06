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

  use Raxol.Component
  # alias Raxol.Style # Unused
  alias Raxol.Core.Events.Event

  @type state :: %{
    value: String.t(),
    cursor: non_neg_integer(),
    selection: {non_neg_integer(), non_neg_integer()} | nil,
    focused: boolean(),
    placeholder: String.t() | nil,
    password: boolean()
  }

  # @default_width 40 # Unused

  # @behaviour Raxol.Component # Redundant: already included by `use Raxol.Component`

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
  end

  @impl true
  def render(state) do
    # TODO: Raxol.View.input is undefined. TextInput needs refactoring to use
    # Raxol.Core.Renderer.View or a dedicated input rendering mechanism.
    # Commenting out for now to allow compilation.
    # View.input(
    #   value: display_value(state),
    #   cursor: state.cursor,
    #   focused: state.focused,
    #   placeholder: state.placeholder
    # )

    # Placeholder return until refactoring
    Raxol.Core.Renderer.View.text(
      "[Input: #{display_value(state)}] (render broken)",
      [style: if(state.focused, do: [:bold], else: [])]
    )
  end

  @impl true
  def handle_event(%Event{type: :key, data: key_data} = _event, state) do
    msg =
      case key_data do
        {:char, c} -> {:input, c}
        :backspace -> {:backspace}
        :left -> {:cursor, :left}
        :right -> {:cursor, :right}
        _ -> nil
      end

    if msg do
      {update(msg, state), []}
    else
      {state, []}
    end
  end

  def handle_event(%Event{type: :focus}, state) do
    {update({:focus}, state), []}
  end

  def handle_event(%Event{type: :blur}, state) do
    {update({:blur}, state), []}
  end

  def handle_event(_, state), do: {state, []}

  # Private helpers

  defp insert_char(state, char) do
    {before_cursor, after_cursor} = String.split_at(state.value, state.cursor)
    new_value = before_cursor <> <<char::utf8>> <> after_cursor
    %{state | value: new_value, cursor: state.cursor + 1}
  end

  defp delete_char(%{cursor: 0} = state), do: state
  defp delete_char(state) do
    {before_cursor, after_cursor} = String.split_at(state.value, state.cursor - 1)
    %{state | value: before_cursor <> after_cursor, cursor: state.cursor - 1}
  end

  defp move_cursor(state, offset) do
    new_cursor = max(0, min(String.length(state.value), state.cursor + offset))
    %{state | cursor: new_cursor}
  end

  defp display_value(%{value: "", placeholder: placeholder}) when not is_nil(placeholder) do
    placeholder
  end
  defp display_value(%{value: value, password: true}) do
    String.duplicate("*", String.length(value))
  end
  defp display_value(%{value: value}) do
    value
  end
end
