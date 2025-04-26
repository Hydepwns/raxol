defmodule Raxol.Core.Accessibility.ThemeIntegration do
  @moduledoc """
  Integrates accessibility settings with visual components.

  This module bridges the accessibility features with visual components
  to ensure proper rendering based on accessibility settings like:
  - High contrast mode
  - Reduced motion
  - Large text

  It provides event handlers that respond to accessibility setting changes
  and applies them to the appropriate components.

  ## Usage

  ```elixir
  # Initialize theme integration
  ThemeIntegration.init()

  # Apply current accessibility settings to components
  ThemeIntegration.apply_current_settings()
  ```
  """

  alias Raxol.Core.Events.Manager, as: EventManager
  # Remove Raxol.Logger alias - use Logger directly
  # alias Raxol.Logger
  require Logger
  alias Raxol.Core.Accessibility # Added alias
  alias Raxol.Style.Theme # Added alias
  alias Raxol.Core.UserPreferences # Added alias

  # Process dictionary key for active theme variant state
  # @active_variant_key :raxol_active_theme_variant

  @doc """
  Initialize the theme integration.

  Registers event handlers for accessibility setting changes.

  ## Examples

      iex> ThemeIntegration.init()
      :ok
  """
  def init do
    # Register event handlers for accessibility settings
    EventManager.register_handler(
      :accessibility_high_contrast,
      __MODULE__,
      :handle_high_contrast
    )

    EventManager.register_handler(
      :accessibility_reduced_motion,
      __MODULE__,
      :handle_reduced_motion
    )

    EventManager.register_handler(
      :accessibility_large_text,
      __MODULE__,
      :handle_large_text
    )

    :ok
  end

  @doc """
  Clean up the theme integration.

  Unregisters event handlers.

  ## Examples

      iex> ThemeIntegration.cleanup()
      :ok
  """
  def cleanup do
    # Unregister event handlers
    EventManager.unregister_handler(
      :accessibility_high_contrast,
      __MODULE__,
      :handle_high_contrast
    )

    EventManager.unregister_handler(
      :accessibility_reduced_motion,
      __MODULE__,
      :handle_reduced_motion
    )

    EventManager.unregister_handler(
      :accessibility_large_text,
      __MODULE__,
      :handle_large_text
    )

    :ok
  end

  @doc """
  Apply the current accessibility settings to components.

  ## Examples

      iex> ThemeIntegration.apply_current_settings()
      :ok
  """
  def apply_current_settings do
    # Get current accessibility options
    options = Process.get(:accessibility_options) || default_options()

    # Apply high contrast setting
    handle_high_contrast(
      {:accessibility_high_contrast, options[:high_contrast]}
    )

    # Apply reduced motion setting
    handle_reduced_motion(
      {:accessibility_reduced_motion, options[:reduced_motion]}
    )

    # Apply large text setting
    handle_large_text({:accessibility_large_text, options[:large_text]})

    :ok
  end

  @doc """
  Handle high contrast mode changes.
  Stores the active variant (:high_contrast or nil) in the process dictionary.
  Components should then use a central function (e.g., ColorSystem.get) to query colors.
  """
  def handle_high_contrast({:accessibility_high_contrast, enabled}) do
    require Logger
    Logger.debug("ThemeIntegration handling high contrast event: #{enabled}")

    # No longer storing in process dictionary
    # active_variant = if enabled, do: :high_contrast, else: nil
    # Process.put(@active_variant_key, active_variant)

    # Components will now query Accessibility.get_option(:high_contrast)
    # or use ColorSystem which should internally check this.

    # Optionally, trigger a global UI refresh event if needed
    # EventManager.trigger(:ui_refresh_required, %{reason: :theme_variant_change})

    :ok
  end

  @doc """
  Gets the currently active theme variant name (e.g., :high_contrast) or nil.
  Reads the state directly from Accessibility (which reads from UserPreferences).
  """
  @spec get_active_variant() :: atom() | nil
  def get_active_variant do
    # Process.get(@active_variant_key)
    if Accessibility.get_option(:high_contrast) do
      :high_contrast
    else
      nil
    end
  end

  @doc """
  Handle reduced motion setting changes.

  ## Examples

      iex> ThemeIntegration.handle_reduced_motion({:accessibility_reduced_motion, true})
      :ok
  """
  def handle_reduced_motion({:accessibility_reduced_motion, _enabled}) do
    require Logger
    Logger.debug("Restoring FocusRing config for normal motion")
    # No animation, immediate focus change
    # FocusRing.configure(animation: :none, transition_effect: :none)

    :ok
  end

  @doc """
  Handle large text setting changes.

  ## Examples

      iex> ThemeIntegration.handle_large_text({:accessibility_large_text, true})
      :ok
  """
  def handle_large_text({:accessibility_large_text, enabled}) do
    # Update text size based on large text setting
    text_scale = if enabled, do: 1.5, else: 1.0

    # Store text scale factor in process dictionary for components to use - REMOVED?
    # Or should this also be a preference?
    # For now, keep in process dictionary as it's more transient display state
    Process.put(:accessibility_text_scale, text_scale)

    :ok
  end

  # Private functions

  defp default_options do
    # %{high_contrast: false, reduced_motion: false, large_text: false}
    # Read defaults from Accessibility module
    Accessibility.default_options()
  end

  # Add helper to check accessibility state directly if needed - REMOVED
  # defp is_high_contrast? do
  #   Accessibility.get_option(:high_contrast)
  # end
end
