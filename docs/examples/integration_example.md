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

```elixir
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
  UXRefinement.register_shortcut("Ctrl+Z", :undo, fn -> 
    undo_action()
    UXRefinement.announce("Action undone", priority: :medium)
  end, context: :editor, description: "Undo last action")
  
  # ... Additional editor shortcuts ...
end

defp setup_browser_shortcuts do
  # Navigation
  UXRefinement.register_shortcut("Alt+Left", :back, fn -> 
    navigate_back()
    UXRefinement.announce("Navigated back", priority: :medium)
  end, context: :browser, description: "Navigate back")
  
  # ... Additional browser shortcuts ...
end
```

## Component Implementation

### Creating Focusable Components

Implement components that can receive focus:

```elixir
defmodule MyApp.Components.Button do
  def render(id, label, options \\ []) do
    # Get focus state
    focused = Raxol.Core.FocusManager.has_focus?(id)
    
    # Apply focus styling if focused
    style = if focused, do: [background: :blue, foreground: :white], else: []
    
    # Register as focusable if not already
    unless Raxol.Core.FocusManager.is_registered?(id) do
      tab_order = Keyword.get(options, :tab_order, 0)
      Raxol.Core.FocusManager.register_focusable(id, tab_order: tab_order)
      
      # Register accessibility metadata if provided
      if metadata = Keyword.get(options, :accessibility) do
        Raxol.Core.UXRefinement.register_accessibility_metadata(id, metadata)
      end
      
      # Register hint if provided
      if hint = Keyword.get(options, :hint) do
        Raxol.Core.UXRefinement.register_component_hint(id, hint)
      end
    end
    
    # Render the button
    render_button(id, label, style)
  end
  
  # ... Component-specific rendering code ...
end
```

### High Contrast Support

Add support for high contrast mode in components:

```elixir
defp render_button(id, label, style) do
  # Get colors based on accessibility settings
  colors = Raxol.Core.Accessibility.get_color_scheme()
  
  # Apply high contrast colors if enabled
  style = if Raxol.Core.Accessibility.high_contrast_enabled?() do
    Keyword.merge(style, [
      background: colors.button,
      foreground: colors.background,
      border: colors.focus
    ])
  else
    style
  end
  
  # Render with appropriate style
  # ... Rendering code ...
end
```

## Event Handling

### Main Event Loop

Implement the main event loop to handle user input:

```elixir
defp event_loop do
  receive do
    {:key, key, modifiers} ->
      # Dispatch keyboard event
      EventManager.dispatch({:keyboard_event, {:key, key, modifiers}})
      
      # Handle specific keys for navigation
      case {key, modifiers} do
        {"tab", _} ->
          handle_tab_navigation(modifiers)
          
        {"enter", _} ->
          handle_enter_key()
          
        {"escape", _} ->
          handle_escape_key()
          
        {arrow, _} when arrow in ["up", "down", "left", "right"] ->
          handle_arrow_navigation(arrow)
          
        _ ->
          :ok
      end
      
    {:mouse, :click, x, y} ->
      handle_mouse_click(x, y)
      
    {:focus_changed, prev, current} ->
      handle_focus_change(prev, current)
      
    {:resize, width, height} ->
      handle_resize(width, height)
      
    other ->
      handle_other_event(other)
  end
  
  # Continue event loop
  event_loop()
end
```

### Focus Navigation Handlers

Handle Tab key navigation:

```elixir
defp handle_tab_navigation(modifiers) do
  current_focus = FocusManager.get_current_focus()
  
  next_focus = if Enum.member?(modifiers, :shift) do
    # Shift+Tab: Move focus backward
    FocusManager.get_previous_focusable(current_focus)
  else
    # Tab: Move focus forward
    FocusManager.get_next_focusable(current_focus)
  end
  
  if next_focus do
    FocusManager.set_focus(next_focus)
  end
end
```

### Handling Activation

Handle Enter key for activating elements:

```elixir
defp handle_enter_key do
  current_focus = FocusManager.get_current_focus()
  
  case current_focus do
    "settings_button" ->
      open_settings_dialog()
      UXRefinement.announce("Settings dialog opened", priority: :medium)
      
    "help_button" ->
      open_help_dialog()
      UXRefinement.announce("Help dialog opened", priority: :medium)
      
    "search_box" ->
      execute_search()
      UXRefinement.announce("Search executed", priority: :medium)
      
    _ ->
      :ok
  end
end
```

## Complete Example

Here's a more complete example of a Raxol application with integrated UX features:

```elixir
defmodule MyApp do
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.FocusManager
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Core.Accessibility
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Components.FocusRing
  
  def start do
    # Initialize the application
    init()
    
    # Start event loop
    event_loop()
  end
  
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
    UXRefinement.enable_feature(:accessibility)
    
    # Configure focus ring
    FocusRing.configure(
      style: :solid,
      color: :blue,
      animation: :pulse,
      transition_effect: :fade
    )
    
    # Setup UI components
    setup_ui()
    
    # Make initial announcement
    UXRefinement.announce("Application loaded. Press Tab to navigate, Ctrl+H for shortcuts.", 
                         priority: :high)
    
    :ok
  end
  
  defp setup_ui do
    # Register focusable components
    FocusManager.register_focusable("header_menu", tab_order: 1)
    FocusManager.register_focusable("search_box", tab_order: 2)
    FocusManager.register_focusable("content_area", tab_order: 3)
    FocusManager.register_focusable("settings_button", tab_order: 4)
    FocusManager.register_focusable("help_button", tab_order: 5)
    
    # Register accessibility metadata
    register_accessibility_metadata()
    
    # Register hints
    register_component_hints()
    
    # Register keyboard shortcuts
    register_keyboard_shortcuts()
    
    # Set initial focus
    FocusManager.set_focus("header_menu")
    
    :ok
  end
  
  defp register_accessibility_metadata do
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
  end
  
  defp register_component_hints do
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
  end
  
  defp register_keyboard_shortcuts do
    # Global shortcuts
    UXRefinement.register_shortcut("Ctrl+H", :show_shortcuts, fn -> 
      UXRefinement.show_shortcuts_help()
    end, description: "Show keyboard shortcuts")
    
    UXRefinement.register_shortcut("F1", :show_help, fn -> 
      open_help_dialog()
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
    
    # Application functionality shortcuts
    UXRefinement.register_shortcut("Ctrl+S", :save, fn -> 
      save_document()
      UXRefinement.announce("Document saved", priority: :medium)
    end, context: :editor, description: "Save document")
    
    UXRefinement.register_shortcut("Ctrl+O", :open, fn -> 
      open_document()
      UXRefinement.announce("Document opened", priority: :medium)
    end, context: :editor, description: "Open document")
    
    # Set initial context
    UXRefinement.set_shortcuts_context(:global)
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
  
  defp toggle_large_text do
    # Get current state
    current = Accessibility.large_text_enabled?()
    
    # Toggle the state
    Accessibility.set_large_text(!current)
    
    # Announce the change
    message = if !current do
      "Large text enabled"
    else
      "Large text disabled"
    end
    
    UXRefinement.announce(message, priority: :medium)
  end
  
  defp open_help_dialog do
    # Show help dialog
    # ... Implementation ...
  end
  
  defp open_settings_dialog do
    # Show settings dialog
    # ... Implementation ...
  end
  
  defp save_document do
    # Save document
    # ... Implementation ...
  end
  
  defp open_document do
    # Open document
    # ... Implementation ...
  end
  
  defp execute_search do
    # Execute search
    # ... Implementation ...
  end
  
  defp event_loop do
    # In a real application, this would be a proper event loop
    # that processes keyboard and other events
    
    # For demonstration purposes, we'll just keep a simple loop
    receive do
      {:key, key, modifiers} ->
        # Dispatch keyboard event to trigger shortcuts
        EventManager.dispatch({:keyboard_event, {:key, key, modifiers}})
        
        # Continue event loop
        event_loop()
        
      other ->
        # Handle other events
        # ... Implementation ...
        
        # Continue event loop
        event_loop()
    end
  end
end
```

## Testing

### Unit Testing

Test individual components and features:

```elixir
defmodule MyAppTest do
  use ExUnit.Case
  
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.FocusManager
  alias Raxol.Core.Accessibility
  
  setup do
    UXRefinement.init()
    
    # Enable features for testing
    UXRefinement.enable_feature(:focus_management)
    UXRefinement.enable_feature(:accessibility)
    UXRefinement.enable_feature(:keyboard_shortcuts)
    
    on_exit(fn ->
      # Clean up
      UXRefinement.disable_feature(:keyboard_shortcuts)
      UXRefinement.disable_feature(:accessibility)
      UXRefinement.disable_feature(:focus_management)
    end)
    
    :ok
  end
  
  test "focus management works correctly" do
    # Register focusable components
    FocusManager.register_focusable("button1", tab_order: 1)
    FocusManager.register_focusable("button2", tab_order: 2)
    
    # Set initial focus
    FocusManager.set_focus("button1")
    assert FocusManager.get_current_focus() == "button1"
    
    # Test navigation
    next = FocusManager.get_next_focusable("button1")
    assert next == "button2"
    
    FocusManager.set_focus(next)
    assert FocusManager.get_current_focus() == "button2"
  end
  
  test "high contrast mode changes colors" do
    # Enable high contrast
    Accessibility.set_high_contrast(true)
    
    # Get color scheme
    colors = Accessibility.get_color_scheme()
    
    # Verify high contrast colors
    assert colors.background == :black
    assert colors.foreground == :white
    
    # Disable high contrast
    Accessibility.set_high_contrast(false)
    
    # Get color scheme
    colors = Accessibility.get_color_scheme()
    
    # Verify standard colors
    assert colors.background != :black
  end
  
  test "keyboard shortcuts trigger correct actions" do
    # Store test process pid
    test_pid = self()
    
    # Register a test shortcut
    UXRefinement.register_shortcut("Ctrl+T", :test, fn -> 
      send(test_pid, :test_shortcut_triggered)
    end)
    
    # Simulate keyboard event
    send(self(), {:key, "t", [:ctrl]})
    
    # Process the event (normally done by event loop)
    # ... Implementation ...
    
    # Verify shortcut was triggered
    assert_received :test_shortcut_triggered
  end
end
```

### Integration Testing

Test how features work together:

```elixir
defmodule MyAppIntegrationTest do
  use ExUnit.Case
  
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.FocusManager
  alias Raxol.Core.Accessibility
  alias Raxol.Core.Events.Manager, as: EventManager
  
  setup do
    # Initialize for integration test
    UXRefinement.init()
    
    # Enable all features
    UXRefinement.enable_feature(:events)
    UXRefinement.enable_feature(:focus_management)
    UXRefinement.enable_feature(:keyboard_navigation)
    UXRefinement.enable_feature(:focus_ring)
    UXRefinement.enable_feature(:hints)
    UXRefinement.enable_feature(:keyboard_shortcuts)
    UXRefinement.enable_feature(:accessibility)
    
    on_exit(fn ->
      # Clean up
      UXRefinement.disable_feature(:accessibility)
      UXRefinement.disable_feature(:keyboard_shortcuts)
      UXRefinement.disable_feature(:hints)
      UXRefinement.disable_feature(:focus_ring)
      UXRefinement.disable_feature(:keyboard_navigation)
      UXRefinement.disable_feature(:focus_management)
      UXRefinement.disable_feature(:events)
    end)
    
    :ok
  end
  
  test "component with accessibility metadata gets announced when focused" do
    # Store test process pid
    test_pid = self()
    
    # Mock Accessibility.announce
    :meck.new(Accessibility, [:passthrough])
    :meck.expect(Accessibility, :announce, fn message, _opts ->
      send(test_pid, {:announce, message})
      :ok
    end)
    
    try do
      # Register component with metadata
      UXRefinement.register_accessibility_metadata("test_button", %{
        announce: "Test button. Press Enter to test.",
        role: :button,
        label: "Test"
      })
      
      # Register as focusable
      FocusManager.register_focusable("test_button", tab_order: 1)
      
      # Set focus to component
      FocusManager.set_focus("test_button")
      
      # Verify announcement
      assert_received {:announce, "Test button. Press Enter to test."}
    after
      :meck.unload(Accessibility)
    end
  end
  
  test "keyboard shortcut focuses component and announces it" do
    # Store test process pid
    test_pid = self()
    
    # Mock Accessibility.announce
    :meck.new(Accessibility, [:passthrough])
    :meck.expect(Accessibility, :announce, fn message, _opts ->
      send(test_pid, {:announce, message})
      :ok
    end)
    
    try do
      # Register component with metadata and shortcut
      UXRefinement.register_accessibility_metadata("test_button", %{
        announce: "Test button. Press Enter to test.",
        role: :button,
        label: "Test",
        shortcut: "Alt+T"
      })
      
      # Register as focusable
      FocusManager.register_focusable("test_button", tab_order: 1)
      
      # Simulate keyboard event for the shortcut
      EventManager.dispatch({:keyboard_event, {:key, "t", [:alt]}})
      
      # Verify component was focused and announced
      assert FocusManager.get_current_focus() == "test_button"
      assert_received {:announce, "Test button. Press Enter to test."}
    after
      :meck.unload(Accessibility)
    end
  end
end
```

---

By following this integration example, you can create terminal UI applications with comprehensive UX features that are accessible, user-friendly, and efficient. 