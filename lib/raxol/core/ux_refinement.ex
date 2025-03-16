defmodule Raxol.Core.UXRefinement do
  @moduledoc """
  User experience refinement module for the Raxol terminal UI.
  
  This module provides comprehensive UX features to enhance the terminal UI experience:
  
  * Focus Management - Track and manage focus across UI components
  * Keyboard Navigation - Enable intuitive keyboard navigation
  * Contextual Hints - Display helpful hints based on current context
  * Focus Indicators - Visual indicators for focused elements
  * Multi-level Hints - Basic, detailed, and examples for different help levels
  * Keyboard Shortcuts - Global and context-specific keyboard shortcuts
  * Accessibility Features - Screen reader support, high contrast, reduced motion, etc.
  
  All features can be enabled or disabled individually to customize the UX to your needs.
  """
  
  alias Raxol.Core.FocusManager
  alias Raxol.Components.FocusRing
  alias Raxol.Components.KeyboardNavigator 
  alias Raxol.Components.HintDisplay
  alias Raxol.Core.Accessibility
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.KeyboardShortcuts
  
  @doc """
  Initialize the UX refinement system.
  
  This function sets up the basic infrastructure for UX refinement features.
  It should be called before enabling any specific features.
  
  ## Examples
  
      iex> UXRefinement.init()
      :ok
  """
  def init do
    # Initialize enabled features registry
    Process.put(:ux_refinement_features, MapSet.new())
    
    # Initialize hint registry
    Process.put(:ux_refinement_hints, %{})
    
    # Initialize metadata registry
    Process.put(:ux_refinement_metadata, %{})
    
    # Initialize Events Manager
    EventManager.init()
    
    :ok
  end
  
  @doc """
  Enable a UX refinement feature.
  
  Available features:
  
  * `:focus_management` - Enable focus tracking and management
  * `:keyboard_navigation` - Enable keyboard navigation
  * `:hints` - Enable contextual hints
  * `:focus_ring` - Enable visual focus indicators
  * `:accessibility` - Enable accessibility features
  * `:keyboard_shortcuts` - Enable keyboard shortcuts
  * `:events` - Enable event management system
  
  ## Parameters
  
  * `feature` - The feature to enable
  * `opts` - Options for the feature
  
  ## Examples
  
      iex> UXRefinement.enable_feature(:focus_management)
      :ok
      
      iex> UXRefinement.enable_feature(:accessibility, high_contrast: true)
      :ok
  """
  def enable_feature(feature, opts \\ [])
  
  def enable_feature(:focus_management, _opts) do
    # Initialize focus manager
    FocusManager.init()
    
    # Register the feature as enabled
    register_enabled_feature(:focus_management)
    
    :ok
  end
  
  def enable_feature(:keyboard_navigation, _opts) do
    # Ensure focus management is enabled
    ensure_feature_enabled(:focus_management)
    
    # Initialize keyboard navigator
    KeyboardNavigator.init()
    
    # Register the feature as enabled
    register_enabled_feature(:keyboard_navigation)
    
    :ok
  end
  
  def enable_feature(:hints, _opts) do
    # Initialize hint display
    HintDisplay.init()
    
    # Initialize hint registry if not already done
    Process.put(:ux_refinement_hints, %{})
    
    # Register the feature as enabled
    register_enabled_feature(:hints)
    
    :ok
  end
  
  def enable_feature(:focus_ring, opts) do
    # Ensure focus management is enabled
    ensure_feature_enabled(:focus_management)
    
    # Initialize focus ring with options
    FocusRing.init(opts)
    
    # Register the feature as enabled
    register_enabled_feature(:focus_ring)
    
    :ok
  end
  
  def enable_feature(:accessibility, opts) do
    # Ensure events are enabled
    ensure_feature_enabled(:events)
    
    # Initialize accessibility features
    Accessibility.enable(opts)
    
    # Initialize metadata registry if not already done
    Process.put(:ux_refinement_metadata, %{})
    
    # Register focus change handler
    FocusManager.register_focus_change_handler(&handle_accessibility_focus_change/2)
    
    # Register the feature as enabled
    register_enabled_feature(:accessibility)
    
    :ok
  end
  
  def enable_feature(:keyboard_shortcuts, _opts) do
    # Ensure events are enabled
    ensure_feature_enabled(:events)
    
    # Initialize keyboard shortcuts
    KeyboardShortcuts.init()
    
    # Register the feature as enabled
    register_enabled_feature(:keyboard_shortcuts)
    
    :ok
  end
  
  def enable_feature(:events, _opts) do
    # Initialize events manager if not already done
    EventManager.init()
    
    # Register the feature as enabled
    register_enabled_feature(:events)
    
    :ok
  end
  
  def enable_feature(unknown_feature, _opts) do
    {:error, "Unknown feature: #{unknown_feature}"}
  end
  
  @doc """
  Disable a previously enabled UX refinement feature.
  
  ## Parameters
  
  * `feature` - The feature to disable
  
  ## Examples
  
      iex> UXRefinement.disable_feature(:hints)
      :ok
  """
  def disable_feature(feature)
  
  def disable_feature(:focus_management) do
    # Clean up focus manager
    FocusManager.cleanup()
    
    # Unregister the feature
    unregister_enabled_feature(:focus_management)
    
    :ok
  end
  
  def disable_feature(:keyboard_navigation) do
    # Clean up keyboard navigator
    KeyboardNavigator.cleanup()
    
    # Unregister the feature
    unregister_enabled_feature(:keyboard_navigation)
    
    :ok
  end
  
  def disable_feature(:hints) do
    # Clean up hint display
    HintDisplay.cleanup()
    
    # Clear hint registry
    Process.put(:ux_refinement_hints, %{})
    
    # Unregister the feature
    unregister_enabled_feature(:hints)
    
    :ok
  end
  
  def disable_feature(:focus_ring) do
    # Clean up focus ring
    FocusRing.cleanup()
    
    # Unregister the feature
    unregister_enabled_feature(:focus_ring)
    
    :ok
  end
  
  def disable_feature(:accessibility) do
    # Clean up accessibility features
    Accessibility.disable()
    
    # Clear metadata registry
    Process.put(:ux_refinement_metadata, %{})
    
    # Unregister focus change handler
    FocusManager.unregister_focus_change_handler(&handle_accessibility_focus_change/2)
    
    # Unregister the feature
    unregister_enabled_feature(:accessibility)
    
    :ok
  end
  
  def disable_feature(:keyboard_shortcuts) do
    # Clean up keyboard shortcuts
    KeyboardShortcuts.cleanup()
    
    # Unregister the feature
    unregister_enabled_feature(:keyboard_shortcuts)
    
    :ok
  end
  
  def disable_feature(:events) do
    # Check if other features depend on events
    features = Process.get(:ux_refinement_features)
    
    if MapSet.member?(features, :accessibility) || MapSet.member?(features, :keyboard_shortcuts) do
      {:error, "Cannot disable events while accessibility or keyboard shortcuts are enabled"}
    else
      # Clean up events manager
      EventManager.cleanup()
      
      # Unregister the feature
      unregister_enabled_feature(:events)
      
      :ok
    end
  end
  
  def disable_feature(unknown_feature) do
    {:error, "Unknown feature: #{unknown_feature}"}
  end
  
  @doc """
  Check if a UX refinement feature is enabled.
  
  ## Parameters
  
  * `feature` - The feature to check
  
  ## Examples
  
      iex> UXRefinement.feature_enabled?(:focus_management)
      true
  """
  def feature_enabled?(feature) do
    features = Process.get(:ux_refinement_features, MapSet.new())
    MapSet.member?(features, feature)
  end
  
  @doc """
  Register a hint for a component.
  
  ## Parameters
  
  * `component_id` - The ID of the component
  * `hint` - The hint text
  
  ## Examples
  
      iex> UXRefinement.register_hint("search_button", "Search for content")
      :ok
  """
  def register_hint(component_id, hint) when is_binary(hint) do
    # Ensure hints feature is enabled
    ensure_feature_enabled(:hints)
    
    # Register a basic hint
    # Also calls register_component_hint with the hint as the basic level
    register_component_hint(component_id, %{basic: hint})
    
    :ok
  end
  
  @doc """
  Register comprehensive hints for a component with multiple detail levels.
  
  ## Parameters
  
  * `component_id` - The ID of the component
  * `hint_info` - Map containing different levels of hints and shortcuts
  
  ## Hint Info Structure
  
  * `:basic` - Basic hint (shown by default)
  * `:detailed` - More detailed explanation
  * `:examples` - Examples of usage
  * `:shortcuts` - List of keyboard shortcuts for the component: `[{"Ctrl+S", "Save"}, ...]`
  
  ## Examples
  
      iex> UXRefinement.register_component_hint("search_button", %{
      ...>   basic: "Search for content",
      ...>   detailed: "Search for content in the application using keywords",
      ...>   examples: "Type keywords like 'settings' or 'help'",
      ...>   shortcuts: [
      ...>     {"Enter", "Execute search"},
      ...>     {"Alt+S", "Focus search"}
      ...>   ]
      ...> })
      :ok
  """
  def register_component_hint(component_id, hint_info) do
    # Ensure hints feature is enabled
    ensure_feature_enabled(:hints)
    
    # Normalize hint info
    normalized_hint_info = normalize_hint_info(hint_info)
    
    # Get current hints registry
    hints = Process.get(:ux_refinement_hints)
    
    # Update registry
    updated_hints = Map.put(hints, component_id, normalized_hint_info)
    Process.put(:ux_refinement_hints, updated_hints)
    
    # Register any shortcuts if available
    maybe_register_shortcuts(component_id, normalized_hint_info)
    
    :ok
  end
  
  @doc """
  Get the hint for a component.
  
  This returns the basic hint by default. Use `get_component_hint/2` for
  more detailed hints.
  
  ## Parameters
  
  * `component_id` - The ID of the component
  
  ## Examples
  
      iex> UXRefinement.get_hint("search_button")
      "Search for content"
  """
  def get_hint(component_id) do
    # Ensure hints feature is enabled
    ensure_feature_enabled(:hints)
    
    # Get hints registry
    hints = Process.get(:ux_refinement_hints)
    
    # Get hint info for component
    hint_info = Map.get(hints, component_id)
    
    # Return basic hint
    if hint_info, do: hint_info.basic, else: nil
  end
  
  @doc """
  Get a specific hint level for a component.
  
  ## Parameters
  
  * `component_id` - The ID of the component
  * `level` - The hint level to retrieve (`:basic`, `:detailed`, `:examples`)
  
  ## Examples
  
      iex> UXRefinement.get_component_hint("search_button", :detailed)
      "Search for content in the application using keywords"
  """
  def get_component_hint(component_id, level) when level in [:basic, :detailed, :examples] do
    # Ensure hints feature is enabled
    ensure_feature_enabled(:hints)
    
    # Get hints registry
    hints = Process.get(:ux_refinement_hints)
    
    # Get hint info for component
    hint_info = Map.get(hints, component_id)
    
    # Return requested hint level or fallback to basic
    if hint_info do
      Map.get(hint_info, level) || hint_info.basic
    else
      nil
    end
  end
  
  @doc """
  Get shortcuts for a component.
  
  ## Parameters
  
  * `component_id` - The ID of the component
  
  ## Examples
  
      iex> UXRefinement.get_component_shortcuts("search_button")
      [{"Enter", "Execute search"}, {"Alt+S", "Focus search"}]
  """
  def get_component_shortcuts(component_id) do
    # Ensure hints feature is enabled
    ensure_feature_enabled(:hints)
    
    # Get hints registry
    hints = Process.get(:ux_refinement_hints)
    
    # Get hint info for component
    hint_info = Map.get(hints, component_id)
    
    # Return shortcuts
    if hint_info, do: hint_info.shortcuts, else: []
  end
  
  @doc """
  Register accessibility metadata for a component.
  
  ## Parameters
  
  * `component_id` - The ID of the component
  * `metadata` - Map containing accessibility metadata
  
  ## Metadata Structure
  
  * `:announce` - Text to announce when component gets focus
  * `:role` - ARIA role (e.g., `:button`, `:input`, `:link`)
  * `:label` - Accessible label
  * `:description` - Additional description
  * `:shortcut` - Keyboard shortcut
  
  ## Examples
  
      iex> UXRefinement.register_accessibility_metadata("search_button", %{
      ...>   announce: "Search button. Press Enter to search.",
      ...>   role: :button,
      ...>   label: "Search",
      ...>   shortcut: "Alt+S"
      ...> })
      :ok
  """
  def register_accessibility_metadata(component_id, metadata) do
    # Ensure accessibility feature is enabled
    ensure_feature_enabled(:accessibility)
    
    # Register metadata with Accessibility module
    Accessibility.register_element_metadata(component_id, metadata)
    
    # Register shortcut if provided
    if Map.has_key?(metadata, :shortcut) && feature_enabled?(:keyboard_shortcuts) do
      register_component_shortcut(component_id, metadata.shortcut, metadata)
    end
    
    :ok
  end
  
  @doc """
  Get accessibility metadata for a component.
  
  ## Parameters
  
  * `component_id` - The ID of the component
  
  ## Examples
  
      iex> UXRefinement.get_accessibility_metadata("search_button")
      %{
        announce: "Search button. Press Enter to search.",
        role: :button,
        label: "Search",
        shortcut: "Alt+S"
      }
  """
  def get_accessibility_metadata(component_id) do
    # Ensure accessibility feature is enabled
    ensure_feature_enabled(:accessibility)
    
    # Get metadata from Accessibility module
    Accessibility.get_element_metadata(component_id)
  end
  
  @doc """
  Make a screen reader announcement.
  
  ## Parameters
  
  * `message` - The message to announce
  * `opts` - Options for the announcement
  
  ## Options
  
  * `:priority` - Priority level (`:high`, `:medium`, `:low`)
  * `:interrupt` - Whether to interrupt current announcements
  
  ## Examples
  
      iex> UXRefinement.announce("File saved successfully", priority: :medium)
      :ok
      
      iex> UXRefinement.announce("Error occurred", priority: :high, interrupt: true)
      :ok
  """
  def announce(message, opts \\ []) do
    # Ensure accessibility feature is enabled
    ensure_feature_enabled(:accessibility)
    
    # Make announcement through Accessibility module
    Accessibility.announce(message, opts)
  end
  
  @doc """
  Register a keyboard shortcut.
  
  ## Parameters
  
  * `shortcut` - The keyboard shortcut string (e.g., "Ctrl+S", "Alt+F4")
  * `name` - A unique identifier for the shortcut (atom or string)
  * `callback` - A function to be called when the shortcut is triggered
  * `opts` - Options for the shortcut
  
  ## Options
  
  * `:context` - The context in which this shortcut is active (default: `:global`)
  * `:description` - A description of what the shortcut does
  * `:priority` - Priority level (`:high`, `:medium`, `:low`), affects precedence
  
  ## Examples
  
      iex> UXRefinement.register_shortcut("Ctrl+S", :save, fn -> save_document() end)
      :ok
      
      iex> UXRefinement.register_shortcut("Alt+F", :file_menu, fn -> open_file_menu() end, 
      ...>   context: :main_menu, description: "Open File menu")
      :ok
  """
  def register_shortcut(shortcut, name, callback, opts \\ []) do
    # Ensure keyboard shortcuts feature is enabled
    ensure_feature_enabled(:keyboard_shortcuts)
    
    # Register shortcut with KeyboardShortcuts module
    KeyboardShortcuts.register_shortcut(shortcut, name, callback, opts)
  end
  
  @doc """
  Set the current context for keyboard shortcuts.
  
  ## Parameters
  
  * `context` - The context to set as active
  
  ## Examples
  
      iex> UXRefinement.set_shortcuts_context(:editor)
      :ok
  """
  def set_shortcuts_context(context) do
    # Ensure keyboard shortcuts feature is enabled
    ensure_feature_enabled(:keyboard_shortcuts)
    
    # Set context with KeyboardShortcuts module
    KeyboardShortcuts.set_context(context)
  end
  
  @doc """
  Get available keyboard shortcuts for the current context.
  
  ## Examples
  
      iex> UXRefinement.get_available_shortcuts()
      [
        %{name: :save, key_combo: "Ctrl+S", description: "Save document"},
        %{name: :find, key_combo: "Ctrl+F", description: "Find in document"}
      ]
  """
  def get_available_shortcuts do
    # Ensure keyboard shortcuts feature is enabled
    ensure_feature_enabled(:keyboard_shortcuts)
    
    # Get shortcuts from KeyboardShortcuts module
    KeyboardShortcuts.get_shortcuts_for_context()
  end
  
  @doc """
  Show help for available keyboard shortcuts.
  
  ## Examples
  
      iex> UXRefinement.show_shortcuts_help()
      {:ok, "Available keyboard shortcuts for Editor:\\nCtrl+S: Save document\\nCtrl+F: Find in document"}
  """
  def show_shortcuts_help do
    # Ensure keyboard shortcuts feature is enabled
    ensure_feature_enabled(:keyboard_shortcuts)
    
    # Show help with KeyboardShortcuts module
    KeyboardShortcuts.show_shortcuts_help()
  end
  
  # Private functions
  
  # Register a feature as enabled
  defp register_enabled_feature(feature) do
    features = Process.get(:ux_refinement_features, MapSet.new())
    Process.put(:ux_refinement_features, MapSet.put(features, feature))
  end
  
  # Unregister a feature
  defp unregister_enabled_feature(feature) do
    features = Process.get(:ux_refinement_features, MapSet.new())
    Process.put(:ux_refinement_features, MapSet.delete(features, feature))
  end
  
  # Ensure a feature is enabled
  defp ensure_feature_enabled(feature) do
    unless feature_enabled?(feature) do
      # If not enabled, try to enable it
      enable_feature(feature)
    end
  end
  
  # Handle focus changes for accessibility
  defp handle_accessibility_focus_change(previous_focus, current_focus) do
    # Delegate to Accessibility module
    Accessibility.handle_focus_change(previous_focus, current_focus)
    
    :ok
  end
  
  # Normalize hint info to ensure it has all required fields
  defp normalize_hint_info(hint_info) when is_map(hint_info) do
    # Ensure we have at least a basic hint
    basic = Map.get(hint_info, :basic) || ""
    
    # Create normalized hint info
    %{
      basic: basic,
      detailed: Map.get(hint_info, :detailed),
      examples: Map.get(hint_info, :examples),
      shortcuts: Map.get(hint_info, :shortcuts, [])
    }
  end
  
  defp normalize_hint_info(hint) when is_binary(hint) do
    # Convert string to map with basic hint
    %{
      basic: hint,
      detailed: nil,
      examples: nil,
      shortcuts: []
    }
  end
  
  # Register shortcuts for a component based on hint info
  defp maybe_register_shortcuts(component_id, hint_info) do
    if feature_enabled?(:keyboard_shortcuts) && hint_info.shortcuts != [] do
      Enum.each(hint_info.shortcuts, fn {shortcut, description} ->
        register_component_shortcut(component_id, shortcut, %{description: description})
      end)
    end
  end
  
  # Register a component-specific shortcut
  defp register_component_shortcut(component_id, shortcut, metadata) do
    # Only proceed if keyboard shortcuts feature is enabled
    if feature_enabled?(:keyboard_shortcuts) do
      # Create shortcut name based on component
      shortcut_name = String.to_atom("#{component_id}_shortcut")
      
      # Create callback that focuses the component
      callback = fn -> 
        if feature_enabled?(:focus_management) do
          FocusManager.set_focus(component_id)
          
          # Announce focus change if accessibility is enabled
          if feature_enabled?(:accessibility) && Map.has_key?(metadata, :announce) do
            Accessibility.announce(metadata.announce, priority: :medium)
          end
        end
      end
      
      # Get description
      description = cond do
        Map.has_key?(metadata, :description) -> metadata.description
        Map.has_key?(metadata, :label) -> "Focus #{metadata.label}"
        true -> "Focus #{component_id}"
      end
      
      # Register the shortcut
      KeyboardShortcuts.register_shortcut(shortcut, shortcut_name, callback, 
                                        description: description)
    end
  end
end 