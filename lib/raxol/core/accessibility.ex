defmodule Raxol.Core.Accessibility do
  @behaviour Raxol.Core.Accessibility.Behaviour

  @moduledoc """
  Accessibility module for Raxol terminal UI applications.

  This module provides accessibility features including:
  - Screen reader announcements
  - Keyboard navigation enhancements
  - High contrast mode
  - Reduced motion support
  - Focus management
  - Large text support

  ## Usage

  ```elixir
  # Enable accessibility features
  Accessibility.enable()

  # Make an announcement for screen readers
  Accessibility.announce("You have selected the search button")

  # Enable high contrast mode
  Accessibility.set_high_contrast(true)

  # Enable reduced motion mode
  Accessibility.set_reduced_motion(true)

  # Enable large text mode
  Accessibility.set_large_text(true)
  ```
  """

  alias Raxol.Core.Events.Manager, as: EventManager

  alias Raxol.Core.Accessibility.{
    Announcements,
    EventHandlers,
    Legacy,
    Metadata,
    Preferences,
    ThemeIntegration
  }

  require Raxol.Core.Runtime.Log

  @doc """
  Enable accessibility features with the given options.

  ## Parameters

  * `options` - Options to override the default accessibility settings
  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

  ## Options

  * `:high_contrast` - Enable high contrast mode (default: `false`)
  * `:reduced_motion` - Enable reduced motion (default: `false`)
  * `:large_text` - Enable large text (default: `false`)
  * `:screen_reader` - Enable screen reader support (default: `true`)
  * `:keyboard_focus` - Enable keyboard focus indicators (default: `true`)
  * `:silence_announcements` - Silence screen reader announcements (default: `false`)

  ## Examples

      iex> Accessibility.enable(high_contrast: true)
      :ok

      iex> Accessibility.enable(reduced_motion: true, screen_reader: false)
      :ok
  """
  def enable(options \\ [], user_preferences_pid_or_name \\ nil) do
    Raxol.Core.Runtime.Log.debug(
      "Enabling accessibility features with options: #{inspect(options)} and pid_or_name: #{inspect(user_preferences_pid_or_name)}"
    )

    # Start with the default options
    full_options = [
      enabled: true,
      screen_reader: true,
      high_contrast: false,
      reduced_motion: false,
      keyboard_focus: true,
      large_text: false,
      silence_announcements: false
    ]

    # Override with custom options
    updated_options = Keyword.merge(full_options, options)

    Raxol.Core.Runtime.Log.debug(
      "[Accessibility] Enabling with options: #{inspect(updated_options)}"
    )

    # Apply all settings
    Preferences.set_option(:enabled, true, user_preferences_pid_or_name)

    Preferences.set_option(
      :screen_reader,
      Keyword.get(updated_options, :screen_reader),
      user_preferences_pid_or_name
    )

    Preferences.set_option(
      :high_contrast,
      Keyword.get(updated_options, :high_contrast),
      user_preferences_pid_or_name
    )

    Preferences.set_option(
      :reduced_motion,
      Keyword.get(updated_options, :reduced_motion),
      user_preferences_pid_or_name
    )

    Preferences.set_option(
      :keyboard_focus,
      Keyword.get(updated_options, :keyboard_focus),
      user_preferences_pid_or_name
    )

    Preferences.set_option(
      :large_text,
      Keyword.get(updated_options, :large_text),
      user_preferences_pid_or_name
    )

    Preferences.set_option(
      :silence_announcements,
      Keyword.get(updated_options, :silence_announcements),
      user_preferences_pid_or_name
    )

    # Reset internal state
    Process.put(:accessibility_disabled, false)
    Process.delete(:accessibility_announcements)

    # Initialize theme integration
    ThemeIntegration.init()

    # Apply settings using the ThemeIntegration.apply_settings function
    ThemeIntegration.apply_settings(updated_options)

    :ok
  end

  @doc """
  Disable accessibility features.

  ## Examples

      iex> Accessibility.disable()
      :ok
  """
  def disable(user_preferences_pid_or_name \\ nil) do
    target_prefs =
      user_preferences_pid_or_name || Preferences.default_prefs_name()

    Raxol.Core.Runtime.Log.debug(
      "Disabling accessibility features for #{inspect(target_prefs)}"
    )

    # Set disabled flag in UserPreferences
    Preferences.set_option(:enabled, false, target_prefs)

    # Set process dictionary flag for immediate local effect if needed
    Process.put(:accessibility_disabled, true)

    # Unregister event handlers
    EventManager.unregister_handler(
      :focus_change,
      __MODULE__,
      :handle_focus_change
    )

    # Unregister event handler for preference changes
    EventManager.unregister_handler(
      :preference_changed,
      __MODULE__,
      :handle_preference_changed
    )

    # Unregister event handler for locale changes
    EventManager.unregister_handler(
      :locale_changed,
      __MODULE__,
      :handle_locale_changed
    )

    # Unregister event handler for theme changes
    EventManager.unregister_handler(
      :theme_changed,
      __MODULE__,
      :handle_theme_changed
    )

    # Clean up theme integration
    ThemeIntegration.cleanup()

    # Clear process dictionary values
    Process.put(:accessibility_announcements, [])

    :ok
  end

  @doc """
  Make an announcement for screen readers.

  This function adds a message to the announcement queue that will be
  read by screen readers.

  ## Parameters

  * `message` - The message to announce
  * `opts` - Options for the announcement
  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (required).

  ## Options

  * `:priority` - Priority level (`:low`, `:medium`, `:high`) (default: `:medium`)
  * `:interrupt` - Whether to interrupt current announcements (default: `false`)

  ## Examples

      iex> Accessibility.announce("Button clicked", [], pid)
      :ok

      iex> Accessibility.announce("Error occurred", [priority: :high, interrupt: true], pid)
      :ok
  """
  def announce(message, opts \\ [], user_preferences_pid_or_name) when is_binary(message) do
    if is_nil(user_preferences_pid_or_name) do
      raise "Accessibility.announce/3 must be called with a user_preferences_pid_or_name."
    end
    Announcements.announce(message, opts, user_preferences_pid_or_name)
  end

  @doc """
  Get the next announcement to be read by screen readers.

  This function is typically called by the screen reader integration.

  ## Examples

      iex> Accessibility.get_next_announcement()
      "Button clicked"
  """
  def get_next_announcement(user_preferences_pid_or_name) do
    Announcements.get_next_announcement(user_preferences_pid_or_name)
  end

  @doc """
  Clear all pending announcements.

  ## Examples

      iex> Accessibility.clear_announcements()
      :ok
  """
  def clear_announcements do
    Announcements.clear_announcements()
  end

  @doc """
  Enable or disable high contrast mode.

  ## Parameters

  * `enabled` - `true` to enable high contrast, `false` to disable.
  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

  ## Examples

      iex> Accessibility.set_high_contrast(true)
      :ok
  """
  def set_high_contrast(enabled, user_preferences_pid_or_name \\ nil)
      when is_boolean(enabled) do
    Preferences.set_high_contrast(enabled, user_preferences_pid_or_name)
  end

  @doc """
  Enable or disable reduced motion.

  ## Parameters

  * `enabled` - `true` to enable reduced motion, `false` to disable.
  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

  ## Examples

      iex> Accessibility.set_reduced_motion(true)
      :ok
  """
  def set_reduced_motion(enabled, user_preferences_pid_or_name \\ nil)
      when is_boolean(enabled) do
    Preferences.set_reduced_motion(enabled, user_preferences_pid_or_name)
  end

  @doc """
  Enable or disable large text mode.

  ## Parameters

  * `enabled` - `true` to enable large text, `false` to disable.
  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

  ## Examples

      iex> Accessibility.set_large_text(true)
      :ok
  """
  def set_large_text(enabled, user_preferences_pid_or_name \\ nil)
      when is_boolean(enabled) do
    Preferences.set_large_text(enabled, user_preferences_pid_or_name)
  end

  @doc """
  Get the current text scale factor based on the large text setting.

  ## Parameters

  * `user_preferences_pid_or_name` - The PID or registered name of the UserPreferences process to use (optional).

  ## Examples

      iex> Accessibility.get_text_scale()
      1.0 # or 1.5 if large_text is enabled
  """
  def get_text_scale(user_preferences_pid_or_name \\ nil) do
    Preferences.get_text_scale(user_preferences_pid_or_name)
  end

  @doc """
  Get the current color scheme based on accessibility settings.

  ## Examples

      iex> Accessibility.get_color_scheme()
      %{background: ...}  # Returns the current color scheme
  """
  def get_color_scheme do
    ThemeIntegration.get_theme()
  end

  @doc """
  Register metadata for an element to be used for accessibility features.

  ## Parameters

  * `element_id` - Unique identifier for the element
  * `metadata` - Metadata to associate with the element

  ## Examples

      iex> Accessibility.register_element_metadata("search_button", %{label: "Search"})
      :ok
  """
  def register_element_metadata(element_id, metadata)
      when is_binary(element_id) and is_map(metadata) do
    Metadata.register_element_metadata(element_id, metadata)
  end

  @doc """
  Get metadata for an element.

  ## Parameters

  * `element_id` - Unique identifier for the element

  ## Returns

  * The metadata map for the element, or `nil` if not found

  ## Examples

      iex> Accessibility.get_element_metadata("search_button")
      %{label: "Search"}
  """
  def get_element_metadata(element_id) when is_binary(element_id) do
    Metadata.get_element_metadata(element_id)
  end

  @doc """
  Register style settings for a component type.

  ## Parameters

  * `component_type` - Atom representing the component type
  * `style` - Style map to associate with the component type

  ## Examples

      iex> Accessibility.register_component_style(:button, %{background: :blue})
      :ok
  """
  def register_component_style(component_type, style)
      when is_atom(component_type) and is_map(style) do
    Metadata.register_component_style(component_type, style)
  end

  @doc """
  Get style settings for a component type.

  ## Parameters

  * `component_type` - Atom representing the component type

  ## Returns

  * The style map for the component type, or empty map if not found

  ## Examples

      iex> Accessibility.get_component_style(:button)
      %{background: :blue}
  """
  def get_component_style(component_type) when is_atom(component_type) do
    Metadata.get_component_style(component_type)
  end

  # --- Event Handlers ---

  @doc false
  def handle_focus_change(event, user_preferences_pid_or_name) do
    EventHandlers.handle_focus_change(event, user_preferences_pid_or_name)
  end

  @doc false
  def handle_preference_changed(event, user_preferences_pid_or_name \\ nil) do
    EventHandlers.handle_preference_changed(event, user_preferences_pid_or_name)
  end

  @doc false
  def handle_locale_changed(event) do
    EventHandlers.handle_locale_changed(event)
  end

  @doc false
  def handle_theme_changed(event, user_preferences_pid_or_name) do
    EventHandlers.handle_theme_changed(event, user_preferences_pid_or_name)
  end

  # --- Legacy Functions ---

  @doc false
  def high_contrast_enabled?(user_preferences_pid_or_name \\ nil)
  def high_contrast_enabled?(user_preferences_pid_or_name) do
    Preferences.get_option(:high_contrast, user_preferences_pid_or_name, false)
  end

  @doc false
  def reduced_motion_enabled?(user_preferences_pid_or_name) do
    Legacy.reduced_motion_enabled?(user_preferences_pid_or_name)
  end

  @doc false
  def large_text_enabled?(user_preferences_pid_or_name) do
    Legacy.large_text_enabled?(user_preferences_pid_or_name)
  end

  @doc """
  Gets an accessibility option value.
  """
  def get_option(category, option, default \\ nil) do
    Application.get_env(:raxol, :accessibility, %{})
    |> Map.get(category, %{})
    |> Map.get(option, default)
  end

  @doc """
  Sets an accessibility option value.
  """
  def set_option(category, option, value) do
    current = Application.get_env(:raxol, :accessibility, %{})
    category_settings = Map.get(current, category, %{})
    new_category_settings = Map.put(category_settings, option, value)
    new_settings = Map.put(current, category, new_category_settings)
    Application.put_env(:raxol, :accessibility, new_settings)
  end

  @doc """
  Checks if screen reader support is enabled.
  """
  def screen_reader_enabled?(_opts) do
    get_option(:assistive, :screen_reader, false)
  end

  @doc """
  Gets the current font size multiplier.
  """
  def font_size_multiplier(_opts) do
    get_option(:display, :font_size_multiplier, 1.0)
  end

  @doc """
  Gets the current color scheme.
  """
  def color_scheme(_opts) do
    get_option(:display, :color_scheme, :default)
  end

  @doc """
  Subscribe a process (by ref) to accessibility announcement events.
  """
  def subscribe_to_announcements(ref) do
    EventManager.register_handler(
      :accessibility_announce,
      ref,
      :handle_announcement
    )

    :ok
  end

  @doc """
  Unsubscribe a process (by ref) from accessibility announcement events.
  """
  def unsubscribe_from_announcements(ref) do
    EventManager.unregister_handler(
      :accessibility_announce,
      ref,
      :handle_announcement
    )

    :ok
  end

  @doc false
  def get_next_announcement(), do: get_next_announcement(nil)

  def __mock_for__, do: Raxol.Core.Accessibility.Mock
end
