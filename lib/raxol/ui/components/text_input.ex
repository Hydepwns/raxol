defmodule Raxol.UI.Components.TextInput do
  @moduledoc """
  A text input component with editing capabilities.

  This module provides a text input field that allows users to enter
  and edit text with cursor positioning, selection, and validation.

  ## Example

  ```elixir
  alias Raxol.UI.Components.TextInput

  TextInput.new(
    value: model.name,
    placeholder: "Enter your name",
    on_change: fn value -> {:update_name, value} end
  )
  ```
  """

  alias Raxol.Style

  @type t :: map()

  @doc """
  Creates a new text input with the given options.

  ## Options

  * `:value` - Current input value
  * `:placeholder` - Placeholder text when empty
  * `:on_change` - Function to call when value changes
  * `:password` - Whether to mask input as password
  * `:max_length` - Maximum input length
  * `:style` - Custom style for the input
  * `:disabled` - Whether the input is disabled
  * `:validation` - Validation function
  * `:invalid_message` - Message to show when validation fails

  ## Returns

  A text input component that can be used in a Raxol view.

  ## Example

  ```elixir
  TextInput.new(
    value: model.email,
    placeholder: "example@example.com",
    validation: &String.contains?(&1, "@"),
    invalid_message: "Must be a valid email"
  )
  ```
  """
  def new(opts \\ []) do
    # Extract options with defaults
    value = Keyword.get(opts, :value, "")
    placeholder = Keyword.get(opts, :placeholder, "")
    on_change = Keyword.get(opts, :on_change)
    password = Keyword.get(opts, :password, false)
    max_length = Keyword.get(opts, :max_length)
    input_style = Keyword.get(opts, :style, :default)
    disabled = Keyword.get(opts, :disabled, false)
    validation = Keyword.get(opts, :validation)
    invalid_message = Keyword.get(opts, :invalid_message, "Invalid input")

    # Validate if needed
    valid = validate_value(validation, value)

    # Create the input with merged styles
    %{
      type: :component,
      component_type: :text_input,
      value: value,
      placeholder: placeholder,
      on_change: on_change,
      password: password,
      max_length: max_length,
      disabled: disabled,
      validation: validation,
      valid: valid,
      invalid_message: invalid_message,
      cursor_pos: String.length(value),
      selection: nil,
      style: get_input_style(input_style, disabled, valid),
      focus_key: Keyword.get(opts, :focus_key, generate_focus_key())
    }
  end

  @doc """
  Renders the text input as a basic element.

  This is typically called by the renderer, not directly by users.
  """
  def render(input) do
    # The style is pre-calculated in new/1
    # display_text = get_display_text(input)
    # Style.render(input.style, %{\n    #   type: :text_input,\n    #   attrs: %{\n    #     value: input.value,\n    #     display_text: display_text,\n    #     placeholder: input.placeholder,\n    #     password: input.password,\n    #     cursor_pos: input.cursor_pos,\n    #     selection: input.selection,\n    #     disabled: input.disabled,\n    #     valid: input.valid,\n    #     invalid_message: if(!input.valid, do: input.invalid_message, else: nil),\n    #     focus_key: input.focus_key\n    #   }\n    # })
    input.style
  end

  @doc """
  Updates the text input based on keyboard input.

  ## Parameters

  * `input` - The text input component
  * `key_event` - Keyboard event as `{meta, key}`

  ## Returns

  Updated text input component.

  ## Example

  ```elixir
  updated_input = TextInput.handle_key_event(input, {:none, ?a})
  ```
  """
  def handle_key_event(%{disabled: true} = input, {_meta, key})
      when key in 32..126//1 do
    input
  end

  def handle_key_event(input, {_meta, key} = _key_event)
      when key in 32..126//1 do
    process_character_input(input, key)
  end

  def handle_key_event(%{disabled: true} = input, {:none, :backspace}),
    do: input

  def handle_key_event(%{value: ""} = input, {:none, :backspace}), do: input
  def handle_key_event(%{cursor_pos: 0} = input, {:none, :backspace}), do: input

  def handle_key_event(input, {:none, :backspace}) do
    process_backspace(input)
  end

  def handle_key_event(%{disabled: true} = input, {:none, :delete}), do: input
  def handle_key_event(%{value: ""} = input, {:none, :delete}), do: input

  def handle_key_event(input, {:none, :delete}) do
    handle_delete_key(input)
  end

  def handle_key_event(%{disabled: true} = input, {:none, :arrow_left}),
    do: input

  def handle_key_event(%{cursor_pos: 0} = input, {:none, :arrow_left}),
    do: input

  def handle_key_event(input, {:none, :arrow_left}) do
    %{input | cursor_pos: input.cursor_pos - 1, selection: nil}
  end

  def handle_key_event(%{disabled: true} = input, {:none, :arrow_right}),
    do: input

  def handle_key_event(input, {:none, :arrow_right}) do
    handle_arrow_right(input)
  end

  def handle_key_event(%{disabled: true} = input, {:none, :home}), do: input

  def handle_key_event(input, {:none, :home}) do
    %{input | cursor_pos: 0, selection: nil}
  end

  def handle_key_event(%{disabled: true} = input, {:none, :end}), do: input

  def handle_key_event(input, {:none, :end}) do
    %{input | cursor_pos: String.length(input.value), selection: nil}
  end

  def handle_key_event(%{disabled: true} = input, {:shift, :arrow_left}),
    do: input

  def handle_key_event(%{cursor_pos: 0} = input, {:shift, :arrow_left}),
    do: input

  def handle_key_event(input, {:shift, :arrow_left}) do
    extend_selection_left(input)
  end

  def handle_key_event(%{disabled: true} = input, {:shift, :arrow_right}),
    do: input

  def handle_key_event(input, {:shift, :arrow_right}) do
    extend_selection_right(input)
  end

  def handle_key_event(input, _key_event) do
    # Ignore other key events
    input
  end

  # Private functions

  defp validate_value(nil, _value), do: true
  defp validate_value(validation, value), do: validation.(value)

  defp process_character_input(input, key) do
    char = <<key::utf8>>

    input
    |> check_max_length(char)
    |> insert_character(char)
    |> validate_input()
  end

  defp check_max_length(%{max_length: nil} = input, _char), do: input

  defp check_max_length(%{max_length: max_len, value: value} = input, _char)
       when byte_size(value) >= max_len,
       do: :max_length_reached

  defp check_max_length(input, _char), do: input

  defp insert_character(:max_length_reached, _char), do: :max_length_reached

  defp insert_character(input, char) do
    {before_cursor, after_cursor} =
      String.split_at(input.value, input.cursor_pos)

    new_value = before_cursor <> char <> after_cursor
    new_cursor_pos = input.cursor_pos + 1

    %{
      input
      | value: new_value,
        cursor_pos: new_cursor_pos,
        selection: nil
    }
  end

  defp process_backspace(input) do
    {before_cursor, after_cursor} =
      String.split_at(input.value, input.cursor_pos)

    before_cursor = trim_last_character(before_cursor)
    new_value = before_cursor <> after_cursor
    new_cursor_pos = input.cursor_pos - 1

    %{
      input
      | value: new_value,
        cursor_pos: new_cursor_pos,
        selection: nil
    }
    |> validate_input()
  end

  defp trim_last_character(""), do: ""

  defp trim_last_character(str) do
    {_, trimmed} = String.split_at(str, -1)
    trimmed
  end

  defp handle_delete_key(input) when input.cursor_pos >= byte_size(input.value),
    do: input

  defp handle_delete_key(input) do
    {before_cursor, after_cursor} =
      String.split_at(input.value, input.cursor_pos)

    {_, after_cursor} = String.split_at(after_cursor, 1)
    new_value = before_cursor <> after_cursor

    %{input | value: new_value, selection: nil}
    |> validate_input()
  end

  defp handle_arrow_right(input)
       when input.cursor_pos >= byte_size(input.value),
       do: input

  defp handle_arrow_right(input) do
    %{input | cursor_pos: input.cursor_pos + 1, selection: nil}
  end

  defp extend_selection_left(input) do
    new_cursor_pos = input.cursor_pos - 1

    new_selection =
      compute_selection(
        input.selection,
        new_cursor_pos,
        input.cursor_pos,
        :left
      )

    %{input | cursor_pos: new_cursor_pos, selection: new_selection}
  end

  defp extend_selection_right(input)
       when input.cursor_pos >= byte_size(input.value),
       do: input

  defp extend_selection_right(input) do
    new_cursor_pos = input.cursor_pos + 1

    new_selection =
      compute_selection(
        input.selection,
        input.cursor_pos,
        new_cursor_pos,
        :right
      )

    %{input | cursor_pos: new_cursor_pos, selection: new_selection}
  end

  defp compute_selection(nil, start_pos, end_pos, :left),
    do: {start_pos, end_pos}

  defp compute_selection(nil, start_pos, end_pos, :right),
    do: {start_pos, end_pos}

  defp compute_selection({anchor, _}, new_pos, _, _), do: {anchor, new_pos}

  # defp get_display_text(%{value: "", placeholder: placeholder}) do
  #   placeholder
  # end
  #
  # defp get_display_text(%{value: value, password: true}) do
  #   String.duplicate("*", String.length(value))
  # end
  #
  # defp get_display_text(%{value: value}) do
  #   value
  # end

  defp get_input_style(style_atom, disabled, valid) when is_atom(style_atom) do
    base_style =
      Style.new(
        padding: [0, 1],
        width: :fill,
        border: :single
      )

    # Define state-based styles
    state_style = determine_state_style(disabled, valid)

    # Merge base and state styles
    Style.merge(base_style, state_style)
  end

  defp determine_state_style(true, _valid),
    do: Style.new(%{color: :gray, border_color: :dark_gray})

  defp determine_state_style(false, false),
    do: Style.new(%{border_color: :red})

  defp determine_state_style(false, true),
    do: Style.new(%{border_color: :gray})

  defp get_input_style(custom_style, disabled, valid)
       when is_map(custom_style) do
    # Define a base style if needed, or assume custom_style provides all defaults
    base_style =
      Style.new(
        padding: [0, 1],
        width: :fill,
        border: :single
      )

    # Merge base with the custom style provided
    merged_base = Style.merge(base_style, custom_style)

    # Define state-based overrides
    state_override_style = determine_override_style(disabled, valid)

    # Merge the combined base/custom style with state overrides
    Style.merge(merged_base, state_override_style)
  end

  defp determine_override_style(true, _valid),
    do: Style.new(%{color: :gray, border_color: :dark_gray})

  defp determine_override_style(false, false),
    do: Style.new(%{border_color: :red})

  defp determine_override_style(false, true),
    do: Style.new(%{})

  defp validate_input(%{validation: nil} = input) do
    %{input | valid: true}
  end

  defp validate_input(%{validation: validation, value: value} = input) do
    valid = validation.(value)
    %{input | valid: valid}
  end

  defp validate_input(:max_length_reached), do: :max_length_reached

  defp process_input_with_validation(input, text, nil) do
    combined_value = input.value <> text
    new_value = apply_max_length(combined_value, input.max_length)

    %{
      input
      | value: new_value,
        cursor_pos: String.length(new_value)
    }
    |> validate_input()
  end

  defp process_input_with_validation(input, text, validator) do
    combined_text = input.value <> text

    case validator.(combined_text) do
      true ->
        new_value = apply_max_length(combined_text, input.max_length)

        %{
          input
          | value: new_value,
            cursor_pos: String.length(new_value)
        }
        |> validate_input()

      false ->
        handle_invalid_input(input, text, validator)
    end
  end

  defp handle_invalid_input(input, text, validator) do
    filtered_text = filter_text_by_validator(input.value, text, validator)
    new_value = apply_max_length(filtered_text, input.max_length)

    %{
      input
      | value: new_value,
        cursor_pos: String.length(new_value)
    }
  end

  defp filter_text_by_validator(current_value, text, validator) do
    case validator.("123") do
      true ->
        # Numeric validator - filter only digits
        current_value <> String.replace(text, ~r/[^\d]/, "")

      _ ->
        # Other validators - reject entirely
        current_value
    end
  end

  defp apply_max_length(text, nil), do: text

  defp apply_max_length(text, max_length) do
    String.slice(text, 0, max_length)
  end

  defp generate_focus_key do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # defp maybe_update_cursor_position(_state) do
  #   # Implementation of maybe_update_cursor_position/1
  # end

  @doc """
  Handles text input by updating the value.

  This is a simplified API for property tests that directly updates the value.
  """
  @spec handle_input(map(), String.t()) :: map()
  def handle_input(%{disabled: true} = input, _text), do: input

  def handle_input(input, text) do
    validator = Map.get(input, :validator) || Map.get(input, :validation)
    process_input_with_validation(input, text, validator)
  end

  @doc """
  Handles cursor positioning.

  Ensures cursor stays within valid bounds.
  """
  @spec handle_cursor(map(), integer()) :: map()
  def handle_cursor(%{disabled: true} = input, _pos), do: input

  def handle_cursor(input, pos) do
    max_pos = String.length(input.value)
    new_pos = pos |> max(0) |> min(max_pos)

    %{input | cursor_pos: new_pos}
  end
end
