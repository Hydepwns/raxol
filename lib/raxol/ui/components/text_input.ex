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

  import Raxol.Guards
  alias Raxol.Style
  alias Raxol.UI.Theming.Theme

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
    valid = if validation, do: validation.(value), else: true

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
  def handle_key_event(input, {_meta, key} = _key_event) when key in 32..126 do
    # Only process if not disabled
    if input.disabled do
      input
    else
      # Get the character being typed
      char = <<key::utf8>>

      # Check max length
      if input.max_length && String.length(input.value) >= input.max_length do
        input
      else
        # Insert the character at cursor position
        {before_cursor, after_cursor} =
          String.split_at(input.value, input.cursor_pos)

        new_value = before_cursor <> char <> after_cursor
        new_cursor_pos = input.cursor_pos + 1

        # Update with new value and cursor position
        updated_input = %{
          input
          | value: new_value,
            cursor_pos: new_cursor_pos,
            selection: nil
        }

        # Validate if needed
        updated_input = validate_input(updated_input)

        # Trigger on_change callback if present
        if input.on_change do
          # Return updated input but don't actually call the callback
          # (that's the responsibility of the application's update function)
          updated_input
        else
          updated_input
        end
      end
    end
  end

  def handle_key_event(input, {:none, :backspace}) do
    # Only process if not disabled and there's something to delete
    if input.disabled || input.value == "" || input.cursor_pos == 0 do
      input
    else
      # Delete the character before cursor
      {before_cursor, after_cursor} =
        String.split_at(input.value, input.cursor_pos)

      before_cursor =
        if String.length(before_cursor) > 0 do
          {_, bc} = String.split_at(before_cursor, -1)
          bc
        else
          before_cursor
        end

      new_value = before_cursor <> after_cursor
      new_cursor_pos = input.cursor_pos - 1

      # Update with new value and cursor position
      updated_input = %{
        input
        | value: new_value,
          cursor_pos: new_cursor_pos,
          selection: nil
      }

      # Validate if needed
      updated_input = validate_input(updated_input)

      # Trigger on_change callback if present
      if input.on_change do
        # Return updated input but don't actually call the callback
        # (that's the responsibility of the application's update function)
        updated_input
      else
        updated_input
      end
    end
  end

  def handle_key_event(input, {:none, :delete}) do
    # Only process if not disabled and there's something to delete
    if input.disabled || input.value == "" ||
         input.cursor_pos >= String.length(input.value) do
      input
    else
      # Delete the character after cursor
      {before_cursor, after_cursor} =
        String.split_at(input.value, input.cursor_pos)

      {_, after_cursor} = String.split_at(after_cursor, 1)
      new_value = before_cursor <> after_cursor

      # Update with new value (cursor position stays the same)
      updated_input = %{input | value: new_value, selection: nil}

      # Validate if needed
      updated_input = validate_input(updated_input)

      # Trigger on_change callback if present
      if input.on_change do
        # Return updated input but don't actually call the callback
        # (that's the responsibility of the application's update function)
        updated_input
      else
        updated_input
      end
    end
  end

  def handle_key_event(input, {:none, :arrow_left}) do
    # Move cursor left if possible
    if input.disabled || input.cursor_pos == 0 do
      input
    else
      %{input | cursor_pos: input.cursor_pos - 1, selection: nil}
    end
  end

  def handle_key_event(input, {:none, :arrow_right}) do
    # Move cursor right if possible
    if input.disabled || input.cursor_pos >= String.length(input.value) do
      input
    else
      %{input | cursor_pos: input.cursor_pos + 1, selection: nil}
    end
  end

  def handle_key_event(input, {:none, :home}) do
    # Move cursor to beginning
    if input.disabled do
      input
    else
      %{input | cursor_pos: 0, selection: nil}
    end
  end

  def handle_key_event(input, {:none, :end}) do
    # Move cursor to end
    if input.disabled do
      input
    else
      %{input | cursor_pos: String.length(input.value), selection: nil}
    end
  end

  def handle_key_event(input, {:shift, :arrow_left}) do
    # Extend selection left
    if input.disabled || input.cursor_pos == 0 do
      input
    else
      new_cursor_pos = input.cursor_pos - 1

      new_selection =
        case input.selection do
          nil -> {new_cursor_pos, input.cursor_pos}
          {anchor, _} -> {anchor, new_cursor_pos}
        end

      %{input | cursor_pos: new_cursor_pos, selection: new_selection}
    end
  end

  def handle_key_event(input, {:shift, :arrow_right}) do
    # Extend selection right
    if input.disabled || input.cursor_pos >= String.length(input.value) do
      input
    else
      new_cursor_pos = input.cursor_pos + 1

      new_selection =
        case input.selection do
          nil -> {input.cursor_pos, new_cursor_pos}
          {anchor, _} -> {anchor, new_cursor_pos}
        end

      %{input | cursor_pos: new_cursor_pos, selection: new_selection}
    end
  end

  def handle_key_event(input, _key_event) do
    # Ignore other key events
    input
  end

  # Private functions

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

  defp get_input_style(style_atom, disabled, valid) when atom?(style_atom) do
    base_style =
      Style.new(
        padding: [0, 1],
        width: :fill,
        border: :single
      )

    # Define state-based styles
    state_style =
      cond do
        # Example disabled style
        disabled -> Style.new(%{color: :gray, border_color: :dark_gray})
        # Invalid style
        !valid -> Style.new(%{border_color: :red})
        # Default valid style
        true -> Style.new(%{border_color: :gray})
      end

    # Merge base and state styles
    Style.merge(base_style, state_style)
  end

  defp get_input_style(custom_style, disabled, valid)
       when map?(custom_style) do
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
    state_override_style =
      cond do
        # Example disabled style
        disabled -> Style.new(%{color: :gray, border_color: :dark_gray})
        # Invalid style override
        !valid -> Style.new(%{border_color: :red})
        # No override needed for valid state if custom_style handles it
        true -> Style.new(%{})
      end

    # Merge the combined base/custom style with state overrides
    Style.merge(merged_base, state_override_style)
  end

  defp validate_input(%{validation: nil} = input) do
    %{input | valid: true}
  end

  defp validate_input(%{validation: validation, value: value} = input) do
    valid = validation.(value)
    %{input | valid: valid}
  end

  defp generate_focus_key do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  # defp maybe_update_cursor_position(_state) do
  #   # Implementation of maybe_update_cursor_position/1
  # end
end
