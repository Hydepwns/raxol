defmodule Raxol.Components.TextInput do
  @moduledoc """
  A text input component with editing capabilities.
  
  This module provides a text input field that allows users to enter
  and edit text with cursor positioning, selection, and validation.
  
  ## Example
  
  ```elixir
  alias Raxol.Components.TextInput
  
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
    display_text = get_display_text(input)
    
    Style.render(input.style, %{
      type: :text_input,
      attrs: %{
        value: input.value,
        display_text: display_text,
        placeholder: input.placeholder,
        password: input.password,
        cursor_pos: input.cursor_pos,
        selection: input.selection,
        disabled: input.disabled,
        valid: input.valid,
        invalid_message: if(!input.valid, do: input.invalid_message, else: nil),
        focus_key: input.focus_key
      }
    })
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
        {before_cursor, after_cursor} = String.split_at(input.value, input.cursor_pos)
        new_value = before_cursor <> char <> after_cursor
        new_cursor_pos = input.cursor_pos + 1
        
        # Update with new value and cursor position
        updated_input = %{input | 
          value: new_value,
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
      {before_cursor, after_cursor} = String.split_at(input.value, input.cursor_pos)
      {_, before_cursor} = String.split_at(before_cursor, -1)
      new_value = before_cursor <> after_cursor
      new_cursor_pos = input.cursor_pos - 1
      
      # Update with new value and cursor position
      updated_input = %{input | 
        value: new_value,
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
    if input.disabled || input.value == "" || input.cursor_pos >= String.length(input.value) do
      input
    else
      # Delete the character after cursor
      {before_cursor, after_cursor} = String.split_at(input.value, input.cursor_pos)
      {_, after_cursor} = String.split_at(after_cursor, 1)
      new_value = before_cursor <> after_cursor
      
      # Update with new value (cursor position stays the same)
      updated_input = %{input | 
        value: new_value,
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
  
  defp get_display_text(%{value: "", placeholder: placeholder}) do
    placeholder
  end
  
  defp get_display_text(%{value: value, password: true}) do
    String.duplicate("*", String.length(value))
  end
  
  defp get_display_text(%{value: value}) do
    value
  end
  
  defp get_input_style(style_type, disabled, valid) when is_atom(style_type) do
    base_style = Style.style([
      padding: [0, 1],
      border: :normal,
      width: :auto
    ])
    
    color_style = 
      cond do
        disabled -> Style.style(color: :gray, background: :light_black)
        !valid -> Style.style(color: :white, background: :red)
        true -> Style.style(color: :white, background: :black)
      end
    
    # Combine styles
    Style.combine([base_style, color_style])
  end
  
  defp get_input_style(custom_style, disabled, valid) when is_map(custom_style) do
    base_style = Style.style([
      padding: [0, 1],
      border: :normal,
      width: :auto
    ])
    
    # Combine with custom style
    combined_style = Style.merge(base_style, custom_style)
    
    # Apply state-based overrides
    cond do
      disabled -> Style.merge(combined_style, Style.style(color: :gray, background: :light_black))
      !valid -> Style.merge(combined_style, Style.style(color: :white, background: :red))
      true -> combined_style
    end
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
end 