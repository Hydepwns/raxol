defmodule Raxol.Core.Accessibility.EventHandlers do
  @moduledoc """
  Handles accessibility-related events and notifications.
  """

  alias Raxol.Core.Accessibility.{Announcements, Metadata, Preferences}
  require Raxol.Core.Runtime.Log

  @doc """
  Handle focus change events for accessibility announcements.

  ## Examples

      iex> EventHandlers.handle_focus_change({:focus_change, nil, "search_button"})
      :ok
  """
  def handle_focus_change(
        {:focus_change, _old_element, new_element},
        user_preferences_pid_or_name
      ) do
    Raxol.Core.Runtime.Log.debug(
      "EventHandlers.handle_focus_change called with: #{inspect(new_element)}, prefs: #{inspect(user_preferences_pid_or_name)}"
    )

    if Preferences.get_option(:screen_reader, user_preferences_pid_or_name) do
      # Get accessible name/label for the element if metadata exists
      announcement = Metadata.get_accessible_name(new_element)

      Raxol.Core.Runtime.Log.debug("Got announcement: #{inspect(announcement)}")

      if announcement do
        Announcements.announce(announcement, [], user_preferences_pid_or_name)

        Raxol.Core.Runtime.Log.debug(
          "Announcement made: #{inspect(announcement)}"
        )
      end

      Raxol.Core.Runtime.Log.debug("Focus changed to: #{inspect(new_element)}")
    else
      Raxol.Core.Runtime.Log.debug(
        "Screen reader disabled for: #{inspect(user_preferences_pid_or_name)}"
      )
    end

    :ok
  end

  def handle_focus_change(_event),
    do:
      raise(
        "handle_focus_change/2 must be called with a user_preferences_pid_or_name."
      )

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
    Raxol.Core.Runtime.Log.debug("Locale changed event received.")
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
        user_preferences_pid_or_name
      ) do
    Raxol.Core.Runtime.Log.info(
      "[Test Log - Accessibility] handle_theme_changed triggered for theme: #{inspect(theme_name)}"
    )

    announce_message = "Theme changed to #{theme_name}"
    Announcements.announce(announce_message, [], user_preferences_pid_or_name)
    :ok
  end

  def handle_theme_changed(_, _), do: :ok

  # Add String.Chars protocol implementation for Theme
  if Code.ensure_loaded?(Raxol.UI.Theming.Theme) do
    defimpl String.Chars, for: Raxol.UI.Theming.Theme do
      def to_string(theme) do
        "Theme: #{theme.name}"
      end
    end
  end
end
