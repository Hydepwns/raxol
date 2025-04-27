---
title: Integration Example
description: Example demonstrating integration features in Raxol Terminal Emulator
date: 2023-04-04
author: Raxol Team
section: examples
tags: [examples, integration, documentation]
---

# Raxol UX Integration Example

This document provides a comprehensive example of integrating all UX refinement features in a Raxol terminal UI application.

## Table of Contents

1. [Overview](#overview)
2. [Setup and Initialization](#setup-and-initialization)
3. [Feature Integration](#feature-integration)
4. [Component Implementation](#component-implementation)
5. [Event Handling](#event-handling)
6. [Complete Example](#complete-example)
7. [Testing](#testing)

## Overview

The Raxol UX refinement system provides several features that enhance the user experience of terminal UI applications:

- Focus Management
- Keyboard Navigation
- Focus Ring Visual Indicators
- Contextual Hints
- Keyboard Shortcuts
- Accessibility Features (Screen Reader, High Contrast, Reduced Motion, Large Text)

This example demonstrates how to integrate all these features into a cohesive application.

## Setup and Initialization

### Basic Setup

First, initialize the UX refinement system and enable the required features:

```elixir
defmodule MyApp do
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.FocusManager
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Core.Accessibility
  alias Raxol.Components.FocusRing

  def init do
    # Initialize UX refinement
    UXRefinement.init()

    # Enable features
    UXRefinement.enable_feature(:events)
    UXRefinement.enable_feature(:focus_management)
    UXRefinement.enable_feature(:keyboard_navigation)
    UXRefinement.enable_feature(:focus_ring)
    UXRefinement.enable_feature(:hints)
    UXRefinement.enable_feature(:keyboard_shortcuts)
    UXRefinement.enable_feature(:accessibility,
      high_contrast: false,
      reduced_motion: false,
      large_text: false
    )

    # Configure focus ring
    FocusRing.configure(
      style: :solid,
      color: :blue,
      animation: :pulse,
      transition_effect: :fade
    )

    # Register components and setup UI
    setup_ui()

    # Initialize with welcome announcement
    UXRefinement.announce("Application initialized. Press Tab to navigate.", priority: :high)

    # Start event loop
    event_loop()
  end

  # ... rest of the module ...
end
```

## Feature Integration

### Focus Management and Keyboard Navigation

Register focusable components and set up tab order:

```elixir
defp setup_ui do
  # Register focusable components with tab order
  FocusManager.register_focusable("header_menu", tab_order: 1)
  FocusManager.register_focusable("search_box", tab_order: 2)
  FocusManager.register_focusable("content_area", tab_order: 3)
  FocusManager.register_focusable("settings_button", tab_order: 4)
  FocusManager.register_focusable("help_button", tab_order: 5)

  # Set up component contents and appearance
  setup_component_contents()

  # Set initial focus
  FocusManager.set_focus("header_menu")
end
```

### Accessibility Metadata

Register accessibility metadata for components:

```elixir
defp setup_component_contents do
  # Register accessibility metadata for components
  UXRefinement.register_accessibility_metadata("header_menu", %{
    announce: "Header menu. Use arrow keys to navigate menu items.",
    role: :menubar,
    label: "Main Menu",
    shortcut: "Alt+M"
  })

  UXRefinement.register_accessibility_metadata("search_box", %{
    announce: "Search box. Type to search content.",
    role: :searchbox,
    label: "Search",
    shortcut: "Alt+S"
  })

  UXRefinement.register_accessibility_metadata("content_area", %{
    announce: "Content area. Contains main application content.",
    role: :region,
    label: "Main Content",
    shortcut: "Alt+C"
  })

  UXRefinement.register_accessibility_metadata("settings_button", %{
    announce: "Settings button. Press Enter to open settings.",
    role: :button,
    label: "Settings",
    shortcut: "Alt+T"
  })

  UXRefinement.register_accessibility_metadata("help_button", %{
    announce: "Help button. Press Enter to open help.",
    role: :button,
    label: "Help",
    shortcut: "Alt+H"
  })

  # Register hints with component information
  setup_component_hints()
end
```

### Component Hints

Register comprehensive multi-level hints for components:

```elixir
defp setup_component_hints do
  UXRefinement.register_component_hint("search_box", %{
    basic: "Search for content",
    detailed: "Type keywords to search for content in the application",
    examples: "Example searches: 'settings', 'help', 'tutorial'",
    shortcuts: [
      {"Enter", "Execute search"},
      {"Escape", "Clear search"},
      {"Alt+S", "Focus search box"}
    ]
  })

  UXRefinement.register_component_hint("settings_button", %{
    basic: "Open settings",
    detailed: "Access application settings and preferences",
    shortcuts: [
      {"Enter", "Open settings dialog"},
      {"Alt+T", "Focus settings button"}
    ]
  })

  UXRefinement.register_component_hint("help_button", %{
    basic: "Get help",
    detailed: "Access help documentation and tutorials",
    examples: "Find information about features, keyboard shortcuts, and how to use the application",
    shortcuts: [
      {"Enter", "Open help documentation"},
      {"Alt+H", "Focus help button"}
    ]
  })

  # Register keyboard shortcuts
  setup_keyboard_shortcuts()
end
```

### Keyboard Shortcuts

Register global and context-specific keyboard shortcuts:

````elixir
defp setup_keyboard_shortcuts do
  # Global shortcuts
  UXRefinement.register_shortcut("Ctrl+H", :show_shortcuts, fn ->
    UXRefinement.show_shortcuts_help()
  end, description: "Show keyboard shortcuts")

  UXRefinement.register_shortcut("F1", :show_help, fn ->
    show_help_documentation()
    UXRefinement.announce("Help documentation opened", priority: :medium)
  end, description: "Show help documentation")

  # Accessibility shortcuts
  UXRefinement.register_shortcut("Alt+C", :toggle_high_contrast, fn ->
    toggle_high_contrast()
  end, description: "Toggle high contrast mode")

  UXRefinement.register_shortcut("Alt+M", :toggle_reduced_motion, fn ->
    toggle_reduced_motion()
  end, description: "Toggle reduced motion")

  UXRefinement.register_shortcut("Alt+L", :toggle_large_text, fn ->
    toggle_large_text()
  end, description: "Toggle large text")

  # Context-specific shortcuts for different application modes
  setup_editor_shortcuts()
  setup_browser_shortcuts()

  # Set initial context
  UXRefinement.set_shortcuts_context(:global)
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
    edit_cut()
    UXRefinement.announce("Text cut", priority: :low)
  end, context: :editor, description: "Cut selected text")

  UXRefinement.register_shortcut("Ctrl+C", :copy, fn ->
    edit_copy()
    UXRefinement.announce("Text copied", priority: :low)
  end, context: :editor, description: "Copy selected text")

  UXRefinement.register_shortcut("Ctrl+V", :paste, fn ->
    edit_paste()
    UXRefinement.announce("Text pasted", priority: :low)
  end, context: :editor, description: "Paste text from clipboard")

  UXRefinement.register_shortcut("Ctrl+Z", :undo, fn ->
    edit_undo()
    UXRefinement.announce("Undo performed", priority: :low)
  end, context: :editor, description: "Undo last action")

  UXRefinement.register_shortcut("Ctrl+Y", :redo, fn ->
    edit_redo()
    UXRefinement.announce("Redo performed", priority: :low)
  end, context: :editor, description: "Redo last undone action")
end

defp setup_browser_shortcuts do
  UXRefinement.register_shortcut("Ctrl+T", :new_tab, fn ->
    open_new_tab()
    UXRefinement.announce("New tab opened", priority: :medium)
  end, context: :browser, description: "Open new tab")

  UXRefinement.register_shortcut("Ctrl+W", :close_tab, fn ->
    close_current_tab()
    UXRefinement.announce("Tab closed", priority: :medium)
  end, context: :browser, description: "Close current tab")

  UXRefinement.register_shortcut("Ctrl+Tab", :next_tab, fn ->
    navigate_next_tab()
  end, context: :browser, description: "Switch to next tab")

  UXRefinement.register_shortcut("Ctrl+Shift+Tab", :prev_tab, fn ->
    navigate_previous_tab()
  end, context: :browser, description: "Switch to previous tab")
end

## Component Implementation

### Basic Component Structure

Components need to integrate with the focus system and render accessibility information:

```elixir
defmodule MyButton do
  alias Raxol.Core.FocusManager
  alias Raxol.Components.FocusRing

  def render(props) do
    is_focused = FocusManager.is_focused?(props.id)

    # Determine style based on focus and accessibility state
    style = get_component_style(is_focused, props.accessibility_state)

    # Render component content
    content = render_button_content(props.label)

    # Conditionally render focus ring
    focus_ring = if is_focused, do: FocusRing.render(props.id), else: ""

    # Combine elements
    "<button id=\"#{props.id}\" style=\"#{style}\">#{content}</button>#{focus_ring}"
  end

  defp get_component_style(is_focused, accessibility_state) do
    # Apply styles based on focus and accessibility
    base_style = "..."
    focus_style = if is_focused, do: "border: 1px solid blue;", else: ""
    high_contrast_style = if accessibility_state.high_contrast, do: "...", else: ""

    "#{base_style} #{focus_style} #{high_contrast_style}"
  end
end
````

### Handling Accessibility State Changes

Components should react to accessibility state changes provided by the system:

```elixir
def handle_accessibility_update(component_id, new_state) do
  # Re-render component or update styles based on new_state
  # e.g., new_state = %{high_contrast: true, reduced_motion: false}
  component = find_component(component_id)
  component.update_styles(new_state)
  component.rerender()

  # Announce the change if necessary
  if new_state.high_contrast do
    UXRefinement.announce("High contrast mode enabled", priority: :medium)
  end
end

# Subscribe to accessibility updates
UXRefinement.subscribe_to_accessibility_updates(&handle_accessibility_update/2)
```

## Event Handling

### Processing Input Events

The main event loop needs to delegate input to the UX refinement system:

```elixir
def event_loop do
  receive do
    {:input, event} ->
      # Let UX refinement handle focus, shortcuts, navigation first
      if UXRefinement.handle_event(event) do
        # Event was handled by UX system (e.g., focus change, shortcut)
        :ok
      else
        # Pass unhandled event to the focused component
        focused_component_id = FocusManager.get_focused_component()
        if focused_component_id do
          handle_component_event(focused_component_id, event)
        end
      end
      event_loop() # Continue loop

    {:render_tick} ->
      render_application()
      event_loop()

    {:shutdown} ->
      :ok
  end
end
```

### Component Event Handling

Components handle events relevant to their functionality after the UX system has processed navigation and shortcuts:

```elixir
def handle_component_event(component_id, event) do
  case {component_id, event} do
    {"search_box", {:keypress, "Enter"}} ->
      execute_search(get_search_term())
      UXRefinement.announce("Search executed", priority: :low)

    {"settings_button", {:click}} ->
      open_settings_dialog()
      UXRefinement.announce("Settings dialog opened", priority: :medium)

    {"header_menu", {:keypress, key}} when key in ["ArrowUp", "ArrowDown"] ->
      navigate_menu(key)

    _ ->
      # Default handling or ignore
      :ok
  end
end
```

## Complete Example

_(A more detailed, runnable example combining all concepts would go here)_

## Testing

### Unit Testing Components

Test component rendering and behavior in isolation, mocking UX system interactions:

```elixir
defmodule MyButtonTest do
  use ExUnit.Case
  alias MyApp.MyButton
  alias Raxol.Core.FocusManagerMock

  test "renders correctly when focused" do
    FocusManagerMock.set_focused("test_button", true)
    props = %{id: "test_button", label: "Click Me", accessibility_state: %{}}
    rendered = MyButton.render(props)

    assert rendered =~ "border: 1px solid blue;"
    assert rendered =~ FocusRing.render("test_button")
  end
end
```

### Integration Testing Features

Test the integration of features like focus navigation and shortcuts:

```elixir
defmodule UXIntegrationTest do
  use ExUnit.Case
  alias MyApp
  alias Raxol.Core.FocusManager
  alias Raxol.Core.UXRefinement

  setup do
    MyApp.init()
    :ok
  end

  test "Tab navigation cycles through components" do
    assert FocusManager.get_focused_component() == "header_menu"
    UXRefinement.handle_event({:keypress, "Tab"})
    assert FocusManager.get_focused_component() == "search_box"
    # ... test full cycle ...
  end

  test "Keyboard shortcut triggers action" do
    # Mock the action function
    mock_show_help = fn -> send(self(), :help_shown) end
    UXRefinement.register_shortcut("F1", :show_help, mock_show_help)

    UXRefinement.handle_event({:keypress, "F1"})
    assert_received :help_shown
  end
end
```

### Accessibility Testing

Use Raxol's accessibility testing utilities to check metadata and announcements:

```elixir
defmodule AccessibilityTest do
  use ExUnit.Case
  alias Raxol.Core.AccessibilityTester
  alias Raxol.Core.UXRefinement

  setup do
    MyApp.init()
    :ok
  end

  test "Components have correct accessibility labels" do
    assert AccessibilityTester.get_label("search_box") == "Search"
    assert AccessibilityTester.get_role("settings_button") == :button
  end

  test "Action triggers correct announcement" do
    AccessibilityTester.start_monitoring_announcements()
    UXRefinement.handle_event({:keypress, "F1"}) # Trigger help shortcut
    assert AccessibilityTester.received_announcement?("Help documentation opened", priority: :medium)
  end
end
```
