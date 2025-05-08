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

  require Logger

  # alias Raxol.Core.FocusManager # Removed as it's called via helper
  alias Raxol.Components.FocusRing
  # alias Raxol.Core.Accessibility # Removed as it's called via helper
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Components.HintDisplay
  alias Raxol.Core.KeyboardNavigator

  # --- Module Helpers for Dependencies ---
  defp focus_manager_module do
    Application.get_env(:raxol, :focus_manager_impl, Raxol.Core.FocusManager)
  end

  defp accessibility_module do
    Application.get_env(:raxol, :accessibility_impl, Raxol.Core.Accessibility)
  end

  # --- End Module Helpers ---

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
    # Ensure events are initialized first
    ensure_feature_enabled(:events)

    # Register the feature as enabled
    _ = register_enabled_feature(:focus_management)

    :ok
  end

  def enable_feature(:keyboard_navigation, _opts) do
    # Ensure focus management is enabled
    ensure_feature_enabled(:focus_management)

    # Initialize keyboard navigator
    KeyboardNavigator.init()

    # Register the feature as enabled
    _ = register_enabled_feature(:keyboard_navigation)

    :ok
  end

  def enable_feature(:hints, _opts) do
    # Initialize hint display
    hint_config = HintDisplay.init(%{})
    # Store the hint config for later use if needed
    Process.put(:ux_refinement_hint_config, hint_config)

    # Initialize hint registry if not already done
    Process.put(:ux_refinement_hints, %{})

    # Register the feature as enabled
    _ = register_enabled_feature(:hints)

    :ok
  end

  def enable_feature(:focus_ring, opts) do
    # Ensure focus management is enabled
    ensure_feature_enabled(:focus_management)

    # Initialize focus ring with options - Handle the default [] case
    focus_ring_opts = if is_list(opts) and opts == [], do: %{}, else: opts

    focus_ring_config = FocusRing.init(focus_ring_opts)
    # Store the focus ring config for later use if needed
    Process.put(:ux_refinement_focus_ring_config, focus_ring_config)

    # Register the feature as enabled
    _ = register_enabled_feature(:focus_ring)

    :ok
  end

  def enable_feature(:accessibility, opts) do
    # Ensure events are enabled
    ensure_feature_enabled(:events)

    # Initialize accessibility features
    accessibility_module().enable(opts)

    # Initialize metadata registry if not already done
    Process.put(:ux_refinement_metadata, %{})

    # Register focus change handler
    _ =
      focus_manager_module().register_focus_change_handler(
        &handle_accessibility_focus_change/2
      )

    # Register the feature as enabled
    _ = register_enabled_feature(:accessibility)

    :ok
  end

  def enable_feature(:keyboard_shortcuts, _opts) do
    # Ensure events are enabled
    ensure_feature_enabled(:events)

    # Initialize keyboard shortcuts
    keyboard_shortcuts_module().init()

    # Register the feature as enabled
    _ = register_enabled_feature(:keyboard_shortcuts)

    :ok
  end

  def enable_feature(:events, _opts) do
    # Initialize events manager if not already done
    EventManager.init()

    # Register the feature as enabled
    _ = register_enabled_feature(:events)

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
    # Unregister the feature
    unregister_enabled_feature(:focus_management)

    :ok
  end

  def disable_feature(:keyboard_navigation) do
    # Unregister the feature
    unregister_enabled_feature(:keyboard_navigation)

    :ok
  end

  def disable_feature(:hints) do
    # Clear hint registry
    Process.put(:ux_refinement_hints, %{})

    # Unregister the feature
    unregister_enabled_feature(:hints)

    :ok
  end

  def disable_feature(:focus_ring) do
    # Unregister the feature
    unregister_enabled_feature(:focus_ring)

    :ok
  end

  def disable_feature(:accessibility) do
    # Clean up accessibility features
    accessibility_module().disable()

    # Clear metadata registry
    Process.put(:ux_refinement_metadata, %{})

    # Unregister focus change handler
    focus_manager_module().unregister_focus_change_handler(
      &handle_accessibility_focus_change/2
    )

    # Unregister the feature
    unregister_enabled_feature(:accessibility)

    :ok
  end

  def disable_feature(:keyboard_shortcuts) do
    # Clean up keyboard shortcuts
    keyboard_shortcuts_module().cleanup()

    # Unregister the feature
    unregister_enabled_feature(:keyboard_shortcuts)

    :ok
  end

  def disable_feature(:events) do
    # Check if other features depend on events
    features = Process.get(:ux_refinement_features)

    if MapSet.member?(features, :accessibility) ||
         MapSet.member?(features, :keyboard_shortcuts) do
      {:error,
       "Cannot disable events while accessibility or keyboard shortcuts are enabled"}
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
  def register_component_hint(component_id, hint_info) when is_map(hint_info) do
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
  def get_component_hint(component_id, level)
      when level in [:basic, :detailed, :examples] do
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
  Get accessibility metadata for a component.
  """
  def get_accessibility_metadata(component_id) do
    if feature_enabled?(:accessibility) do
      accessibility_module().get_element_metadata(component_id)
    else
      Logger.debug(
        "[UXRefinement] Accessibility not enabled, metadata retrieval skipped for #{component_id}"
      )

      nil
    end
  end

  # Private helper functions (Placeholders added to fix compilation)

  defp register_enabled_feature(feature) do
    features = Process.get(:ux_refinement_features, MapSet.new())
    Process.put(:ux_refinement_features, MapSet.put(features, feature))
    :ok
  end

  defp unregister_enabled_feature(feature) do
    features = Process.get(:ux_refinement_features, MapSet.new())
    Process.put(:ux_refinement_features, MapSet.delete(features, feature))
    :ok
  end

  defp ensure_feature_enabled(_feature) do
    # Placeholder: Assume feature is enabled or enable it if needed (actual logic missing)
    # enable_feature(feature) # Avoid recursion for now
    :ok
  end

  defp handle_accessibility_focus_change(old_focus, new_focus) do
    # This function is called by FocusManager when focus changes
    # It should make an announcement using the Accessibility module
    # (Consider moving this logic directly into Accessibility.handle_focus_change if appropriate)

    if feature_enabled?(:accessibility) do
      # Get accessible name/label for the new_focus element
      # Prefer metadata registered via UXRefinement or Accessibility
      metadata = get_accessibility_metadata(new_focus) || %{}
      # Fallback to ID if no label
      label = Map.get(metadata, :label, new_focus)

      announcement_message =
        if is_nil(old_focus) do
          "Focus set to #{label}"
        else
          "Focus moved from #{get_accessibility_metadata(old_focus)[:label] || old_focus} to #{label}"
        end

      # Use the announce function which checks for :silence_announcements
      # Low priority for general focus changes
      announce(announcement_message, priority: :low)
    end

    :ok
  end

  defp normalize_hint_info(hint_info) when is_map(hint_info) do
    Map.merge(
      %{basic: nil, detailed: nil, examples: nil, shortcuts: []},
      hint_info
    )
  end

  defp normalize_hint_info(hint) when is_binary(hint) do
    %{basic: hint, detailed: nil, examples: nil, shortcuts: []}
  end

  defp maybe_register_shortcuts(component_id, %{shortcuts: shortcuts})
       when is_list(shortcuts) do
    ensure_feature_enabled(:keyboard_shortcuts)
    # Use the helper
    ks_module = keyboard_shortcuts_module()

    Enum.each(shortcuts, fn
      {key, description} when is_binary(key) and is_binary(description) ->
        shortcut_name = generate_shortcut_name(component_id, key)
        callback = shortcut_callback(component_id, description)

        ks_module.register_shortcut(key, shortcut_name, callback,
          description: description,
          context: component_id
        )

      _invalid_shortcut_format ->
        Logger.warn(
          "Invalid shortcut format for component #{component_id}: must be {key_string, description_string}"
        )
    end)
  end

  # No shortcuts to register
  defp maybe_register_shortcuts(_component_id, _hint_info), do: :ok

  defp generate_shortcut_name(component_id, key) do
    "#{component_id}_shortcut_#{key}"
  end

  defp shortcut_callback(component_id, description) do
    fn ->
      IO.inspect("Shortcut activated for #{component_id}: #{description}")
      # Placeholder for actual action. For example, sending an event:
      # Raxol.Core.Runtime.Events.Dispatcher.dispatch_event(%Raxol.Core.Events.Event{type: :shortcut, data: %{component_id: component_id, description: description}})
      :ok
    end
  end

  defp keyboard_shortcuts_module do
    Application.get_env(
      :raxol,
      :keyboard_shortcuts_module,
      Raxol.Core.KeyboardShortcuts
    )
  end

  defp get_hints do
    Process.get(:ux_refinement_hints)
  end

  @doc """
  Display help for available keyboard shortcuts.
  """
  def show_shortcuts_help do
    ensure_feature_enabled(:keyboard_shortcuts)
    keyboard_shortcuts_module().show_shortcuts_help()
  end

  @doc """
  Set the active context for keyboard shortcuts.
  """
  def set_shortcuts_context(context) do
    ensure_feature_enabled(:keyboard_shortcuts)
    keyboard_shortcuts_module().set_context(context)
  end

  @doc """
  Get all available shortcuts for a given context.
  If no context is provided, returns shortcuts for the current active context.
  """
  def get_available_shortcuts(context \\ nil) do
    ensure_feature_enabled(:keyboard_shortcuts)
    keyboard_shortcuts_module().get_shortcuts_for_context(context)
  end

  @doc """
  Make an announcement for screen readers.
  """
  def announce(message, opts \\ []) do
    if feature_enabled?(:accessibility) do
      accessibility_module().announce(message, opts)
    else
      Logger.debug(
        "[UXRefinement] Accessibility not enabled, announcement skipped: #{message}"
      )

      :ok
    end
  end

  @doc """
  Register accessibility metadata for a component.

  ## Parameters

  * `component_id` - The ID of the component
  * `metadata` - The metadata to register

  ## Examples

      iex> UXRefinement.register_accessibility_metadata("search_button", %{label: "Search"})
      :ok
  """
  def register_accessibility_metadata(component_id, metadata) do
    # Ensure accessibility feature is enabled or at least initialized for metadata storage
    # This function acts as a convenience wrapper.
    # The actual storage might be managed within Accessibility module or here.
    # For now, assuming it calls the accessibility_module if enabled.
    if feature_enabled?(:accessibility) do
      accessibility_module().register_element_metadata(component_id, metadata)
    else
      # If accessibility is not fully enabled, we might still want to store metadata
      # This depends on the desired behavior. For now, log and no-op.
      Logger.debug(
        "[UXRefinement] Accessibility not enabled, metadata registration skipped for #{component_id}"
      )

      # Or store in Process.put(:ux_refinement_metadata, ...) directly if needed
      :ok
    end
  end
end
