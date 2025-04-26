defmodule Raxol.UI.Components.Input.TextInput do
  @moduledoc """
  A text input component for capturing user text input.

  Features:
  * Customizable placeholder text
  * Value binding
  * Focus handling
  * Character validation
  * Input masking (for password fields)
  * Event callbacks
  """

  alias Raxol.UI.Components.Base.Component
  # alias Raxol.View
  # alias Raxol.View.Style
  # alias Raxol.Core.Events

  @behaviour Component

  @type props :: %{
          optional(:id) => String.t(),
          optional(:value) => String.t(),
          optional(:placeholder) => String.t(),
          optional(:on_change) => (String.t() -> any()),
          optional(:on_submit) => (String.t() -> any()),
          optional(:on_cancel) => (-> any()) | nil,
          optional(:theme) => map(),
          optional(:mask_char) => String.t() | nil,
          optional(:max_length) => integer() | nil,
          optional(:validator) => (String.t() -> boolean()) | nil
        }

  @type state :: %{
          cursor_pos: non_neg_integer(),
          focused: boolean()
        }

  require Logger

  # Implementation of Component callbacks
  @impl true
  def init(_props) do
    state = %{
      cursor_pos: 0,
      focused: false
    }

    {:ok, state}
  end

  def handle_event(component, %{type: :keypress, key: key} = _event) do
    case key do
      :enter ->
        if is_function(component.props[:on_submit], 1) do
          component.props.on_submit.(component.props.value || "")
        end

        {:ok, component}

      :escape ->
        if is_function(component.props[:on_cancel], 0) do
          component.props.on_cancel.()
        end

        {:ok, component}

      :backspace ->
        # Delete character before cursor
        %{state: state} = component
        current_pos = state.cursor_pos
        current_value = component.props.value || ""

        if current_pos > 0 do
          # Simplify slice calls temporarily by removing step operator
          before_part = String.slice(current_value, 0..(current_pos - 2))
          remaining_part = String.slice(current_value, current_pos..-1)

          # Handle potential nil results explicitly
          before = before_part || ""
          remaining = remaining_part || ""

          new_value = before <> remaining
          new_state = %{state | cursor_pos: current_pos - 1}
          # Assign updated component to variable first
          updated_component = %{component | state: new_state}
          emit_change(updated_component, new_value)
        else
          {:ok, component}
        end

      {:delete, _} ->
        # Delete character AT cursor position
        %{state: state} = component
        current_pos = state.cursor_pos
        current_value = component.props.value || ""

        if current_pos < String.length(current_value) do
          before = String.slice(current_value, 0, current_pos)
          # Use // -1 for explicit negative step
          after_text =
            String.slice(current_value, (current_pos + 1)..-1//1) || ""

          new_value = before <> after_text
          emit_change(component, new_value)
        else
          {:ok, component}
        end

      {:left, _} ->
        # Move cursor left
        %{state: state} = component
        if state.cursor_pos > 0 do
          new_cursor_pos = state.cursor_pos - 1

          {:ok,
           %{component | state: %{state | cursor_pos: new_cursor_pos}}}
        else
          {:ok, component}
        end

      {:right, _} ->
        # Move cursor right
        %{state: state} = component
        current_value = component.props.value || ""

        if state.cursor_pos < String.length(current_value) do
          new_cursor_pos = state.cursor_pos + 1

          {:ok,
           %{component | state: %{state | cursor_pos: new_cursor_pos}}}
        else
          {:ok, component}
        end

      {:home, _} ->
        # Move cursor to beginning
        {:ok, %{component | state: %{component.state | cursor_pos: 0}}}

      {:end, _} ->
        # Move cursor to end
        %{state: state} = component
        current_value = component.props.value || ""

        {:ok,
         %{
           component
           | state: %{
               state
               | cursor_pos: String.length(current_value)
             }
         }}

      # Handle regular character input
      {char, _} when is_integer(char) and char >= 32 and char <= 126 ->
        # Check max length if set
        %{state: state} = component
        current_value = component.props.value || ""
        max_length = component.props[:max_length]

        if max_length && String.length(current_value) >= max_length do
          # Max length reached
          {:ok, component}
        else
          # Validate character if validator provided
          validator = component.props[:validator]
          char_str = <<char::utf8>>

          if is_function(validator, 1) && !validator.(char_str) do
            # Character rejected by validator
            {:ok, component}
          else
            # Insert character at cursor position
            cursor_pos = state.cursor_pos
            before = String.slice(current_value, 0, cursor_pos)
            after_text = String.slice(current_value, cursor_pos..-1//1) || ""

            new_value = before <> char_str <> after_text
            new_cursor_pos = cursor_pos + 1

            # Update component with new value and cursor position
            updated_component = %{
              component
              | state: %{state | cursor_pos: new_cursor_pos}
            }

            emit_change(updated_component, new_value)
          end
        end

      _ ->
        # Ignore other keys
        {:ok, component}
    end
  end

  def handle_event(component, %{type: :focus}) do
    {:ok, %{component | state: %{component.state | focused: true}}}
  end

  def handle_event(component, %{type: :blur}) do
    {:ok, %{component | state: %{component.state | focused: false}}}
  end

  def handle_event(component, _event) do
    {:ok, component}
  end

  def render(component) do
    # Use component.state directly
    %{state: state} = component
    value = state.value
    placeholder = state.placeholder
    # display_text = if value == "", do: placeholder, else: value

    # Simplified render logic for demonstration
    # In a real component, you'd use the state to generate View elements
    # Apply masking if mask_char is provided
    masked_text =
      if component.props[:mask_char] do
        String.duplicate(component.props.mask_char, String.length(value))
      else
        value
      end

    # Return a representation of the text input
    %{
      type: :text_input,
      text: if(value == "", do: placeholder, else: masked_text),
      cursor_pos: state.cursor_pos,
      focused: state.focused
    }
  end

  # Helper function to emit change events
  defp emit_change(component, new_value) do
    # Call on_change callback if provided
    if is_function(component.props[:on_change], 1) do
      component.props.on_change.(new_value)
    end

    # Return updated component with new value
    {:ok, %{component | props: Map.put(component.props, :value, new_value)}}
  end

  @impl true
  def render(_component, _context) do
    # Return a simple text map as placeholder
    %{type: :text, text: "Placeholder TextInput Render"}
  end

  @impl true
  def handle_event(component, _event, _context) do
    # TODO: Implement proper event handling based on behaviour signature
    # Can delegate to old handle_event/2 if modified to fit.
    # Example: handle_event(component, event)
    # Must return {new_state, commands}
    {component.state, []}
  end

  @impl true
  def update(component, _message) do
    # TODO: Implement update logic based on messages if needed
    # Must return {:noreply, new_state}
    {:noreply, component.state}
  end
end
