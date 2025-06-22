defmodule Raxol.UI.Components.Input.TextInput.CharacterHandler do
  @moduledoc false

  import Raxol.Guards

  def handle_character(state, char_key) do
    with char_str when not nil?(char_str) <- process_char_key(char_key),
         true <- validate_length(state, char_str),
         true <- validate_char(state, char_str) do
      insert_char_at_cursor(state, char_str)
    else
      _ -> {state, []}
    end
  end

  defp process_char_key(char_key) do
    cond do
      binary?(char_key) and String.length(char_key) == 1 and
          String.printable?(char_key) ->
        char_key

      integer?(char_key) and char_key >= 32 and char_key <= 126 ->
        <<char_key::utf8>>

      true ->
        nil
    end
  end

  defp validate_length(state, char_str) do
    current_value = state.value || ""
    max_length = state.max_length
    !max_length || String.length(current_value) < max_length
  end

  defp validate_char(state, char_str) do
    validator = state.validator
    !function?(validator, 1) || validator.(char_str)
  end

  defp insert_char_at_cursor(state, char_str) do
    current_value = state.value || ""
    cursor_pos = state.cursor_pos
    before = String.slice(current_value, 0, cursor_pos)
    after_text = String.slice(current_value, cursor_pos..-1//1) || ""
    new_value = before <> char_str <> after_text
    new_cursor_pos = cursor_pos + 1

    new_state = %{
      state
      | cursor_pos: new_cursor_pos,
        value: new_value
    }

    emit_change_side_effect(state, new_value)
    {new_state, []}
  end

  defp emit_change_side_effect(state, new_value) do
    if function?(state.on_change, 1) do
      state.on_change.(new_value)
    end
  end
end
