---
title: Keyboard Shortcuts Guide
description: Guide for keyboard shortcuts in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: guides
tags: [guides, keyboard, shortcuts]
---

# Raxol Keyboard Shortcuts Guide

This guide provides information on implementing and using keyboard shortcuts in Raxol terminal UI applications.

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Registering Shortcuts](#registering-shortcuts)
4. [Context-Specific Shortcuts](#context-specific-shortcuts)
5. [Shortcut Prioritization](#shortcut-prioritization)
6. [Integration with Accessibility](#integration-with-accessibility)
7. [Displaying Available Shortcuts](#displaying-available-shortcuts)
8. [Best Practices](#best-practices)
9. [Example Implementation](#example-implementation)
10. [Troubleshooting](#troubleshooting)

## Introduction

Keyboard shortcuts are essential for improving efficiency and accessibility in terminal UI applications. Raxol provides a comprehensive keyboard shortcuts system that allows you to:

- Register global and context-specific shortcuts
- Handle keyboard events and execute callbacks
- Display available shortcuts to users
- Prioritize shortcuts to handle conflicts
- Integrate shortcuts with accessibility features

## Getting Started

To enable keyboard shortcuts in your Raxol application, you need to initialize the UX refinement system and enable the keyboard shortcuts feature:

```elixir
# Initialize UX refinement
Raxol.Core.UXRefinement.init()

# Enable keyboard shortcuts and events features
Raxol.Core.UXRefinement.enable_feature(:events)
Raxol.Core.UXRefinement.enable_feature(:keyboard_shortcuts)
```

## Registering Shortcuts

### Basic Shortcut Registration

Register a keyboard shortcut with a callback function:

```elixir
Raxol.Core.UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
  save_document()
  Raxol.Core.UXRefinement.announce("Document saved")
end, description: "Save document")
```

### Shortcut Format

Shortcuts are specified as strings in the format `"Modifier+Key"`, where `Modifier` can be `Ctrl`, `Alt`, or `Shift`, and multiple modifiers can be combined:

```elixir
# Single modifier
"Ctrl+S"
"Alt+F"
"Shift+Tab"

# Multiple modifiers
"Ctrl+Alt+S"
"Ctrl+Shift+Alt+X"

# No modifier
"F1"
"Escape"
"Enter"
```

### Shortcut Options

When registering shortcuts, you can specify additional options:

```elixir
Raxol.Core.UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
  save_document()
end, 
  context: :editor,           # Context in which this shortcut is active
  description: "Save document", # Description for help display
  priority: :high             # Priority level (high, medium, low)
)
```

## Context-Specific Shortcuts

### Contexts Overview

Contexts allow you to group shortcuts based on the current state or mode of your application. For example, you might have different shortcuts for an editor mode versus a browser mode.

### Defining Contexts

Contexts are defined implicitly when you register shortcuts with a specific context:

```elixir
# Register shortcuts for editor context
Raxol.Core.UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
  save_document()
end, context: :editor)

Raxol.Core.UXRefinement.register_shortcut("Ctrl+F", :find, fn -> 
  find_in_document()
end, context: :editor)

# Register shortcuts for browser context
Raxol.Core.UXRefinement.register_shortcut("Alt+R", :refresh, fn -> 
  refresh_page()
end, context: :browser)
```

### Switching Contexts

Switch between contexts based on the current state of your application:

```elixir
# Switch to editor context
Raxol.Core.UXRefinement.set_shortcuts_context(:editor)

# Switch to browser context
Raxol.Core.UXRefinement.set_shortcuts_context(:browser)

# Switch to global context
Raxol.Core.UXRefinement.set_shortcuts_context(:global)
```

### Global Shortcuts

Global shortcuts are always active, regardless of the current context:

```elixir
# Register global shortcut (no context specified)
Raxol.Core.UXRefinement.register_shortcut("F1", :help, fn -> 
  show_help()
end, description: "Show help")
```

## Shortcut Prioritization

### Priority Levels

When multiple shortcuts share the same key combination, you can specify priority levels to determine which one takes precedence:

```elixir
# High priority shortcut
Raxol.Core.UXRefinement.register_shortcut("Ctrl+X", :cut, fn -> 
  cut_selection()
end, priority: :high)

# Medium priority shortcut (default)
Raxol.Core.UXRefinement.register_shortcut("Ctrl+X", :close, fn -> 
  close_document()
end, priority: :medium)

# Low priority shortcut
Raxol.Core.UXRefinement.register_shortcut("Ctrl+X", :exit, fn -> 
  exit_application()
end, priority: :low)
```

### Context Precedence

Context-specific shortcuts take precedence over global shortcuts with the same name:

```elixir
# Global shortcut
Raxol.Core.UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
  save_global_settings()
end)

# Context-specific shortcut
Raxol.Core.UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
  save_document()
end, context: :editor)

# When in editor context, the context-specific save will be triggered
# When in global context, the global save will be triggered
```

## Integration with Accessibility

### Announcing Shortcut Actions

When a shortcut is triggered, announce the action to screen readers:

```elixir
Raxol.Core.UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
  save_document()
  Raxol.Core.UXRefinement.announce("Document saved", priority: :medium)
end)
```

### Component Shortcuts

Register shortcuts for focusing specific components:

```elixir
# Register accessibility metadata with shortcut
Raxol.Core.UXRefinement.register_accessibility_metadata("search_button", %{
  announce: "Search button. Press Enter to search.",
  role: :button,
  label: "Search",
  shortcut: "Alt+S"
})

# This automatically registers a shortcut to focus the component
# and announces the component when focused
```

### Hint Integration

Include shortcuts in component hints:

```elixir
Raxol.Core.UXRefinement.register_component_hint("search_button", %{
  basic: "Search for content",
  detailed: "Search for content in the application",
  shortcuts: [
    {"Enter", "Execute search"},
    {"Alt+S", "Focus search"}
  ]
})
```

## Displaying Available Shortcuts

### Show All Shortcuts

Display all available shortcuts for the current context:

```elixir
# Display shortcuts help
{:ok, help_message} = Raxol.Core.UXRefinement.show_shortcuts_help()

# Output will be something like:
# "Available keyboard shortcuts for Editor:
# Ctrl+S: Save document
# Ctrl+F: Find in document
# F1: Show help"
```

### Get Shortcuts Programmatically

Get the list of available shortcuts for the current context:

```elixir
# Get shortcuts
shortcuts = Raxol.Core.UXRefinement.get_available_shortcuts()

# Result will be a list of maps:
# [
#   %{name: :save, key_combo: "Ctrl+S", description: "Save document"},
#   %{name: :find, key_combo: "Ctrl+F", description: "Find in document"}
# ]
```

### Register Help Shortcut

Register a shortcut to display available shortcuts:

```elixir
Raxol.Core.UXRefinement.register_shortcut("Ctrl+H", :help, fn -> 
  Raxol.Core.UXRefinement.show_shortcuts_help()
end, description: "Show keyboard shortcuts")
```

## Best Practices

1. **Use consistent shortcuts**: Follow platform conventions (e.g., Ctrl+S for save, Ctrl+C for copy).
2. **Avoid conflicts**: Don't use the same shortcut for different actions in the same context.
3. **Provide discoverability**: Always include a way for users to discover available shortcuts.
4. **Group related shortcuts**: Use contexts to group related shortcuts together.
5. **Use descriptive names**: Provide clear descriptions for shortcuts in help displays.
6. **Support keyboard-only operation**: Ensure all functionality can be accessed via keyboard shortcuts.
7. **Announce actions**: Announce shortcut actions to screen readers for accessibility.
8. **Prioritize correctly**: Use priority levels to handle potential conflicts.
9. **Document shortcuts**: Include a shortcut reference in your application documentation.
10. **Test thoroughly**: Test shortcuts in different contexts and with screen readers.

## Example Implementation

Here's a comprehensive example of implementing keyboard shortcuts in a Raxol application:

```elixir
defmodule MyApp do
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Core.Accessibility
  
  def init do
    # Initialize UX refinement
    UXRefinement.init()
    
    # Enable required features
    UXRefinement.enable_feature(:events)
    UXRefinement.enable_feature(:keyboard_shortcuts)
    UXRefinement.enable_feature(:accessibility)
    
    # Setup shortcuts
    setup_global_shortcuts()
    setup_editor_shortcuts()
    setup_browser_shortcuts()
    
    # Set initial context
    UXRefinement.set_shortcuts_context(:global)
    
    # Make initial announcement
    UXRefinement.announce("Application loaded. Press Ctrl+H to see available shortcuts.", 
                         priority: :high)
    
    # Start event loop
    event_loop()
  end
  
  defp setup_global_shortcuts do
    # Help shortcuts
    UXRefinement.register_shortcut("Ctrl+H", :help, fn -> 
      UXRefinement.show_shortcuts_help()
    end, description: "Show keyboard shortcuts")
    
    UXRefinement.register_shortcut("F1", :show_help, fn -> 
      show_help_documentation()
      UXRefinement.announce("Help documentation opened")
    end, description: "Show help documentation")
    
    # Accessibility shortcuts
    UXRefinement.register_shortcut("Alt+C", :toggle_high_contrast, fn -> 
      toggle_high_contrast()
    end, description: "Toggle high contrast mode")
    
    UXRefinement.register_shortcut("Alt+M", :toggle_reduced_motion, fn -> 
      toggle_reduced_motion()
    end, description: "Toggle reduced motion")
    
    # Context switching shortcuts
    UXRefinement.register_shortcut("F2", :switch_to_editor, fn -> 
      switch_context(:editor)
    end, description: "Switch to editor mode")
    
    UXRefinement.register_shortcut("F3", :switch_to_browser, fn -> 
      switch_context(:browser)
    end, description: "Switch to browser mode")
    
    # Universal cancel/escape
    UXRefinement.register_shortcut("Escape", :cancel, fn -> 
      cancel_current_operation()
      UXRefinement.announce("Operation canceled", priority: :high)
    end, description: "Cancel current operation", priority: :high)
  end
  
  defp setup_editor_shortcuts do
    # File operations
    UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
      save_document()
      UXRefinement.announce("Document saved", priority: :medium)
    end, context: :editor, description: "Save document")
    
    UXRefinement.register_shortcut("Ctrl+O", :open, fn -> 
      open_document()
      UXRefinement.announce("Document opened", priority: :medium)
    end, context: :editor, description: "Open document")
    
    # Edit operations
    UXRefinement.register_shortcut("Ctrl+X", :cut, fn -> 
      cut_selection()
      UXRefinement.announce("Text cut to clipboard", priority: :medium)
    end, context: :editor, description: "Cut selection")
    
    UXRefinement.register_shortcut("Ctrl+C", :copy, fn -> 
      copy_selection()
      UXRefinement.announce("Text copied to clipboard", priority: :medium)
    end, context: :editor, description: "Copy selection")
    
    UXRefinement.register_shortcut("Ctrl+V", :paste, fn -> 
      paste_clipboard()
      UXRefinement.announce("Text pasted from clipboard", priority: :medium)
    end, context: :editor, description: "Paste from clipboard")
    
    # Search operations
    UXRefinement.register_shortcut("Ctrl+F", :find, fn -> 
      open_find_dialog()
      UXRefinement.announce("Find dialog opened", priority: :medium)
    end, context: :editor, description: "Find in document")
    
    UXRefinement.register_shortcut("Ctrl+H", :replace, fn -> 
      open_replace_dialog()
      UXRefinement.announce("Find and replace dialog opened", priority: :medium)
    end, context: :editor, description: "Find and replace")
  end
  
  defp setup_browser_shortcuts do
    # Navigation
    UXRefinement.register_shortcut("Alt+Left", :back, fn -> 
      navigate_back()
      UXRefinement.announce("Navigated back", priority: :medium)
    end, context: :browser, description: "Navigate back")
    
    UXRefinement.register_shortcut("Alt+Right", :forward, fn -> 
      navigate_forward()
      UXRefinement.announce("Navigated forward", priority: :medium)
    end, context: :browser, description: "Navigate forward")
    
    # Tab management
    UXRefinement.register_shortcut("Ctrl+T", :new_tab, fn -> 
      open_new_tab()
      UXRefinement.announce("New tab opened", priority: :medium)
    end, context: :browser, description: "Open new tab")
    
    UXRefinement.register_shortcut("Ctrl+W", :close_tab, fn -> 
      close_current_tab()
      UXRefinement.announce("Tab closed", priority: :medium)
    end, context: :browser, description: "Close current tab")
    
    # Page actions
    UXRefinement.register_shortcut("F5", :refresh, fn -> 
      refresh_page()
      UXRefinement.announce("Page refreshed", priority: :medium)
    end, context: :browser, description: "Refresh page")
    
    UXRefinement.register_shortcut("Ctrl+D", :bookmark, fn -> 
      bookmark_page()
      UXRefinement.announce("Page bookmarked", priority: :medium)
    end, context: :browser, description: "Bookmark page")
  end
  
  defp switch_context(context) do
    # Set the context
    UXRefinement.set_shortcuts_context(context)
    
    # Update UI to reflect context change
    update_ui_for_context(context)
    
    # Announce context change
    UXRefinement.announce("Switched to #{context} mode. Press Ctrl+H to see available shortcuts.", 
                         priority: :medium)
  end
  
  defp toggle_high_contrast do
    # Get current state
    current = Accessibility.high_contrast_enabled?()
    
    # Toggle the state
    Accessibility.set_high_contrast(!current)
    
    # Announce the change
    message = if !current do
      "High contrast mode enabled"
    else
      "High contrast mode disabled"
    end
    
    UXRefinement.announce(message, priority: :medium)
  end
  
  defp toggle_reduced_motion do
    # Get current state
    current = Accessibility.reduced_motion_enabled?()
    
    # Toggle the state
    Accessibility.set_reduced_motion(!current)
    
    # Announce the change
    message = if !current do
      "Reduced motion enabled"
    else
      "Reduced motion disabled"
    end
    
    UXRefinement.announce(message, priority: :medium)
  end
  
  # ... Implementation of other functions and event handling ...
end
```

## Troubleshooting

### Shortcut Not Working

If a shortcut isn't working as expected:

1. **Check context**: Make sure you're in the correct context for the shortcut.
2. **Check conflicts**: Another shortcut with higher priority might be overriding it.
3. **Verify registration**: Make sure the shortcut is registered correctly.
4. **Check callback**: Ensure the callback function is working properly.
5. **Check event handling**: Make sure keyboard events are being dispatched correctly.

### Common Issues and Solutions

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Shortcut not triggering | Wrong context | Check current context with `KeyboardShortcuts.get_current_context/0` |
| | Conflicting shortcut | Use different key combination or adjust priority |
| | Event not dispatched | Make sure events feature is enabled |
| Multiple shortcuts trigger | Priority not set | Set appropriate priority levels |
| | Context not specific enough | Use more specific contexts |
| Screen reader not announcing | Accessibility not enabled | Enable accessibility feature |
| | Missing announce call | Add `UXRefinement.announce/2` in shortcut callback |
| Help display not showing | Missing descriptions | Add descriptions when registering shortcuts |

### Debugging Shortcuts

You can debug keyboard shortcuts by adding logging to your callbacks:

```elixir
UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
  IO.puts("Ctrl+S shortcut triggered")
  save_document()
  UXRefinement.announce("Document saved", priority: :medium)
end)
```

You can also get information about registered shortcuts:

```elixir
# Print all shortcuts for debugging
shortcuts = UXRefinement.get_available_shortcuts()
IO.inspect(shortcuts, label: "Available Shortcuts")
```

---

By following these guidelines and implementing keyboard shortcuts using Raxol's shortcut system, you can create terminal UI applications that are efficient, accessible, and user-friendly. 