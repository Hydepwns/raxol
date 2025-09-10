# Accessibility

Built-in support for screen readers, keyboard navigation, and WCAG compliance.

## Quick Start

```elixir
# Enable accessibility features
config :raxol, :accessibility,
  screen_reader: true,
  high_contrast: true,
  reduce_motion: true
  
# Component with accessibility
defmodule AccessibleButton do
  use Raxol.Component
  
  def render(state, props) do
    button(
      props.label,
      role: "button",
      aria_label: props.aria_label || props.label,
      aria_pressed: state.pressed,
      tabindex: 0
    )
  end
end
```

## Screen Reader Support

### Announcements

```elixir
# Announce changes
Raxol.Accessibility.announce("Item added to cart", :polite)
Raxol.Accessibility.announce("Error: Invalid input", :assertive)

# Live regions
live_region(:polite) do
  text("Status: #{status}")
end
```

### ARIA Attributes

```elixir
# Semantic roles
div(role: "navigation", aria_label: "Main menu")
ul(role: "list")
li(role: "listitem")

# States and properties  
input(
  aria_invalid: has_error?,
  aria_describedby: "error-msg",
  aria_required: true
)

# Relationships
label(for: "email", text: "Email")
input(id: "email", type: "email")
```

## Keyboard Navigation

### Focus Management

```elixir
# Tab order
button("First", tabindex: 1)
button("Second", tabindex: 2)
button("Skip", tabindex: -1)  # Not in tab order

# Focus trap (for modals)
focus_trap do
  modal_content()
end

# Programmatic focus
Raxol.Focus.set(element_id)
Raxol.Focus.return()  # Return to previous
```

### Keyboard Shortcuts

```elixir
# Global shortcuts
Raxol.Keyboard.global_binding([:ctrl, :s], &save/0)
Raxol.Keyboard.global_binding([:escape], &close_modal/0)

# Component shortcuts
def handle_event({:key, :space}, state) do
  toggle_selection(state)
end

def handle_event({:key, :arrow_down}, state) do
  move_focus_down(state)
end
```

## Color & Contrast

### High Contrast Mode

```elixir
# Automatic contrast adjustment
if Raxol.Accessibility.high_contrast? do
  %{
    foreground: :white,
    background: :black,
    border: :white
  }
else
  normal_colors()
end

# Color-blind safe palettes
Raxol.Colors.accessible_palette(:deuteranopia)
Raxol.Colors.accessible_palette(:protanopia)
```

### Contrast Checking

```elixir
# Check WCAG compliance
{:ok, ratio} = Raxol.Colors.contrast_ratio(:blue, :white)
Raxol.Colors.meets_wcag_aa?(:blue, :white)  # true/false
Raxol.Colors.meets_wcag_aaa?(:gray, :white) # true/false

# Auto-fix contrast
bg = :blue
fg = Raxol.Colors.ensure_contrast(bg, :white, :aa)
```

## Motion & Animation

### Reduced Motion

```elixir
# Respect user preference
if Raxol.Accessibility.reduce_motion? do
  # Instant transitions
  transition(duration: 0)
else
  # Normal animation
  transition(duration: 300, easing: :ease_out)
end

# Conditional animations
animate_if_allowed(element, properties)
```

## Text & Readability

### Font Scaling

```elixir
# Respect system font size
base_size = Raxol.Accessibility.font_scale()
text("Content", size: base_size * 1.2)

# Minimum font sizes
text(content, size: max(12, user_size))
```

### Clear Language

```elixir
# Descriptive labels
button("Save", aria_label: "Save document")
icon(:trash, aria_label: "Delete item")

# Error messages
error_message(
  "Password must be at least 8 characters",
  id: "password-error",
  role: "alert"
)
```

## Forms

### Accessible Forms

```elixir
form do
  # Group related fields
  fieldset(legend: "Personal Information") do
    # Label association
    label(for: "name", text: "Full Name *")
    input(
      id: "name",
      required: true,
      aria_describedby: "name-help"
    )
    span(id: "name-help", text: "Enter your full name")
  end
  
  # Error handling
  if errors[:email] do
    input(
      aria_invalid: true,
      aria_errormessage: "email-error"
    )
    span(
      id: "email-error",
      role: "alert",
      text: errors[:email]
    )
  end
end
```

## Testing

### Accessibility Testing

```elixir
defmodule AccessibilityTest do
  use Raxol.AccessibilityCase
  
  test "button has accessible name" do
    button = render_component(MyButton)
    assert has_accessible_name?(button)
  end
  
  test "form fields have labels" do
    form = render_component(MyForm)
    assert all_inputs_labeled?(form)
  end
  
  test "meets contrast requirements" do
    component = render_component(MyComponent)
    assert meets_wcag_aa?(component)
  end
end
```

### Automated Checks

```elixir
# Run accessibility audit
{:ok, report} = Raxol.Accessibility.audit(component)

# Check specific rules
Raxol.Accessibility.check_heading_order(page)
Raxol.Accessibility.check_alt_text(page)
Raxol.Accessibility.check_focus_visible(page)
```

## Configuration

```elixir
config :raxol, :accessibility,
  # Screen reader
  screen_reader_mode: :auto,  # :auto, :on, :off
  announcement_timeout: 100,
  
  # Visual
  high_contrast: :auto,
  reduce_motion: :auto,
  reduce_transparency: false,
  
  # Interaction
  keyboard_only: false,
  focus_visible: :always,  # :always, :keyboard, :never
  
  # Compliance
  wcag_level: :aa,  # :a, :aa, :aaa
  check_contrast: true
```

## See Also

- [Components](components.md) - Building accessible components
- [Testing Guide](testing.md) - Testing accessibility
- [WCAG Guidelines](https://www.w3.org/WAI/WCAG21/quickref/) - External reference