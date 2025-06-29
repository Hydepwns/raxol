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

  require Raxol.Core.Runtime.Log

  alias Raxol.UI.Components.FocusRing
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.UI.Components.HintDisplay
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
  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (required)

  ## Examples

      iex> UXRefinement.enable_feature(:focus_management)
      :ok

      iex> UXRefinement.enable_feature(:accessibility, high_contrast: true)
      :ok
  """
  def enable_feature(feature, opts \\ [], user_preferences_pid_or_name)

  def enable_feature(:focus_management, _opts, user_preferences_pid_or_name) do
    ensure_feature_enabled(:events, user_preferences_pid_or_name)
    _ = register_enabled_feature(:focus_management)
    :ok
  end

  def enable_feature(:keyboard_navigation, _opts, user_preferences_pid_or_name) do
    ensure_feature_enabled(:focus_management, user_preferences_pid_or_name)
    KeyboardNavigator.init()
    _ = register_enabled_feature(:keyboard_navigation)
    :ok
  end

  def enable_feature(:hints, _opts, _user_preferences_pid_or_name) do
    hint_config = HintDisplay.init(%{})
    Process.put(:ux_refinement_hint_config, hint_config)
    Process.put(:ux_refinement_hints, %{})
    _ = register_enabled_feature(:hints)
    :ok
  end

  def enable_feature(:focus_ring, opts, user_preferences_pid_or_name) do
    ensure_feature_enabled(:focus_management, user_preferences_pid_or_name)
    focus_ring_opts = if is_list(opts) and opts == [], do: %{}, else: opts
    focus_ring_config = FocusRing.init(focus_ring_opts)
    Process.put(:ux_refinement_focus_ring_config, focus_ring_config)
    _ = register_enabled_feature(:focus_ring)
    :ok
  end

  def enable_feature(:accessibility, opts, user_preferences_pid_or_name) do
    ensure_feature_enabled(:events, user_preferences_pid_or_name)
    accessibility_module().enable(opts, user_preferences_pid_or_name)
    Process.put(:ux_refinement_metadata, %{})

    _ =
      focus_manager_module().register_focus_change_handler(
        fn a, b -> handle_accessibility_focus_change(a, b, nil) end
      )

    _ = register_enabled_feature(:accessibility)
    :ok
  end

  def enable_feature(:keyboard_shortcuts, _opts, user_preferences_pid_or_name) do
    keyboard_shortcuts_module().init()
    ensure_feature_enabled(:events, user_preferences_pid_or_name)
    _ = register_enabled_feature(:keyboard_shortcuts)
    :ok
  end

  def enable_feature(:events, _opts, _user_preferences_pid_or_name) do
    EventManager.init()
    _ = register_enabled_feature(:events)
    :ok
  end

  def enable_feature(unknown_feature, _opts, _user_preferences_pid_or_name) do
    {:error, "Unknown feature: #{unknown_feature}"}
  end

  def enable_feature(feature) do
    enable_feature(feature, [], nil)
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
    accessibility_module().disable(nil)
    Process.put(:ux_refinement_metadata, %{})

    focus_manager_module().unregister_focus_change_handler(
      fn a, b -> handle_accessibility_focus_change(a, b, nil) end
    )

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
    ensure_feature_enabled(:hints, component_id)

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
      ...>   examples: "Type keywords like "settings" or "help"",
      ...>   shortcuts: [
      ...>     {"Enter", "Execute search"},
      ...>     {"Alt+S", "Focus search"}
      ...>   ]
      ...> })
      :ok

      iex> UXRefinement.register_component_hint("simple_button", "Click me")
      :ok
  """
  def register_component_hint(component_id, hint_info_string)
      when is_binary(hint_info_string) do
    register_component_hint(component_id, %{basic: hint_info_string})
  end

  def register_component_hint(component_id, hint_info) when is_map(hint_info) do
    # Ensure hints feature is enabled
    ensure_feature_enabled(:hints, component_id)

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
    ensure_feature_enabled(:hints, component_id)

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
    ensure_feature_enabled(:hints, component_id)

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
    ensure_feature_enabled(:hints, component_id)

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
      Raxol.Core.Runtime.Log.debug(
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

  defp ensure_feature_enabled(:events, _user_preferences_pid_or_name) do
    # Initialize events manager if not already done
    EventManager.init()
    # Register the feature as enabled
    register_enabled_feature(:events)
    # Return original value
    :ok
  end

  defp ensure_feature_enabled(feature, user_preferences_pid_or_name)
       when feature != :events do
    if feature_enabled?(feature) do
      :ok
    else
      enable_feature(feature, [], user_preferences_pid_or_name)
    end
  end

  defp handle_accessibility_focus_change(
         old_focus,
         new_focus,
         user_preferences_pid_or_name
       ) do
    if feature_enabled?(:accessibility) do
      metadata = get_accessibility_metadata(new_focus) || %{}
      label = Map.get(metadata, :label, new_focus)

      announcement_message =
        if is_nil(old_focus) do
          "Focus set to #{label}"
        else
          "Focus moved from #{get_accessibility_metadata(old_focus)[:label] || old_focus} to #{label}"
        end

      announce(
        announcement_message,
        [priority: :low],
        user_preferences_pid_or_name
      )
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
    ensure_feature_enabled(:keyboard_shortcuts, component_id)
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
        Raxol.Core.Runtime.Log.warning_with_context(
          "Invalid shortcut format for component #{component_id}: must be {key_string, description_string}",
          %{}
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
      # Keep debug for now
      Raxol.Core.Runtime.Log.debug(
        "Shortcut activated for #{component_id}: #{description}"
      )

      # Also attempt to set focus to the component associated with the hint
      focus_manager_module().set_focus(component_id)
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

  @doc """
  Display help for available keyboard shortcuts.
  """
  def show_shortcuts_help(user_preferences_pid_or_name) do
    ensure_feature_enabled(:keyboard_shortcuts, user_preferences_pid_or_name)

    keyboard_shortcuts_module().show_shortcuts_help(
      user_preferences_pid_or_name
    )
  end

  @doc """
  Set the active context for keyboard shortcuts.
  """
  def set_shortcuts_context(context) do
    ensure_feature_enabled(:keyboard_shortcuts, context)
    keyboard_shortcuts_module().set_context(context)
  end

  @doc """
  Get all available shortcuts for a given context.
  If no context is provided, returns shortcuts for the current active context.
  """
  def get_available_shortcuts(context \\ nil) do
    ensure_feature_enabled(:keyboard_shortcuts, context)
    keyboard_shortcuts_module().get_shortcuts_for_context(context)
  end

  @doc """
  Make an announcement for screen readers.

  ## Parameters
  * `message` - The message to announce
  * `opts` - Options for the announcement
  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (required)
  """
  def announce(message, opts \\ [], user_preferences_pid_or_name) do
    if feature_enabled?(:accessibility) do
      accessibility_module().announce(
        message,
        opts,
        user_preferences_pid_or_name
      )
    else
      Raxol.Core.Runtime.Log.debug(
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
      Raxol.Core.Runtime.Log.debug(
        "[UXRefinement] Accessibility not enabled, metadata registration skipped for #{component_id}"
      )

      # Or store in Process.put(:ux_refinement_metadata, ...) directly if needed
      :ok
    end
  end

  @doc """
  Display help for available keyboard shortcuts (no user preferences context).
  """
  def show_shortcuts_help do
    show_shortcuts_help(nil)
  end
end
