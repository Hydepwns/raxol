defmodule Raxol.Core.Accessibility do
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
  alias Raxol.Core.Accessibility.ThemeIntegration
  alias Raxol.Core.UserPreferences
  require Logger

  # Key prefix for accessibility preferences
  @pref_prefix "accessibility"

  # Helper function to get preference key
  defp pref_key(key), do: "#{@pref_prefix}.#{key}"

  @doc """
  Enable accessibility features.

  ## Options

  * `:screen_reader` - Enable screen reader support (default: `true`)
  * `:high_contrast` - Enable high contrast mode (default: `false`)
  * `:reduced_motion` - Reduce or disable animations (default: `false`)
  * `:keyboard_focus` - Enhanced keyboard focus indicators (default: `true`)
  * `:large_text` - Use larger text for better readability (default: `false`)

  ## Examples

      iex> Accessibility.enable()
      :ok

      iex> Accessibility.enable(high_contrast: true, reduced_motion: true)
      :ok
  """
  def enable(opts \\ []) do
    Logger.debug(
      "Enabling accessibility features with options: #{inspect(opts)}"
    )

    # Get initial options from UserPreferences merged with explicit opts
    initial_options = load_initial_options(opts)

    Logger.debug(
      "[Accessibility] Enabling with options: #{inspect(initial_options)}"
    )

    # Register event handler for focus changes
    EventManager.register_handler(
      :focus_change,
      __MODULE__,
      :handle_focus_change
    )

    # Register event handler for preference changes
    EventManager.register_handler(
      :preference_changed,
      __MODULE__,
      :handle_preference_changed
    )

    # Register event handler for locale changes
    EventManager.register_handler(
      :locale_changed,
      __MODULE__,
      :handle_locale_changed
    )

    # Initialize the announcement queue
    Process.put(:accessibility_announcements, [])

    # Initialize theme integration
    ThemeIntegration.init()

    # Apply initial settings based on loaded preferences
    apply_initial_settings(initial_options)

    :ok
  end

  @doc """
  Disable accessibility features.

  ## Examples

      iex> Accessibility.disable()
      :ok
  """
  def disable do
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

    # Clean up theme integration
    ThemeIntegration.cleanup()

    # Clear process dictionary values
    Process.delete(:accessibility_announcements)
    # Process.delete(:accessibility_options) # No longer storing options here

    :ok
  end

  @doc """
  Make an announcement for screen readers.

  This function adds a message to the announcement queue that will be
  read by screen readers.

  ## Parameters

  * `message` - The message to announce
  * `opts` - Options for the announcement

  ## Options

  * `:priority` - Priority level (`:low`, `:medium`, `:high`) (default: `:medium`)
  * `:interrupt` - Whether to interrupt current announcements (default: `false`)

  ## Examples

      iex> Accessibility.announce("Button clicked")
      :ok

      iex> Accessibility.announce("Error occurred", priority: :high, interrupt: true)
      :ok
  """
  def announce(message, opts \\ []) when is_binary(message) do
    # Check if announcements are silenced globally
    silenced =
      UserPreferences.get([:accessibility, :silence_announcements]) || false

    unless silenced do
      priority = Keyword.get(opts, :priority, :normal)
      interrupt = Keyword.get(opts, :interrupt, false)

      # Only proceed if screen reader is enabled
      screen_reader_enabled =
        UserPreferences.get([:accessibility, :screen_reader]) || true

      if screen_reader_enabled do
        Logger.info("Announcing (SR): [#{priority}] #{message}")

        # Create announcement with metadata
        announcement = %{
          message: message,
          priority: priority,
          timestamp: System.monotonic_time(:millisecond),
          interrupt: interrupt
        }

        # Add to queue
        updated_queue =
          if announcement.interrupt do
            # Clear queue if interrupt is true
            [announcement]
          else
            # Add to queue based on priority
            insert_by_priority(
              Process.get(:accessibility_announcements) || [],
              announcement
            )
          end

        # Store updated queue
        Process.put(:accessibility_announcements, updated_queue)

        # Dispatch event to notify screen readers
        # In a real implementation, this would integrate with the system's
        # accessibility API. For now, we just emit an event.
        EventManager.dispatch({:accessibility_announce, message})
      end
    end

    :ok
  end

  @doc """
  Get the next announcement to be read by screen readers.

  This function is typically called by the screen reader integration.

  ## Examples

      iex> Accessibility.get_next_announcement()
      "Button clicked"
  """
  def get_next_announcement do
    queue = Process.get(:accessibility_announcements) || []

    case queue do
      [] ->
        nil

      [next | rest] ->
        # Update queue
        Process.put(:accessibility_announcements, rest)
        next.message
    end
  end

  @doc """
  Clear all pending announcements.

  ## Examples

      iex> Accessibility.clear_announcements()
      :ok
  """
  def clear_announcements do
    Process.put(:accessibility_announcements, [])
    :ok
  end

  @doc """
  Enable or disable high contrast mode.

  ## Examples

      iex> Accessibility.set_high_contrast(true)
      :ok
  """
  def set_high_contrast(enabled) when is_boolean(enabled) do
    # Save setting to preferences
    :ok = UserPreferences.set(pref_key(:high_contrast), enabled)
    # Dispatch event to notify listeners (like ThemeIntegration)
    EventManager.dispatch({:accessibility_high_contrast, enabled})
    :ok
  end

  @doc """
  Enable or disable reduced motion.

  ## Examples

      iex> Accessibility.set_reduced_motion(true)
      :ok
  """
  def set_reduced_motion(enabled) when is_boolean(enabled) do
    :ok = UserPreferences.set(pref_key(:reduced_motion), enabled)
    EventManager.dispatch({:accessibility_reduced_motion, enabled})
    :ok
  end

  @doc """
  Enable or disable large text mode.

  ## Examples

      iex> Accessibility.set_large_text(true)
      :ok
  """
  def set_large_text(enabled) when is_boolean(enabled) do
    :ok = UserPreferences.set(pref_key(:large_text), enabled)
    EventManager.dispatch({:accessibility_large_text, enabled})
    :ok
  end

  @doc """
  Get the current text scale factor.

  ## Examples

      iex> Accessibility.get_text_scale()
      1.0  # Default scale

      iex> Accessibility.set_large_text(true)
      iex> Accessibility.get_text_scale()
      1.5  # Large text scale
  """
  def get_text_scale do
    Process.get(:accessibility_text_scale) || 1.0
  end

  @doc """
  Get the current color scheme based on accessibility settings.

  ## Examples

      iex> Accessibility.get_color_scheme()
      %{background: ...}  # Returns the current color scheme
  """
  def get_color_scheme do
    theme = Raxol.Style.Theme.current()
    active_variant = ThemeIntegration.get_active_variant()

    variant_palette =
      if active_variant do
        theme.variants
        |> Map.get(active_variant, %{})
        |> Map.get(:color_palette)
      end

    # Return variant palette if it exists, otherwise base theme palette
    variant_palette || theme.color_palette
  end

  @doc """
  Handle focus change events for accessibility announcements.

  ## Examples

      iex> Accessibility.handle_focus_change(nil, "search_button")
      :ok
  """
  def handle_focus_change(_old_focus, new_focus) do
    # Handle focus change
    {:ok, new_focus}
  end

  @doc """
  Register metadata for an element to be used for accessibility features.

  ## Parameters

  * `element_id` - Unique identifier for the element
  * `metadata` - Metadata to associate with the element

  ## Examples

      iex> Accessibility.register_metadata("search_button", %{label: "Search"})
      :ok
  """
  def register_metadata(_element_id, _metadata) do
    :ok
  end

  @doc """
  Get an accessibility option value.

  ## Parameters

  * `key` - The option key to get

  ## Examples

      iex> Accessibility.get_option(:high_contrast)
      false
  """
  def get_option(key) when is_atom(key) do
    # Use the same key format as our other accessibility functions
    UserPreferences.get(pref_key(key)) || Map.get(default_options(), key)
  end

  @doc """
  Set an accessibility option value.

  ## Parameters

  * `key` - The option key to set
  * `value` - The value to set

  ## Examples

      iex> Accessibility.set_option(:high_contrast, true)
      :ok
  """
  def set_option(key, value) when is_atom(key) do
    # Use our existing functions for specific settings when available
    case key do
      :high_contrast -> set_high_contrast(value)
      :reduced_motion -> set_reduced_motion(value)
      :large_text -> set_large_text(value)
      _ ->
        # For other settings, save directly to preferences
        :ok = UserPreferences.set(pref_key(key), value)
        # Dispatch a generic event
        EventManager.dispatch({:accessibility_option_changed, key, value})
    end
    :ok
  end

  # --- Private Helper Functions (Placeholders) ---

  # Placeholder for default accessibility options
  defp default_options do
    %{
      # Accessibility enabled by default
      enabled: true,
      # Screen reader support enabled by default
      screen_reader: true,
      high_contrast: false,
      reduced_motion: false,
      keyboard_focus: true,
      large_text: false,
      silence_announcements: false
    }
  end

  # Placeholder for loading options (merge defaults, preferences, explicit opts)
  defp load_initial_options(opts) do
    default_opts = default_options()

    pref_opts =
      Enum.reduce(Map.keys(default_opts), %{}, fn key, acc ->
        pref_value = UserPreferences.get(pref_key(key))

        if pref_value != nil do
          Map.put(acc, key, pref_value)
        else
          acc
        end
      end)

    default_opts
    |> Map.merge(pref_opts)
    |> Map.merge(
      Keyword.keyword?(opts)
      |> if do
        Map.new(opts)
      else
        %{}
      end
    )
  end

  # Placeholder for applying settings based on options
  defp apply_initial_settings(options) do
    set_high_contrast(Map.get(options, :high_contrast, false))
    set_reduced_motion(Map.get(options, :reduced_motion, false))
    set_large_text(Map.get(options, :large_text, false))
    # Other settings like text scale might be set here too
    Process.put(
      :accessibility_text_scale,
      if Map.get(options, :large_text, false) do
        1.5
      else
        1.0
      end
    )

    :ok
  end

  # Placeholder for inserting announcement into queue by priority
  defp insert_by_priority(queue, announcement) do
    # Simple append for now, ignores priority
    queue ++ [announcement]
  end

  # --- Removed Unused Placeholder Handlers ---
  # defp handle_preference_changed(_key, _value) do ... end
  # defp handle_locale_changed(_new_locale) do ... end
end
