---
title: Keyboard Shortcuts Guide
description: Guide for implementing and using keyboard shortcuts in Raxol applications
date: 2024-07-27 # Updated date
author: Raxol Team
section: guides
tags: [guides, keyboard, shortcuts, events, accessibility]
---

# Raxol Keyboard Shortcuts Guide

This guide provides information on implementing and using keyboard shortcuts in Raxol terminal UI applications.

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Registering Shortcuts](#registering-shortcuts)
4. [Context-Specific Shortcuts](#context-specific-shortcuts)
5. [Shortcut Prioritization](#shortcut-prioritization)
6. [Handling Keyboard Events](#handling-keyboard-events)
7. [Integration with Accessibility](#integration-with-accessibility)
8. [Displaying Available Shortcuts](#displaying-available-shortcuts)
9. [Best Practices](#best-practices)
10. [Example Implementation](#example-implementation)
11. [Troubleshooting](#troubleshooting)

## Introduction

Keyboard shortcuts are essential for improving efficiency and accessibility in terminal UI applications. Raxol provides a keyboard shortcuts system, primarily managed by the `Raxol.Core.KeyboardShortcuts` module, allowing you to:

- Register global and context-specific shortcuts
- Handle keyboard events and execute callbacks
- Prioritize shortcuts to handle conflicts

Integration with hints and accessibility features involves other modules like `Raxol.Core.UXRefinement` and `Raxol.Core.Accessibility`.

## Getting Started

To use the keyboard shortcuts system, you first need to initialize the core UX features and enable the necessary components using `Raxol.Core.UXRefinement`:

```elixir
# Initialize core UX systems (including Event Manager)
defp setup_ux do
  Raxol.Core.UXRefinement.init()
  Raxol.Core.UXRefinement.enable_feature(:events)
  Raxol.Core.UXRefinement.enable_feature(:keyboard_shortcuts)
  # Optionally enable accessibility for announcements
  Raxol.Core.UXRefinement.enable_feature(:accessibility)
end

# Call this setup early in your application initialization
setup_ux()
```

This ensures the `Raxol.Core.KeyboardShortcuts` module is initialized and ready to register and handle shortcuts.

## Registering Shortcuts

Use `Raxol.Core.KeyboardShortcuts.register_shortcut/4` to define shortcuts.

### Basic Shortcut Registration

Register a keyboard shortcut with a unique name (atom), the key combination string, and a callback function:

```elixir
# Assuming KeyboardShortcuts is aliased or imported
KeyboardShortcuts.register_shortcut(:save_doc, "Ctrl+S", fn ->
  save_document()
  # Optionally announce using the Accessibility module if enabled
  Accessibility.announce("Document saved")
end, description: "Save document")
```

**Note:** The first argument is a unique atom identifying the shortcut. The callback function is executed when the shortcut is triggered in the correct context.

### Shortcut Format

Shortcuts are specified as strings in the format `"Modifier+Key"`, where `Modifier` can be `Ctrl`, `Alt`, or `Shift`. Multiple modifiers can be combined:

```elixir
# Single modifier
"Ctrl+S"
"Alt+F"
"Shift+Tab"

# Multiple modifiers
"Ctrl+Alt+Delete"
"Ctrl+Shift+Z"

# Function keys, arrows, and special keys
"F1"
"Escape"
"Enter"
"ArrowUp"
"PageDown"
```

(Refer to the specific input event handling documentation for exact key names.)

### Shortcut Options

When registering shortcuts, you can specify additional options as the fourth argument (keyword list):

```elixir
KeyboardShortcuts.register_shortcut(:save_doc, "Ctrl+S", fn ->
  save_document()
end,
  context: :editor,           # Context in which this shortcut is active (defaults to :global)
  description: "Save document", # Description for help display
  priority: :high             # Priority level (:high, :medium, :low - default :medium)
)
```

## Context-Specific Shortcuts

### Contexts Overview

Contexts (represented by atoms) allow you to group shortcuts based on the current state or mode of your application (e.g., `:editor`, `:file_browser`, `:command_palette`). Only shortcuts matching the currently active context (or the `:global` context) will be considered.

### Defining Contexts

Contexts are defined implicitly when registering shortcuts:

```elixir
# Register shortcuts for :editor context
KeyboardShortcuts.register_shortcut(:save, "Ctrl+S", &save_document/0, context: :editor)
KeyboardShortcuts.register_shortcut(:find, "Ctrl+F", &find_in_document/0, context: :editor)

# Register shortcuts for :browser context
KeyboardShortcuts.register_shortcut(:refresh, "Alt+R", &refresh_page/0, context: :browser)
```

### Switching Contexts

Use `Raxol.Core.KeyboardShortcuts.set_active_context/1` to change the currently active context:

```elixir
# Activate editor shortcuts
KeyboardShortcuts.set_active_context(:editor)

# Activate browser shortcuts
KeyboardShortcuts.set_active_context(:browser)

# Revert to only global shortcuts being active
KeyboardShortcuts.set_active_context(:global)
```

This function should be called whenever your application transitions between states where different shortcut sets are relevant.

### Global Shortcuts

Shortcuts registered without a `context` option or with `context: :global` are always active, regardless of the specific context set by `set_active_context/1`.

```elixir
# Register global shortcut
KeyboardShortcuts.register_shortcut(:help, "F1", &show_help/0, description: "Show help")
```

## Shortcut Prioritization

### Priority Levels

If multiple active shortcuts (matching the current context or global) use the same key combination, the `priority` option determines which one executes:

- `:high` takes precedence over `:medium` and `:low`.
- `:medium` (default) takes precedence over `:low`.

```elixir
# High priority shortcut
KeyboardShortcuts.register_shortcut(:cut_item, "Ctrl+X", &cut_selection/0, priority: :high, context: :list_view)

# Medium priority global shortcut (might close a window)
KeyboardShortcuts.register_shortcut(:close_window, "Ctrl+X", &close_window/0, priority: :medium)
```

In the `:list_view` context, `Ctrl+X` triggers `cut_item`. In other contexts, it triggers `close_window`.

### Context Precedence

Context-specific shortcuts generally take precedence over global shortcuts _with the same name_. However, if shortcuts have _different names_ but the _same key combination_, the `priority` field is the primary determinant.

## Handling Keyboard Events

Keyboard shortcuts don't trigger themselves automatically. Your application needs to capture keyboard input events and pass them to the shortcut system.

This typically happens within your main application logic, such as the `handle_event/3` callback in a `Raxol.App` implementation:

```elixir
defmodule MyApp do
  use Raxol.App

  alias Raxol.Core.KeyboardShortcuts

  # ... init, render ...

  @impl true
  def handle_event({:key, key_event}, _from, state) do
    # Pass the key event to the shortcut handler
    case KeyboardShortcuts.handle_key_event(key_event, state) do
      {:ok, :handled, new_state} ->
        # Shortcut was found and executed, state might have changed by the callback
        {:noreply, new_state}
      {:ok, :not_handled, state} ->
        # No matching shortcut found, handle the key event normally
        handle_other_key_input(key_event, state)
      {:error, reason, state} ->
        # Handle error from shortcut system
        Logger.error("Keyboard shortcut error: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  def handle_event(event, from, state) do
    # Handle other events
    # ...
  end

  defp handle_other_key_input(key_event, state) do
    # Fallback key handling logic
    # ...
    {:noreply, state}
  end
end
```

The `KeyboardShortcuts.handle_key_event/2` function (or a similar function provided by the module) takes the raw key event data, checks against registered shortcuts for the active context, considers priority, executes the callback if a match is found, and returns whether the event was handled.

## Integration with Accessibility

While `Raxol.Core.KeyboardShortcuts` manages shortcut execution, integration with accessibility features like screen reader announcements typically involves the `Raxol.Core.Accessibility` module.

### Announcing Shortcut Actions

Callbacks triggered by shortcuts should use `Raxol.Core.Accessibility.announce/2` (if the accessibility feature is enabled via `UXRefinement`) to inform users of the action taken:

```elixir
KeyboardShortcuts.register_shortcut(:save, "Ctrl+S", fn ->
  save_document()
  # Announce the action if accessibility is enabled
  if Raxol.Core.UXRefinement.feature_enabled?(:accessibility) do
    Raxol.Core.Accessibility.announce("Document saved", priority: :medium)
  end
end)
```

### Component Shortcuts & Hints

Registering shortcuts that focus specific components, or associating shortcuts with component hints, often involves coordinating between `KeyboardShortcuts`, `Accessibility`, and potentially `UXRefinement` or component-specific metadata registration.

- Use `KeyboardShortcuts.register_shortcut/4` to define a shortcut whose callback focuses a specific component.
- Use `Accessibility.register_element_metadata/2` (if available) or similar functions to associate accessibility properties (role, label) with a component.
- Hints might be registered via `Raxol.Core.UXRefinement.register_component_hint/2`, which might internally link shortcuts to the hint display.

Refer to specific documentation on Accessibility and Hints for detailed integration patterns.

## Displaying Available Shortcuts

To display a list of currently active shortcuts (global + current context), use `Raxol.Core.KeyboardShortcuts.get_active_shortcuts/0` or a similar function provided by the module.

```elixir
def show_help do
  active_shortcuts = KeyboardShortcuts.get_active_shortcuts()
  # Format and display the shortcuts list
  formatted_help = format_shortcuts_help(active_shortcuts)
  # Render the help text in a panel or overlay
  # ...
end

def format_shortcuts_help(shortcuts) do
  # shortcuts is likely a list of {key_combo, description} or similar
  Enum.map_join(shortcuts, "\n", fn {key, desc} -> "#{key}: #{desc}" end)
end
```

The exact structure returned might vary; inspect the return value of the relevant `KeyboardShortcuts` function.

## Best Practices

1.  **Consistency:** Use common shortcut patterns (e.g., Ctrl+C for copy).
2.  **Discoverability:** Provide a way for users to view available shortcuts (e.g., via F1 or a help menu).
3.  **Context Clarity:** Change shortcut contexts reliably as the application state changes.
4.  **Avoid Conflicts:** Use priorities carefully and minimize overlapping global/contextual shortcuts with the same key combination.
5.  **Accessibility:** Announce actions triggered by shortcuts.

## Example Implementation

```elixir
defmodule MyEditorApp do
  use Raxol.App
  alias Raxol.Core.{KeyboardShortcuts, UXRefinement, Accessibility}

  def start_link(_opts) do
    # Initialize UX systems
    UXRefinement.init()
    UXRefinement.enable_feature(:events)
    UXRefinement.enable_feature(:keyboard_shortcuts)
    UXRefinement.enable_feature(:accessibility)

    # Register shortcuts
    KeyboardShortcuts.register_shortcut(:save, "Ctrl+S", &save/0, context: :editor, description: "Save File")
    KeyboardShortcuts.register_shortcut(:quit, "Ctrl+Q", &quit/0, description: "Quit Application")
    KeyboardShortcuts.register_shortcut(:help, "F1", &show_help/0, description: "Show Help")

    # Set initial context
    KeyboardShortcuts.set_active_context(:editor)

    # Start the Raxol application
    Raxol.Core.Runtime.Lifecycle.start_application(MyAppWithShortcuts)
  end

  # ... init/render ...

  @impl true
  def handle_event({:key, key_event}, _from, state) do
    case KeyboardShortcuts.handle_key_event(key_event, state) do
      {:ok, :handled, new_state} -> {:noreply, new_state}
      {:ok, :not_handled, state} ->
        # Handle key event normally
        {:noreply, state}
      {:error, _reason, state} -> {:noreply, state}
    end
  end
  def handle_event(_event, _from, state), do: {:noreply, state}

  # Shortcut Callbacks
  defp save do
    # ... save logic ...
    Accessibility.announce("File saved.")
    # Return state change if needed, or :ok
    :ok
  end

  defp quit do
    Raxol.Core.Runtime.Lifecycle.stop_application(:normal) # Or appropriate shutdown reason
    :ok
  end

  defp show_help do
    active_shortcuts = KeyboardShortcuts.get_active_shortcuts()
    help_text = format_shortcuts_help(active_shortcuts)
    # Trigger rendering of help_text in the UI
    # ... update state to show help panel ...
    :ok
  end

  defp format_shortcuts_help(shortcuts) do
     Enum.map_join(shortcuts, "\n", fn {key, desc} -> "#{key}: #{desc}" end)
   end
end
```

## Troubleshooting

- **Shortcut Not Triggering:**
  - Verify `KeyboardShortcuts.handle_key_event/2` is being called with key events.
  - Check if the correct context is set using `KeyboardShortcuts.set_active_context/1`.
  - Ensure the key combination string matches exactly what the event system provides.
  - Check for conflicting shortcuts and verify priorities.
- **Incorrect Callback Executing:** Check priorities and context settings for conflicting shortcuts.
- **Announcements Not Working:** Ensure `:accessibility` feature is enabled via `UXRefinement` and `Accessibility.announce/2` is called.

---

By following these guidelines and implementing keyboard shortcuts using Raxol's shortcut system, you can create terminal UI applications that are efficient, accessible, and user-friendly.
