defmodule Raxol.Core.Accessibility.ThemeIntegration do
  @moduledoc """
  Manages the integration between accessibility settings and the active theme.

  Listens for accessibility changes (e.g., high contrast toggle) and
  updates the active theme variant accordingly.
  """

  require Logger

  alias Raxol.Core.Events.Manager, as: EventManager
  # alias Raxol.UI.Theming.Theme # Removed unused alias
  alias Raxol.Core.UserPreferences
  # Remove unused aliases
  # alias Raxol.Style.Theme # Added alias
  # alias Raxol.Core.UserPreferences # Added alias

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
  This function is typically called during initialization to ensure components
  reflect the persisted preferences.
  """
  def apply_current_settings do
    # Get current accessibility options directly from UserPreferences
    # Assuming default values are handled by UserPreferences.get/3 or similar
    high_contrast = UserPreferences.get(pref_key(:high_contrast)) || false
    reduced_motion = UserPreferences.get(pref_key(:reduced_motion)) || false
    large_text = UserPreferences.get(pref_key(:large_text)) || false

    # Apply high contrast setting
    handle_high_contrast({:accessibility_high_contrast, high_contrast})

    # Apply reduced motion setting
    handle_reduced_motion({:accessibility_reduced_motion, reduced_motion})

    # Apply large text setting
    handle_large_text({:accessibility_large_text, large_text})

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
  Returns the currently active theme variant based on accessibility settings.
  Defaults to `:default` if high contrast is off.
  """
  @spec get_active_variant() :: atom()
  def get_active_variant() do
    # Read using UserPreferences
    is_high_contrast = UserPreferences.get(pref_key(:high_contrast)) || false
    if is_high_contrast do
      # Return the variant atom directly
      :high_contrast
    else
      :default
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

  # Helper to mimic internal pref_key logic
  defp pref_key(key), do: "accessibility.#{key}"
end
