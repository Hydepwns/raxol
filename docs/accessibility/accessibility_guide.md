# Raxol Accessibility Guide

This guide provides information on implementing accessible terminal UI applications using the Raxol framework's accessibility features.

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Screen Reader Support](#screen-reader-support)
4. [Keyboard Navigation](#keyboard-navigation)
5. [Visual Adaptations](#visual-adaptations)
6. [Keyboard Shortcuts](#keyboard-shortcuts)
7. [Best Practices](#best-practices)
8. [Example Implementation](#example-implementation)
9. [Testing Accessibility](#testing-accessibility)

## Introduction

Raxol provides comprehensive accessibility features to ensure that terminal UI applications are usable by people with diverse abilities. These features include:

- Screen reader announcements
- Keyboard navigation and focus management
- Visual adaptations (high contrast, large text)
- Reduced motion support
- Keyboard shortcuts
- Comprehensive hints and help

## Getting Started

To enable accessibility features in your Raxol application, you need to initialize the UX refinement system and enable the accessibility feature:

```elixir
# Initialize UX refinement
Raxol.Core.UXRefinement.init()

# Enable accessibility feature
Raxol.Core.UXRefinement.enable_feature(:accessibility)

# Enable related features
Raxol.Core.UXRefinement.enable_feature(:focus_management)
Raxol.Core.UXRefinement.enable_feature(:keyboard_navigation)
Raxol.Core.UXRefinement.enable_feature(:focus_ring)
Raxol.Core.UXRefinement.enable_feature(:hints)
Raxol.Core.UXRefinement.enable_feature(:keyboard_shortcuts)
```

You can customize the accessibility options when enabling the feature:

```elixir
Raxol.Core.UXRefinement.enable_feature(:accessibility, 
  high_contrast: true,
  reduced_motion: true,
  large_text: true
)
```

## Screen Reader Support

### Making Announcements

You can make screen reader announcements using the `announce/2` function:

```elixir
# Basic announcement
Raxol.Core.UXRefinement.announce("File saved successfully")

# High priority announcement that interrupts other announcements
Raxol.Core.UXRefinement.announce("Error occurred", 
  priority: :high, 
  interrupt: true
)
```

### Component Metadata

Register accessibility metadata for components to provide screen readers with information about them:

```elixir
Raxol.Core.UXRefinement.register_accessibility_metadata("search_button", %{
  announce: "Search button. Press Enter to search.",
  role: :button,
  label: "Search",
  shortcut: "Alt+S"
})
```

The metadata will be used to announce components when they receive focus, and to provide information about their purpose and functionality.

## Keyboard Navigation

Enable keyboard navigation to allow users to navigate through the UI using the keyboard:

```elixir
# Enable keyboard navigation
Raxol.Core.UXRefinement.enable_feature(:keyboard_navigation)

# Register focusable components
Raxol.Core.FocusManager.register_focusable("search_button", tab_order: 1)
Raxol.Core.FocusManager.register_focusable("settings_button", tab_order: 2)
```

The focus order is determined by the `tab_order` parameter. Users can navigate through focusable components using the Tab key.

## Visual Adaptations

### High Contrast Mode

High contrast mode increases the color contrast to improve visibility for users with visual impairments:

```elixir
# Enable high contrast mode
Raxol.Core.Accessibility.set_high_contrast(true)

# Check if high contrast is enabled
is_high_contrast = Raxol.Core.Accessibility.high_contrast_enabled?()
```

### Large Text

Large text mode increases the text size for better readability:

```elixir
# Enable large text
Raxol.Core.Accessibility.set_large_text(true)

# Get current text scale
scale = Raxol.Core.Accessibility.get_text_scale()
```

### Reduced Motion

Reduced motion mode minimizes animations for users who are sensitive to motion:

```elixir
# Enable reduced motion
Raxol.Core.Accessibility.set_reduced_motion(true)

# Check if reduced motion is enabled
is_reduced_motion = Raxol.Core.Accessibility.reduced_motion_enabled?()
```

### Focus Ring

The focus ring provides visual indication of which element is currently focused:

```elixir
# Enable focus ring
Raxol.Core.UXRefinement.enable_feature(:focus_ring)

# Configure focus ring appearance
Raxol.Components.FocusRing.configure(
  style: :solid,
  color: :blue,
  thickness: 2,
  animation: :pulse,
  high_contrast: true
)
```

## Keyboard Shortcuts

### Registering Shortcuts

Register keyboard shortcuts to provide quick access to functionality:

```elixir
# Register global shortcut
Raxol.Core.UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
  save_document()
  Raxol.Core.UXRefinement.announce("Document saved")
end, description: "Save document")

# Register context-specific shortcut
Raxol.Core.UXRefinement.register_shortcut("Alt+F", :file_menu, fn -> 
  open_file_menu()
end, context: :main_menu, description: "Open file menu")
```

### Contexts

Group shortcuts into contexts to handle different UI states:

```elixir
# Set current context
Raxol.Core.UXRefinement.set_shortcuts_context(:editor)

# Get available shortcuts for current context
shortcuts = Raxol.Core.UXRefinement.get_available_shortcuts()

# Show shortcuts help
Raxol.Core.UXRefinement.show_shortcuts_help()
```

## Best Practices

1. **Always provide keyboard alternatives**: Ensure all features can be accessed via keyboard.
2. **Use clear and descriptive announcements**: Make screen reader announcements concise and informative.
3. **Provide consistent navigation**: Maintain consistent tab order and navigation patterns.
4. **Test with accessibility features enabled**: Regularly test your application with high contrast, large text, and reduced motion enabled.
5. **Provide comprehensive help**: Implement multi-level hints to accommodate users with different needs.
6. **Use appropriate component roles**: Assign the correct ARIA role to each component.
7. **Announce state changes**: Announce important state changes such as errors, success messages, and modal dialogs.
8. **Respect user preferences**: Allow users to customize accessibility settings.
9. **Provide skip links**: Allow users to skip repetitive content or navigate directly to important sections.
10. **Document accessibility features**: Clearly document available accessibility features and how to use them.

## Example Implementation

Here's a simple example of implementing accessibility features in a Raxol application:

```elixir
defmodule MyApp do
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.FocusManager
  alias Raxol.Core.Accessibility
  alias Raxol.Components.FocusRing

  def init do
    # Initialize UX refinement
    UXRefinement.init()
    
    # Enable required features
    UXRefinement.enable_feature(:focus_management)
    UXRefinement.enable_feature(:keyboard_navigation)
    UXRefinement.enable_feature(:hints)
    UXRefinement.enable_feature(:focus_ring)
    UXRefinement.enable_feature(:accessibility)
    UXRefinement.enable_feature(:keyboard_shortcuts)
    
    # Configure focus ring
    FocusRing.configure(
      style: :solid,
      color: :blue,
      animation: :pulse
    )
    
    # Register components
    setup_components()
    
    # Make initial announcement
    UXRefinement.announce("Application loaded. Use Tab to navigate.", priority: :high)
    
    # Set initial focus
    FocusManager.set_focus("main_menu")
    
    # Start event loop
    event_loop()
  end
  
  defp setup_components do
    # Register focusable components
    FocusManager.register_focusable("main_menu", tab_order: 1)
    FocusManager.register_focusable("search_box", tab_order: 2)
    FocusManager.register_focusable("settings_button", tab_order: 3)
    
    # Register accessibility metadata
    UXRefinement.register_accessibility_metadata("main_menu", %{
      announce: "Main menu. Use arrow keys to navigate menu items.",
      role: :menu,
      label: "Main Menu",
      shortcut: "Alt+M"
    })
    
    UXRefinement.register_accessibility_metadata("search_box", %{
      announce: "Search box. Type to search.",
      role: :searchbox,
      label: "Search",
      shortcut: "Alt+S"
    })
    
    UXRefinement.register_accessibility_metadata("settings_button", %{
      announce: "Settings button. Press Enter to open settings.",
      role: :button,
      label: "Settings",
      shortcut: "Alt+T"
    })
    
    # Register hints
    UXRefinement.register_component_hint("search_box", %{
      basic: "Search for content",
      detailed: "Type keywords to search for content in the application",
      examples: "Example: 'settings', 'help', 'file'",
      shortcuts: [
        {"Enter", "Execute search"},
        {"Alt+S", "Focus search box"}
      ]
    })
    
    # Register shortcuts
    UXRefinement.register_shortcut("Alt+C", :toggle_high_contrast, fn ->
      current = Accessibility.high_contrast_enabled?()
      Accessibility.set_high_contrast(!current)
      
      message = if !current do
        "High contrast mode enabled"
      else
        "High contrast mode disabled"
      end
      
      UXRefinement.announce(message, priority: :medium)
    end, description: "Toggle high contrast mode")
  end
  
  defp event_loop do
    # Implementation of event handling and UI update loop
    # ...
  end
end
```

## Testing Accessibility

To ensure your application is accessible, test it regularly with the following methods:

1. **Keyboard testing**: Verify that all functionality can be accessed using the keyboard.
2. **Screen reader testing**: Test announcements and focus behavior with screen readers.
3. **Visual adaptation testing**: Test the application with high contrast, large text, and reduced motion enabled.
4. **Automated tests**: Write tests for accessibility features using the Raxol testing framework.

Example test for accessibility features:

```elixir
defmodule MyAppTest do
  use ExUnit.Case
  
  alias Raxol.Core.Accessibility
  alias Raxol.Core.UXRefinement
  
  setup do
    UXRefinement.init()
    UXRefinement.enable_feature(:accessibility)
    
    on_exit(fn ->
      UXRefinement.disable_feature(:accessibility)
    end)
    
    :ok
  end
  
  test "high contrast mode changes color scheme" do
    # Enable high contrast
    Accessibility.set_high_contrast(true)
    
    # Get color scheme
    colors = Accessibility.get_color_scheme()
    
    # Verify high contrast colors
    assert colors.background == :black
    assert colors.foreground == :white
    assert colors.accent == :yellow
    
    # Disable high contrast
    Accessibility.set_high_contrast(false)
    
    # Get standard colors
    colors = Accessibility.get_color_scheme()
    
    # Verify standard colors
    assert colors.background != :black
    assert colors.foreground != :white
  end
  
  test "announcements are queued correctly" do
    # Make announcements
    UXRefinement.announce("First announcement")
    UXRefinement.announce("Second announcement")
    
    # Get next announcement
    next = Accessibility.get_next_announcement()
    assert next == "First announcement"
    
    # Get next announcement
    next = Accessibility.get_next_announcement()
    assert next == "Second announcement"
    
    # Queue should be empty now
    next = Accessibility.get_next_announcement()
    assert next == nil
  end
end
```

---

By following these guidelines and implementing the accessibility features provided by Raxol, you can create terminal UI applications that are accessible to a wide range of users, including those with disabilities. 