defmodule Raxol.UI.Components.Input.TextField do
  @moduledoc """
  A text input field component for capturing user-entered text.

  ## Props

  * `:value` - Initial value of the field
  * `:placeholder` - Text to show when the field is empty
  * `:label` - Label for the field
  * `:on_change` - Callback message to send when value changes
  * `:on_submit` - Callback message to send when Enter is pressed
  * `:type` - Input type (:text, :password, etc.)
  * `:disabled` - Whether the field is disabled
  * `:max_length` - Maximum input length

  ## Example

  ```elixir
  text_field(
    value: user.name,
    placeholder: "Enter your name",
    label: "Name",
    on_change: {:update_name, user_id}
  )
  ```
  """
  use Raxol.UI.Components.Base.Component
  import Raxol.View.Layout, only: [row: 1, row: 2, column: 1, column: 2]
  import Raxol.View.Elements, only: [panel: 2]

  @impl true
  def init(props) do
    Map.merge(%{
      value: "",
      placeholder: "",
      label: nil,
      focused: false,
      on_change: nil,
      on_submit: nil,
      type: :text,
      disabled: false,
      max_length: nil,
      cursor_position: 0
    }, props)
  end

  @impl true
  def mount(state) do
    # If this component needs to handle keyboard input, subscribe to keyboard events
    commands =
      if not state.disabled do
        [command({:subscribe, [:key_press]})]
      else
        []
      end

    {state, commands}
  end

  @impl true
  def update({:set_value, value}, state) do
    # Update the value and reset cursor position to end of text
    %{state |
      value: value,
      cursor_position: String.length(value)
    }
  end

  @impl true
  def update({:set_focus, focused}, state) do
    %{state | focused: focused}
  end

  @impl true
  def update(:clear, state) do
    %{state | value: "", cursor_position: 0}
  end

  @impl true
  def update({:move_cursor, position}, state) do
    # Ensure cursor position is within bounds
    new_pos = max(0, min(position, String.length(state.value)))
    %{state | cursor_position: new_pos}
  end

  @impl true
  def render(state) do
    # Determine the display value based on type
    display_value = case state.type do
      :password -> String.duplicate("*", String.length(state.value))
      _ -> state.value
    end

    # Determine text color based on state
    text_color = cond do
      state.disabled -> :gray
      state.focused -> :white
      true -> :light_gray
    end

    # Determine border color based on state
    border_color = cond do
      state.disabled -> :dark_gray
      state.focused -> :blue
      true -> :gray
    end

    # Determine placeholder visibility
    show_placeholder = state.value == "" and state.placeholder != ""

    # Create the component
    container = fn inner_content ->
      column do
        # Add label if present
        if state.label do
          text(content: state.label, style: %{fg: :white, margin_bottom: 1})
        end

        # Input field
        panel(
          border: :single,
          fg: border_color,
          bg: :black,
          height: 3,
          style: %{
            padding: {0, 1, 0, 1},
            margin_bottom: 1
          }
        ) do
          row(style: %{align: :center}) do
            # Show either the value or placeholder
            if show_placeholder do
              text(content: state.placeholder, style: %{fg: :dark_gray})
            else
              inner_content.()
            end
          end
        end
      end
    end

    # Pass the value content to the container
    container.(fn ->
      # If focused, render with cursor
      if state.focused do
        # Split text at cursor position
        {before_cursor, after_cursor} = String.split_at(display_value, state.cursor_position)

        row do
          text(content: before_cursor, style: %{fg: text_color})
          text(content: "|", style: %{fg: :white, bg: border_color})
          text(content: after_cursor, style: %{fg: text_color})
        end
      else
        # Not focused, just show text
        text(content: display_value, style: %{fg: text_color})
      end
    end)
  end

  @impl true
  def handle_event({:key_press, key} = event, state) do
    # Only handle key events if focused and not disabled
    if state.focused and not state.disabled do
      handle_key_press(key, state)
    else
      {state, []}
    end
  end

  @impl true
  def handle_event({:click, _} = event, state) do
    # Handle click events to focus the component
    {%{state | focused: true}, []}
  end

  @impl true
  def handle_event(_event, state) do
    {state, []}
  end

  # Private helpers

  defp handle_key_press({:char, char}, state) do
    # Check if we can add the character (max length)
    if state.max_length == nil or String.length(state.value) < state.max_length do
      # Insert character at cursor position
      {before_cursor, after_cursor} = String.split_at(state.value, state.cursor_position)
      new_value = before_cursor <> char <> after_cursor
      new_cursor_position = state.cursor_position + 1

      new_state = %{state |
        value: new_value,
        cursor_position: new_cursor_position
      }

      # If on_change callback is provided, send the message
      commands = if state.on_change do
        [schedule(state.on_change, 0)]
      else
        []
      end

      {new_state, commands}
    else
      {state, []}
    end
  end

  defp handle_key_press(:backspace, state) do
    if state.cursor_position > 0 do
      # Remove character before cursor
      {before_cursor, after_cursor} = String.split_at(state.value, state.cursor_position)
      {before_cursor, _last_char} = String.split_at(before_cursor, -1)
      new_value = before_cursor <> after_cursor
      new_cursor_position = state.cursor_position - 1

      new_state = %{state |
        value: new_value,
        cursor_position: new_cursor_position
      }

      # If on_change callback is provided, send the message
      commands = if state.on_change do
        [schedule(state.on_change, 0)]
      else
        []
      end

      {new_state, commands}
    else
      {state, []}
    end
  end

  defp handle_key_press(:delete, state) do
    if state.cursor_position < String.length(state.value) do
      # Remove character after cursor
      {before_cursor, after_cursor} = String.split_at(state.value, state.cursor_position)
      {_first_char, after_cursor} = String.split_at(after_cursor, 1)
      new_value = before_cursor <> after_cursor

      new_state = %{state | value: new_value}

      # If on_change callback is provided, send the message
      commands = if state.on_change do
        [schedule(state.on_change, 0)]
      else
        []
      end

      {new_state, commands}
    else
      {state, []}
    end
  end

  defp handle_key_press(:left, state) do
    if state.cursor_position > 0 do
      {%{state | cursor_position: state.cursor_position - 1}, []}
    else
      {state, []}
    end
  end

  defp handle_key_press(:right, state) do
    if state.cursor_position < String.length(state.value) do
      {%{state | cursor_position: state.cursor_position + 1}, []}
    else
      {state, []}
    end
  end

  defp handle_key_press(:home, state) do
    {%{state | cursor_position: 0}, []}
  end

  defp handle_key_press(:end, state) do
    {%{state | cursor_position: String.length(state.value)}, []}
  end

  defp handle_key_press(:enter, state) do
    # If on_submit callback is provided, send the message
    if state.on_submit do
      {state, [schedule(state.on_submit, 0)]}
    else
      {state, []}
    end
  end

  defp handle_key_press(:escape, state) do
    # Blur on escape
    {%{state | focused: false}, []}
  end

  defp handle_key_press(_key, state) do
    # Ignore other keys
    {state, []}
  end
end
