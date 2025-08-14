defmodule Raxol.Core.Accessibility do
  @moduledoc """
  Refactored Accessibility module that delegates to the unified GenServer.
  
  This module provides the same API as the original Accessibility module but uses
  a supervised GenServer instead of the Process dictionary for state management.
  
  ## Migration Notice
  This module is a drop-in replacement for `Raxol.Core.Accessibility`.
  All functions maintain backward compatibility while providing improved
  fault tolerance and functional programming patterns.
  
  ## Benefits over Process Dictionary
  - Unified state management across all accessibility features
  - Supervised state with fault tolerance
  - Pure functional transformations
  - Announcement queuing with priority
  - Better debugging and testing capabilities
  - No global state pollution
  
  ## Consolidated Modules
  This refactored version consolidates functionality from:
  - `Raxol.Core.Accessibility`
  - `Raxol.Core.Accessibility.Announcements`
  - `Raxol.Core.Accessibility.Metadata`
  """

  @behaviour Raxol.Core.Accessibility.Behaviour

  alias Raxol.Core.Accessibility.Server
  alias Raxol.Core.Events.Manager, as: EventManager

  @doc """
  Ensures the Accessibility server is started.
  """
  def ensure_started do
    case Process.whereis(Server) do
      nil ->
        {:ok, _pid} = Server.start_link()
        :ok
      _pid ->
        :ok
    end
  end

  @doc """
  Enable accessibility features with the given options.
  
  ## Options
  - `:high_contrast` - Enable high contrast mode (default: `false`)
  - `:reduced_motion` - Enable reduced motion (default: `false`)
  - `:large_text` - Enable large text (default: `false`)
  - `:screen_reader` - Enable screen reader support (default: `true`)
  - `:keyboard_focus` - Enable keyboard focus indicators (default: `true`)
  - `:silence_announcements` - Silence screen reader announcements (default: `false`)
  """
  def enable(options \\ [], user_preferences_pid_or_name \\ nil) do
    ensure_started()
    Server.enable(options, user_preferences_pid_or_name)
  end

  @doc """
  Disable accessibility features.
  """
  def disable do
    ensure_started()
    Server.disable()
  end

  @doc """
  Check if accessibility features are enabled.
  """
  def enabled? do
    ensure_started()
    Server.enabled?()
  end

  @doc """
  Make an announcement for screen readers.
  
  ## Options
  - `:priority` - Priority level (:high, :medium, :low) default: :medium
  - `:interrupt` - Whether to interrupt current announcement default: false
  - `:language` - Language for the announcement
  """
  def announce(message, opts \\ []) do
    ensure_started()
    Server.announce(message, opts)
    :ok
  end

  @doc """
  Set high contrast mode.
  """
  def set_high_contrast(enabled) when is_boolean(enabled) do
    ensure_started()
    Server.set_high_contrast(enabled)
  end

  @doc """
  Check if high contrast mode is enabled.
  """
  def high_contrast? do
    ensure_started()
    Server.high_contrast?()
  end

  @doc """
  Set reduced motion mode.
  """
  def set_reduced_motion(enabled) when is_boolean(enabled) do
    ensure_started()
    Server.set_reduced_motion(enabled)
  end

  @doc """
  Check if reduced motion mode is enabled.
  """
  def reduced_motion? do
    ensure_started()
    Server.reduced_motion?()
  end

  @doc """
  Set large text mode.
  """
  def set_large_text(enabled) when is_boolean(enabled) do
    ensure_started()
    Server.set_large_text(enabled)
  end

  @doc """
  Check if large text mode is enabled.
  """
  def large_text? do
    ensure_started()
    Server.large_text?()
  end

  @doc """
  Set screen reader support.
  """
  def set_screen_reader(enabled) when is_boolean(enabled) do
    ensure_started()
    Server.set_screen_reader(enabled)
  end

  @doc """
  Check if screen reader support is enabled.
  """
  def screen_reader? do
    ensure_started()
    Server.screen_reader?()
  end

  @doc """
  Set keyboard focus indicators.
  """
  def set_keyboard_focus(enabled) when is_boolean(enabled) do
    ensure_started()
    Server.set_keyboard_focus(enabled)
  end

  @doc """
  Get all accessibility preferences.
  """
  def get_preferences do
    ensure_started()
    Server.get_preferences()
  end

  # Announcements module functions

  @doc """
  Announce with synchronous confirmation.
  """
  def announce_sync(message, opts \\ []) do
    ensure_started()
    Server.announce_sync(message, opts)
  end

  @doc """
  Get announcement history.
  """
  def get_announcement_history(limit \\ nil) do
    ensure_started()
    Server.get_announcement_history(limit)
  end

  @doc """
  Clear announcement history.
  """
  def clear_announcement_history do
    ensure_started()
    Server.clear_announcement_history()
  end

  @doc """
  Set announcement callback function.
  """
  def set_announcement_callback(callback) when is_function(callback, 1) do
    ensure_started()
    Server.set_announcement_callback(callback)
  end

  # Metadata module functions

  @doc """
  Set accessibility metadata for a component.
  
  ## Metadata fields
  - `:label` - Accessible label for the component
  - `:role` - ARIA role (button, navigation, etc.)
  - `:description` - Extended description
  - `:hint` - Usage hint for screen readers
  - `:state` - Current state (expanded, selected, etc.)
  """
  def set_metadata(component_id, metadata) do
    ensure_started()
    Server.set_metadata(component_id, metadata)
  end

  @doc """
  Get accessibility metadata for a component.
  """
  def get_metadata(component_id) do
    ensure_started()
    Server.get_metadata(component_id)
  end

  @doc """
  Remove metadata for a component.
  """
  def remove_metadata(component_id) do
    ensure_started()
    Server.remove_metadata(component_id)
  end

  @doc """
  Update a specific metadata field for a component.
  """
  def update_metadata(component_id, field, value) do
    ensure_started()
    current = Server.get_metadata(component_id) || %{}
    updated = Map.put(current, field, value)
    Server.set_metadata(component_id, updated)
  end

  # Event handler functions (for backward compatibility)

  @doc """
  Handle focus change event.
  """
  def handle_focus_change_event({:focus_change, old_focus, new_focus}) do
    ensure_started()
    Server.handle_focus_change(old_focus, new_focus)
    :ok
  end

  def handle_preference_changed_event(_event), do: :ok
  def handle_locale_changed_event(_event), do: :ok
  def handle_theme_changed_event(_event), do: :ok

  # Additional helper functions

  @doc """
  Announce component activation.
  """
  def announce_activation(component_id) do
    metadata = get_metadata(component_id) || %{}
    label = Map.get(metadata, :label, component_id)
    announce("#{label} activated", priority: :high)
  end

  @doc """
  Announce value change.
  """
  def announce_value_change(component_id, old_value, new_value) do
    metadata = get_metadata(component_id) || %{}
    label = Map.get(metadata, :label, component_id)
    announce("#{label} changed from #{old_value} to #{new_value}", priority: :medium)
  end

  @doc """
  Check if any accessibility feature is active.
  """
  def any_feature_active? do
    ensure_started()
    prefs = Server.get_preferences()
    
    prefs.high_contrast || 
    prefs.reduced_motion || 
    prefs.large_text || 
    prefs.screen_reader || 
    prefs.keyboard_focus
  end

  @doc """
  Reset all accessibility settings to defaults.
  """
  def reset do
    ensure_started()
    disable()
    enable()
  end
end