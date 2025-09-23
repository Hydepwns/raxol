defmodule Raxol.UI.Components.Input.TextInput.CharacterHandler do
  @moduledoc false

  def handle_character(state, char_key) do
    with char_str when not is_nil(char_str) <- process_char_key(char_key),
         true <- validate_length(state, char_str),
         true <- validate_char(state, char_str) do
      insert_char_at_cursor(state, char_str)
    else
      _ -> {state, []}
    end
  end

  defp process_char_key(char_key) when is_binary(char_key) do
    validate_char_key(char_key)
  end

  defp process_char_key(char_key)
       when is_integer(char_key) and char_key >= 32 and char_key <= 126 do
    <<char_key::utf8>>
  end

  defp process_char_key(_char_key), do: nil

  defp validate_length(state, _char_str) do
    current_value = state.value || ""
    max_length = state.max_length
    !max_length || String.length(current_value) < max_length
  end

  defp validate_char(state, char_str) do
    validator = state.validator
    !is_function(validator, 1) || validator.(char_str)
  end

  defp insert_char_at_cursor(state, char_str) do
    current_value = state.value || ""
    cursor_pos = state.cursor_pos
    before = String.slice(current_value, 0, cursor_pos)
    after_text = String.slice(current_value, cursor_pos..-1//1)
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
    execute_on_change(state.on_change, new_value)
  end

  # Helper functions for if-statement elimination
  defp validate_char_key(char_key) do
    handle_char_validation(
      String.length(char_key) == 1 and String.printable?(char_key),
      char_key
    )
  end

  defp handle_char_validation(true, char_key), do: char_key
  defp handle_char_validation(false, _char_key), do: nil

  defp execute_on_change(on_change, new_value) when is_function(on_change, 1) do
    on_change.(new_value)
  end

  defp execute_on_change(_on_change, _new_value), do: :ok
end
