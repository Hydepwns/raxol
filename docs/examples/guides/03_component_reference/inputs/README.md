# Input Components Reference

Complete reference for Raxol input components, including usage patterns, props, events, and examples.

## Overview

Input components in Raxol provide interactive elements for user input, including text fields, selectors, checkboxes, and more. All input components follow consistent patterns for state management, event handling, and accessibility.

## Component Categories

### Text Inputs

- Text Input - Single-line text entry
- Text Area - Multi-line text entry
- Password Input - Secure text entry

### Selection Inputs

- [Select List](select_list.md) - Dropdown selection
- Checkbox - Boolean selection
- Radio Group - Single choice from options
- Multi Select - Multiple choice selection

### Numeric Inputs

- Number Input - Numeric value entry
- Slider - Range selection
- Stepper - Increment/decrement controls

### Specialized Inputs

- Date Picker - Date selection
- Time Picker - Time selection
- File Input - File selection

## Common Patterns

### State Management

All input components follow the same state management pattern:

```elixir
defmodule MyInput do
  use Raxol.Component

  def init(props) do
    %{
      value: props[:value] || "",
      focused: false,
      error: nil,
      disabled: props[:disabled] || false
    }
  end

  def update(%{type: :change, value: new_value}, state) do
    %{state | value: new_value, error: nil}
  end

  def update(%{type: :focus}, state) do
    %{state | focused: true}
  end

  def update(%{type: :blur}, state) do
    %{state | focused: false}
  end
end
```

### Event Handling

Input components emit consistent events:

```elixir
# Change events
%{type: :change, value: "new value"}

# Focus events
%{type: :focus}
%{type: :blur}

# Validation events
%{type: :validation_error, error: "Invalid input"}
%{type: :validation_success}

# Special events
%{type: :submit}
%{type: :cancel}
```

### Accessibility

All input components include built-in accessibility features:

```elixir
# Screen reader support
aria_label: "Enter your name"
aria_describedby: "name-help"

# Keyboard navigation
tab_index: 0
keyboard_shortcuts: [
  %{key: "Enter", action: :submit},
  %{key: "Escape", action: :cancel}
]
```

## Usage Examples

### Basic Text Input

```elixir
defmodule NameInput do
  use Raxol.Component

  def render(state) do
    text_input(%{
      value: state.value,
      placeholder: "Enter your name",
      on_change: &handle_change/1,
      on_focus: &handle_focus/1,
      on_blur: &handle_blur/1
    })
  end

  def handle_change(%{value: value}) do
    send_event(%{type: :change, value: value})
  end

  def handle_focus(_) do
    send_event(%{type: :focus})
  end

  def handle_blur(_) do
    send_event(%{type: :blur})
  end
end
```

### Form with Validation

```elixir
defmodule ContactForm do
  use Raxol.Component

  def init(_props) do
    %{
      name: "",
      email: "",
      message: "",
      errors: %{},
      submitted: false
    }
  end

  def render(state) do
    column([
      text_input(%{
        value: state.name,
        placeholder: "Your name",
        error: state.errors[:name],
        on_change: &handle_name_change/1
      }),
      text_input(%{
        value: state.email,
        placeholder: "Your email",
        error: state.errors[:email],
        on_change: &handle_email_change/1
      }),
      text_area(%{
        value: state.message,
        placeholder: "Your message",
        error: state.errors[:message],
        on_change: &handle_message_change/1
      }),
      button(%{
        text: "Send Message",
        on_click: &handle_submit/1,
        disabled: state.submitted
      })
    ])
  end

  def handle_submit(_) do
    case validate_form(state) do
      {:ok, data} ->
        send_event(%{type: :submit, data: data})
        %{state | submitted: true}

      {:error, errors} ->
        %{state | errors: errors}
    end
  end

  defp validate_form(state) do
    errors = %{}

    errors = if state.name == "", do: Map.put(errors, :name, "Name is required"), else: errors
    errors = if !valid_email?(state.email), do: Map.put(errors, :email, "Invalid email"), else: errors
    errors = if state.message == "", do: Map.put(errors, :message, "Message is required"), else: errors

    if map_size(errors) == 0 do
      {:ok, %{name: state.name, email: state.email, message: state.message}}
    else
      {:error, errors}
    end
  end
end
```

## Component Props

### Common Props

All input components support these common props:

```elixir
%{
  # Value and state
  value: "current value",
  placeholder: "placeholder text",
  disabled: false,
  readonly: false,

  # Styling
  class: "custom-class",
  style: %{color: :red},
  theme: :dark,

  # Events
  on_change: &handle_change/1,
  on_focus: &handle_focus/1,
  on_blur: &handle_blur/1,
  on_key_press: &handle_key_press/1,

  # Accessibility
  aria_label: "Accessibility label",
  aria_describedby: "help-text-id",
  tab_index: 0,

  # Validation
  required: true,
  min_length: 3,
  max_length: 100,
  pattern: ~r/^[a-zA-Z]+$/,

  # Custom attributes
  data_testid: "my-input",
  custom_attr: "value"
}
```

### Component-Specific Props

Each input component has additional props specific to its functionality. See individual component documentation for details.

## Best Practices

### 1. State Management

- Keep input state minimal and focused
- Use controlled components for form validation
- Handle loading and error states appropriately

### 2. Event Handling

- Debounce rapid events like typing
- Validate input on blur, not on every keystroke
- Provide clear error messages

### 3. Accessibility

- Always provide meaningful labels
- Support keyboard navigation
- Include error announcements for screen readers

### 4. Performance

- Use `should_update?/2` to prevent unnecessary re-renders
- Memoize expensive validation functions
- Batch related state updates

### 5. Testing

- Test all user interactions
- Verify accessibility features
- Test error states and edge cases

## Migration Guide

### From v0.4 to v0.5

- Event handlers now receive maps instead of tuples
- Validation props have been standardized
- Accessibility props are now required for all inputs

### Breaking Changes

- `on_input` renamed to `on_change`
- `value` prop is now required for controlled components
- Error handling has been simplified

## Related Documentation

- Component Testing
- Form Validation
- Accessibility Guide
- Performance Optimization
