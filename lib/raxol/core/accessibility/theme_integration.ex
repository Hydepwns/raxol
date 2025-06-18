defmodule Raxol.Core.Accessibility.ThemeIntegration do
  @moduledoc '''
  Manages the integration between accessibility settings and the active theme.

  Listens for accessibility changes (e.g., high contrast toggle) and
  updates the active theme accordingly.
  '''

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.UserPreferences
  alias Raxol.UI.Theming.Theme

  @doc '''
  Initialize the theme integration.

  Registers event handlers for accessibility setting changes.

  ## Examples

      iex> ThemeIntegration.init()
      :ok
  '''
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

    EventManager.register_handler(
      :theme_changed,
      Raxol.Core.Accessibility,
      :handle_theme_changed
    )

    :ok
  end

  @doc '''
  Clean up the theme integration.

  Unregisters event handlers.

  ## Examples

      iex> ThemeIntegration.cleanup()
      :ok
  '''
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

    EventManager.unregister_handler(
      :theme_changed,
      Raxol.Core.Accessibility,
      :handle_theme_changed
    )

    :ok
  end

  @doc '''
  Apply the current accessibility settings to components.
  This function is typically called during initialization to ensure components
  reflect the persisted preferences.
  Accepts a keyword list of options (e.g., `[high_contrast: true, ...]`).
  '''
  def apply_settings(options) when is_list(options) do
    # Get settings directly from the passed options
    high_contrast = Keyword.get(options, :high_contrast, false)
    reduced_motion = Keyword.get(options, :reduced_motion, false)
    large_text = Keyword.get(options, :large_text, false)

    # Apply high contrast setting
    handle_high_contrast({:accessibility_high_contrast, high_contrast})

    # Apply reduced motion setting
    handle_reduced_motion({:accessibility_reduced_motion, reduced_motion})

    # Apply large text setting
    handle_large_text({:accessibility_large_text, large_text})

    :ok
  end

  @doc '''
  Handle high contrast mode changes.
  Updates the theme based on high contrast setting.
  '''
  def handle_high_contrast({:accessibility_high_contrast, enabled}) do
    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.debug(
      "ThemeIntegration handling high contrast event: #{enabled}"
    )

    # Trigger a global UI refresh event
    EventManager.trigger(:ui_refresh_required, %{reason: :theme_change})

    :ok
  end

  @doc '''
  Returns the current accessibility mode based on settings.
  Defaults to `:normal` if high contrast is off.
  '''
  @spec get_accessibility_mode() :: atom()
  def get_accessibility_mode() do
    # Read using UserPreferences
    is_high_contrast = UserPreferences.get(pref_key(:high_contrast)) || false

    if is_high_contrast do
      :high_contrast
    else
      :normal
    end
  end

  @doc '''
  Handle reduced motion setting changes.

  ## Examples

      iex> ThemeIntegration.handle_reduced_motion({:accessibility_reduced_motion, true})
      :ok
  '''
  def handle_reduced_motion({:accessibility_reduced_motion, _enabled}) do
    require Raxol.Core.Runtime.Log
    Raxol.Core.Runtime.Log.debug("Restoring FocusRing config for normal motion")

    :ok
  end

  @doc '''
  Handle large text setting changes.

  ## Examples

      iex> ThemeIntegration.handle_large_text({:accessibility_large_text, true})
      :ok
  '''
  def handle_large_text({:accessibility_large_text, _enabled}) do
    :ok
  end

  # Helper to mimic internal pref_key logic
  defp pref_key(key), do: "accessibility.#{key}"

  @doc '''
  Get the current theme based on accessibility settings.

  ## Examples

      iex> ThemeIntegration.get_theme()
      %Theme{}  # Returns the current theme with accessibility adjustments
  '''
  def get_theme do
    theme = Theme.current()
    mode = get_accessibility_mode()

    if mode == :high_contrast do
      Theme.adjust_for_high_contrast(theme)
    else
      theme
    end
  end

  @doc '''
  Returns the current active theme variant for accessibility-aware theming.
  Used by the renderer and theming system to select the correct theme variant.

  ## Examples

      iex> ThemeIntegration.get_active_variant()
      :normal | :high_contrast
  '''
  @spec get_active_variant() :: atom()
  def get_active_variant do
    get_accessibility_mode()
  end
end
