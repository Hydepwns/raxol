defmodule Raxol.Examples.KeyboardShortcutsDemo do
  @moduledoc """
  Demo of keyboard shortcuts functionality in Raxol.
  
  This example demonstrates:
  - Registering global and context-specific shortcuts
  - Handling keyboard events
  - Displaying available shortcuts
  - Integration with accessibility features
  """
  
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Core.Accessibility
  alias Raxol.Core.Events.Manager, as: EventManager
  
  @doc """
  Start the keyboard shortcuts demo.
  
  ## Examples
  
      iex> Raxol.Examples.KeyboardShortcutsDemo.run()
      :ok
  """
  def run do
    # Initialize UX refinement
    UXRefinement.init()
    
    # Enable required features
    UXRefinement.enable_feature(:events)
    UXRefinement.enable_feature(:keyboard_shortcuts)
    UXRefinement.enable_feature(:accessibility)
    
    # Setup the demo
    setup_demo()
    
    # Main event loop
    event_loop()
    
    :ok
  end
  
  # Private functions
  
  defp setup_demo do
    # Register global shortcuts
    KeyboardShortcuts.register_shortcut("Ctrl+H", :help, fn ->
      KeyboardShortcuts.show_shortcuts_help()
    end, description: "Show keyboard shortcuts help")
    
    KeyboardShortcuts.register_shortcut("Alt+C", :toggle_high_contrast, fn ->
      toggle_high_contrast()
    end, description: "Toggle high contrast mode")
    
    KeyboardShortcuts.register_shortcut("Alt+M", :toggle_reduced_motion, fn ->
      toggle_reduced_motion()
    end, description: "Toggle reduced motion")
    
    KeyboardShortcuts.register_shortcut("Alt+L", :toggle_large_text, fn ->
      toggle_large_text()
    end, description: "Toggle large text")
    
    # Register editing context shortcuts
    KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn ->
      Accessibility.announce("Document saved", priority: :medium)
    end, context: :editor, description: "Save document")
    
    KeyboardShortcuts.register_shortcut("Ctrl+F", :find, fn ->
      Accessibility.announce("Search activated", priority: :medium)
    end, context: :editor, description: "Find in document")
    
    KeyboardShortcuts.register_shortcut("Ctrl+X", :cut, fn ->
      Accessibility.announce("Text cut to clipboard", priority: :medium)
    end, context: :editor, description: "Cut selection")
    
    KeyboardShortcuts.register_shortcut("Ctrl+C", :copy, fn ->
      Accessibility.announce("Text copied to clipboard", priority: :medium)
    end, context: :editor, description: "Copy selection")
    
    KeyboardShortcuts.register_shortcut("Ctrl+V", :paste, fn ->
      Accessibility.announce("Text pasted from clipboard", priority: :medium)
    end, context: :editor, description: "Paste from clipboard")
    
    # Register browser context shortcuts
    KeyboardShortcuts.register_shortcut("Alt+N", :new_tab, fn ->
      Accessibility.announce("New tab opened", priority: :medium)
    end, context: :browser, description: "Open new tab")
    
    KeyboardShortcuts.register_shortcut("Alt+R", :refresh, fn ->
      Accessibility.announce("Page refreshed", priority: :medium)
    end, context: :browser, description: "Refresh page")
    
    KeyboardShortcuts.register_shortcut("Alt+B", :bookmarks, fn ->
      Accessibility.announce("Bookmarks opened", priority: :medium)
    end, context: :browser, description: "Open bookmarks")
    
    # Register universal escape shortcut
    KeyboardShortcuts.register_shortcut("Escape", :cancel, fn ->
      context = KeyboardShortcuts.get_current_context()
      Accessibility.announce("Canceled current operation in #{context} context", priority: :high)
    end, description: "Cancel current operation", priority: :high)
    
    # Register context switching shortcuts
    KeyboardShortcuts.register_shortcut("F2", :switch_to_editor, fn ->
      switch_context(:editor)
    end, description: "Switch to editor mode")
    
    KeyboardShortcuts.register_shortcut("F3", :switch_to_browser, fn ->
      switch_context(:browser)
    end, description: "Switch to browser mode")
    
    KeyboardShortcuts.register_shortcut("F1", :switch_to_global, fn ->
      switch_context(:global)
    end, description: "Switch to global mode")
    
    # Set initial context
    KeyboardShortcuts.set_context(:global)
    
    # Make initial announcement
    Accessibility.announce("Keyboard shortcuts demo loaded. Press Ctrl+H to see available shortcuts.", 
                         priority: :high)
  end
  
  defp event_loop do
    # In a real application, this would be a proper event loop
    # For this demo, we'll simulate some events
    
    # Show global shortcuts
    Process.sleep(1000)
    KeyboardShortcuts.show_shortcuts_help()
    
    # Switch to editor context
    Process.sleep(2000)
    switch_context(:editor)
    
    # Show editor shortcuts
    Process.sleep(1000)
    KeyboardShortcuts.show_shortcuts_help()
    
    # Simulate keyboard events in editor context
    Process.sleep(1500)
    simulate_keyboard_event("s", [:ctrl])
    
    # Switch to browser context
    Process.sleep(2000)
    switch_context(:browser)
    
    # Show browser shortcuts
    Process.sleep(1000)
    KeyboardShortcuts.show_shortcuts_help()
    
    # Simulate keyboard events in browser context
    Process.sleep(1500)
    simulate_keyboard_event("n", [:alt])
    
    # Switch back to global context
    Process.sleep(2000)
    switch_context(:global)
    
    # Toggle accessibility features using shortcuts
    Process.sleep(1500)
    toggle_high_contrast()
    
    Process.sleep(1500)
    toggle_reduced_motion()
    
    Process.sleep(1500)
    toggle_large_text()
    
    # End the demo
    Process.sleep(2000)
    Accessibility.announce("Demo complete. Thank you for exploring the keyboard shortcuts functionality.", 
                         priority: :high, interrupt: true)
  end
  
  defp switch_context(context) do
    # Set the context
    KeyboardShortcuts.set_context(context)
    
    # Announce context change
    Accessibility.announce("Switched to #{context} context. Press Ctrl+H to see available shortcuts.", 
                         priority: :medium)
  end
  
  defp simulate_keyboard_event(key, modifiers) do
    # Construct keyboard event
    event = {:key, key, modifiers}
    
    # Dispatch event
    EventManager.dispatch({:keyboard_event, event})
  end
  
  defp toggle_high_contrast do
    # Get current state
    high_contrast_enabled = Accessibility.high_contrast_enabled?()
    
    # Toggle the state
    new_state = !high_contrast_enabled
    
    # Apply the change
    Accessibility.set_high_contrast(new_state)
    
    # Announce the change
    message = if new_state do
      "High contrast mode enabled."
    else
      "High contrast mode disabled."
    end
    
    Accessibility.announce(message, priority: :medium)
  end
  
  defp toggle_reduced_motion do
    # Get current state
    reduced_motion_enabled = Accessibility.reduced_motion_enabled?()
    
    # Toggle the state
    new_state = !reduced_motion_enabled
    
    # Apply the change
    Accessibility.set_reduced_motion(new_state)
    
    # Announce the change
    message = if new_state do
      "Reduced motion enabled."
    else
      "Reduced motion disabled."
    end
    
    Accessibility.announce(message, priority: :medium)
  end
  
  defp toggle_large_text do
    # Get current state
    large_text_enabled = Accessibility.large_text_enabled?()
    
    # Toggle the state
    new_state = !large_text_enabled
    
    # Apply the change
    Accessibility.set_large_text(new_state)
    
    # Announce the change
    message = if new_state do
      "Large text enabled."
    else
      "Large text disabled."
    end
    
    Accessibility.announce(message, priority: :medium)
  end
end 