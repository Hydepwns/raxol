defmodule Raxol.Core.Accessibility.ThemeIntegration do
  @moduledoc """
  Manages the integration between accessibility settings and the active theme.

  Listens for accessibility changes (e.g., high contrast toggle) and
  updates the active theme accordingly.
  """

  # require Raxol.Core.Runtime.Log  # Commented out due to missing module

  alias Raxol.Core.Events.EventManager, as: EventManager
  alias Raxol.Core.UserPreferences
  alias Raxol.UI.Theming.Theme

  @doc """
  Initialize the theme integration.

  Registers event handlers for accessibility setting changes.

  ## Examples

      iex> ThemeIntegration.init()
      :ok
  """
  def init do
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
      :handle_theme_changed_event
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
    handle_test_cleanup(Mix.env() == :test)

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
      :handle_theme_changed_event
    )

    :ok
  end

  @doc """
  Apply the current accessibility settings to components.
  This function is typically called during initialization to ensure components
  reflect the persisted preferences.
  Accepts a keyword list of options (e.g., `[high_contrast: true, ...]`).
  """
  def apply_settings(options) when is_list(options) do
    high_contrast = Keyword.get(options, :high_contrast, false)
    reduced_motion = Keyword.get(options, :reduced_motion, false)
    large_text = Keyword.get(options, :large_text, false)

    handle_high_contrast({:accessibility_high_contrast, high_contrast})

    handle_reduced_motion({:accessibility_reduced_motion, reduced_motion})

    handle_large_text({:accessibility_large_text, large_text})

    :ok
  end

  @doc """
  Handle high contrast mode changes.
  Updates the theme based on high contrast setting.
  """
  def handle_high_contrast({:accessibility_high_contrast, enabled}) do
    # require Raxol.Core.Runtime.Log  # Commented out due to missing module

    # Only try to set preference if the process exists
    case Process.whereis(UserPreferences) do
      nil -> :ok
      _pid -> UserPreferences.set(pref_key(:high_contrast), enabled)
    end

    # Raxol.Core.Runtime.Log.debug(
    #   "ThemeIntegration handling high contrast event: #{enabled}"
    # )

    EventManager.dispatch({:ui_refresh_required, %{reason: :theme_change}})

    EventManager.dispatch({:theme_changed, %{high_contrast: enabled}})

    :ok
  end

  @doc """
  Returns the current accessibility mode based on settings.
  Defaults to `:normal` if high contrast is off.
  """
  @spec get_accessibility_mode() :: atom()
  def get_accessibility_mode do
    # Only try to get preference if the process exists
    high_contrast =
      case Process.whereis(UserPreferences) do
        nil -> false
        _pid -> UserPreferences.get(pref_key(:high_contrast)) || false
      end

    determine_accessibility_mode(high_contrast)
  end

  @doc """
  Handle reduced motion setting changes.

  ## Examples

      iex> ThemeIntegration.handle_reduced_motion({:accessibility_reduced_motion, true})
      :ok
  """
  def handle_reduced_motion({:accessibility_reduced_motion, enabled}) do
    # require Raxol.Core.Runtime.Log  # Commented out due to missing module

    # Only try to set preference if the process exists
    case Process.whereis(UserPreferences) do
      nil -> :ok
      _pid -> UserPreferences.set(pref_key(:reduced_motion), enabled)
    end

    # Raxol.Core.Runtime.Log.debug("Restoring FocusRing config for normal motion")

    EventManager.dispatch({:theme_changed, %{reduced_motion: enabled}})

    :ok
  end

  @doc """
  Handle large text setting changes.

  ## Examples

      iex> ThemeIntegration.handle_large_text({:accessibility_large_text, true})
      :ok
  """
  def handle_large_text({:accessibility_large_text, enabled}) do
    # Only try to set preference if the process exists
    case Process.whereis(UserPreferences) do
      nil -> :ok
      _pid -> UserPreferences.set(pref_key(:large_text), enabled)
    end

    EventManager.dispatch({:theme_changed, %{large_text: enabled}})

    :ok
  end

  defp pref_key(key), do: "accessibility.#{key}"

  @doc """
  Get the current theme based on accessibility settings.

  ## Examples

      iex> ThemeIntegration.get_theme()
      %Theme{}  # Returns the current theme with accessibility adjustments
  """
  def get_theme do
    theme = Theme.current()
    mode = get_accessibility_mode()

    apply_theme_adjustments(mode == :high_contrast, theme, mode)
  end

  @doc """
  Returns the current active theme variant for accessibility-aware theming.
  Used by the renderer and theming system to select the correct theme variant.

  ## Examples

      iex> ThemeIntegration.get_active_variant()
      :standard | :high_contrast | :reduced_motion
  """
  @spec get_active_variant() :: atom()
  def get_active_variant do
    # Only try to get preferences if the process exists
    {high_contrast, reduced_motion} =
      case Process.whereis(UserPreferences) do
        nil ->
          {false, false}

        _pid ->
          {
            UserPreferences.get(pref_key(:high_contrast)) || false,
            UserPreferences.get(pref_key(:reduced_motion)) || false
          }
      end

    case {high_contrast, reduced_motion} do
      {true, _} -> :high_contrast
      {_, true} -> :reduced_motion
      {false, false} -> :standard
    end
  end

  @doc """
  Get the current color scheme based on accessibility settings.

  ## Examples

      iex> ThemeIntegration.get_color_scheme()
      %{bg: :black, fg: :white}  # Returns high contrast colors when enabled
  """
  @spec get_color_scheme() :: map()
  def get_color_scheme do
    mode = get_accessibility_mode()

    case mode do
      :high_contrast ->
        %{
          bg: :black,
          fg: :white,
          accent: :yellow,
          error: :red,
          success: :green,
          warning: :yellow
        }

      :standard ->
        %{
          bg: {:rgb, 30, 30, 30},
          fg: {:rgb, 220, 220, 220},
          accent: :blue,
          error: :red,
          success: :green,
          warning: :yellow
        }
    end
  end

  @doc """
  Get the current text scale based on accessibility settings.

  ## Examples

      iex> ThemeIntegration.get_text_scale()
      1.5  # Returns scale factor for large text mode
  """
  @spec get_text_scale() :: float()
  def get_text_scale do
    large_text = UserPreferences.get(pref_key(:large_text)) || false

    get_text_scale_factor(large_text)
  end

  defp handle_test_cleanup(false), do: :ok

  defp handle_test_cleanup(true) do
    # Only try to reset if the process exists
    case Process.whereis(UserPreferences) do
      nil -> :ok
      _pid -> UserPreferences.reset_to_defaults_for_test!()
    end
  end

  defp determine_accessibility_mode(true), do: :high_contrast
  defp determine_accessibility_mode(false), do: :standard

  defp apply_theme_adjustments(true, theme, _mode) do
    Theme.adjust_for_high_contrast(theme)
  end

  defp apply_theme_adjustments(false, theme, _mode), do: theme

  defp get_text_scale_factor(true), do: 1.5
  defp get_text_scale_factor(false), do: 1.0
end
