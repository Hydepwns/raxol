defmodule Raxol.Core.Accessibility.EventHandlers do
  @moduledoc """
  Handles accessibility-related events and notifications.
  """

  alias Raxol.Core.Accessibility.{Announcements, Metadata, Preferences}
  require Logger

  @doc """
  Handle focus change events for accessibility announcements.

  ## Examples

      iex> EventHandlers.handle_focus_change({:focus_change, nil, "search_button"})
      :ok
  """
  def handle_focus_change({:focus_change, _old_element, new_element}) do
    if Preferences.get_option(:screen_reader) do
      # Get accessible name/label for the element if metadata exists
      announcement = Metadata.get_accessible_name(new_element)

      if announcement do
        Announcements.announce(announcement)
      end

      Logger.debug("Focus changed to: #{inspect(new_element)}")
    end

    :ok
  end

  @doc """
  Handle preference changes triggered internally or via EventManager.

  ## Examples

      iex> EventHandlers.handle_preference_changed({:preference_changed, [:accessibility, :high_contrast], true})
      :ok
  """
  def handle_preference_changed(event, user_preferences_pid_or_name \\ nil) do
    Preferences.handle_preference_changed(event, user_preferences_pid_or_name)
  end

  @doc """
  Handle locale changes.

  ## Examples

      iex> EventHandlers.handle_locale_changed({:locale_changed, %{locale: "en"}})
      :ok
  """
  def handle_locale_changed({:locale_changed, _locale_info}) do
    Logger.debug("Locale changed event received.")
    :ok
  end

  @doc """
  Handle theme changes.

  ## Examples

      iex> EventHandlers.handle_theme_changed({:theme_changed, %{theme: "dark"}})
      :ok
  """
  def handle_theme_changed(
        {:theme_changed, %{theme: theme_name}},
        _pid_or_name \\ nil
      ) do
    Logger.info(
      "[Test Log - Accessibility] handle_theme_changed triggered for theme: #{inspect(theme_name)}"
    )

    announce_message = "Theme changed to #{theme_name}"
    Announcements.announce(announce_message)
    :ok
  end
end
