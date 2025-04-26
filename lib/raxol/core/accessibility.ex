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
    # Get screen reader setting directly from preferences
    if UserPreferences.get(
         pref_key(:screen_reader),
         default_options()[:screen_reader]
       ) do
      # Get options
      _options = Process.get(:accessibility_options) || default_options()

      # Create announcement with metadata
      announcement = %{
        message: message,
        priority: Keyword.get(opts, :priority, :medium),
        timestamp: System.monotonic_time(:millisecond),
        interrupt: Keyword.get(opts, :interrupt, false)
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
    ThemeIntegration.get_current_colors()
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
  * `metadata` - Map containing accessibility metadata

  ## Metadata Options

  * `:announce` - Text to announce when element receives focus
  * `:role` - ARIA role (e.g., `:button`, `:textbox`)
  * `:label` - Accessible label
  * `:description` - Detailed description of the element
  * `:shortcut` - Keyboard shortcut for the element

  ## Examples

      iex> Accessibility.register_element_metadata("search_button", %{
      ...>   announce: "Search button. Press Enter to search.",
      ...>   role: :button,
      ...>   label: "Search",
      ...>   shortcut: "Alt+S"
      ...> })
      :ok
  """
  def register_element_metadata(element_id, metadata)
      when is_binary(element_id) and is_map(metadata) do
    element_metadata = Process.get(:accessibility_element_metadata) || %{}
    updated_metadata = Map.put(element_metadata, element_id, metadata)
    Process.put(:accessibility_element_metadata, updated_metadata)
    :ok
  end

  @doc """
  Get metadata for an element.

  ## Examples

      iex> Accessibility.get_element_metadata("search_button")
      %{announce: "Search button. Press Enter to search.", role: :button, ...}
  """
  def get_element_metadata(element_id) when is_binary(element_id) do
    element_metadata = Process.get(:accessibility_element_metadata) || %{}
    Map.get(element_metadata, element_id)
  end

  @doc """
  Get style information for a component type based on current accessibility settings.

  ## Examples

      iex> Accessibility.get_component_style(:button)
      %{background: ..., foreground: ..., border: ...}
  """
  def get_component_style(component_type) when is_atom(component_type) do
    component_styles = Process.get(:accessibility_component_styles) || %{}
    Map.get(component_styles, component_type, %{})
  end

  @doc """
  Check if reduced motion is enabled.

  ## Examples

      iex> Accessibility.reduced_motion_enabled?()
      false
  """
  def reduced_motion_enabled? do
    UserPreferences.get(
      pref_key(:reduced_motion),
      default_options()[:reduced_motion]
    )
  end

  @doc """
  Check if high contrast mode is enabled.

  ## Examples

      iex> Accessibility.high_contrast_enabled?()
      false
  """
  def high_contrast_enabled? do
    UserPreferences.get(
      pref_key(:high_contrast),
      default_options()[:high_contrast]
    )
  end

  @doc """
  Check if large text mode is enabled.

  ## Examples

      iex> Accessibility.large_text_enabled?()
      false
  """
  def large_text_enabled? do
    UserPreferences.get(pref_key(:large_text), default_options()[:large_text])
  end

  @doc """
  Handle preference changed events for accessibility announcements.
  """
  def handle_preference_changed({:preference_changed, key, value}) do
    # Only react to changes relevant to accessibility
    # Check key against known preference keys *outside* guards
    high_contrast_key = pref_key(:high_contrast)
    reduced_motion_key = pref_key(:reduced_motion)
    large_text_key = pref_key(:large_text)

    # Use `case` to compare the key directly
    case key do
      ^high_contrast_key ->
        EventManager.dispatch({:accessibility_high_contrast, value})

      ^reduced_motion_key ->
        EventManager.dispatch({:accessibility_reduced_motion, value})

      ^large_text_key ->
        EventManager.dispatch({:accessibility_large_text, value})

      # Ignore other preference changes
      _ ->
        :ok
    end

    :ok
  end

  @doc """
  Handle locale changed events for accessibility announcements.
  """
  def handle_locale_changed({:locale_changed, _locale}) do
    # Handle locale changes for accessibility announcements
    # TODO: Implement locale-specific announcement logic
    :ok
  end

  # Private functions

  defp default_options do
    %{
      screen_reader: true,
      high_contrast: false,
      reduced_motion: false,
      keyboard_focus: true,
      large_text: false
    }
  end

  defp apply_initial_settings(options) do
    Logger.debug(
      "[Accessibility] Applying initial settings: #{inspect(options)}"
    )

    # Trigger events for initial state
    EventManager.dispatch(
      {:accessibility_high_contrast, options[:high_contrast]}
    )

    EventManager.dispatch(
      {:accessibility_reduced_motion, options[:reduced_motion]}
    )

    EventManager.dispatch({:accessibility_large_text, options[:large_text]})
  end

  defp load_initial_options(opts) do
    defaults = default_options()

    pref_options = %{
      high_contrast:
        UserPreferences.get(pref_key(:high_contrast), defaults[:high_contrast]),
      reduced_motion:
        UserPreferences.get(
          pref_key(:reduced_motion),
          defaults[:reduced_motion]
        ),
      large_text:
        UserPreferences.get(pref_key(:large_text), defaults[:large_text]),
      screen_reader:
        UserPreferences.get(pref_key(:screen_reader), defaults[:screen_reader]),
      keyboard_focus:
        UserPreferences.get(
          pref_key(:keyboard_focus),
          defaults[:keyboard_focus]
        )
    }

    # Explicit opts override preferences
    Keyword.merge(pref_options, opts)
  end

  defp insert_by_priority(queue, announcement) do
    # Simple priority: High > Medium > Low
    priority_order = %{high: 3, medium: 2, low: 1}
    _announcement_priority = Map.get(priority_order, announcement.priority, 0)

    Enum.sort_by(
      queue ++ [announcement],
      # Descending priority
      &(-Map.get(priority_order, &1.priority, 0)),
      # Ascending timestamp for same priority
      & &1.timestamp
    )
  end

  @doc """
  Get a specific accessibility option's current value.
  """
  @spec get_option(atom()) :: any()
  def get_option(key)
      when key in [
             :high_contrast,
             :reduced_motion,
             :large_text,
             :screen_reader,
             :keyboard_focus
           ] do
    UserPreferences.get(pref_key(key), default_options()[key])
  end
end
