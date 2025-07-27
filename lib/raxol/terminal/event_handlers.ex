defmodule EventHandlers do
  @moduledoc """
  Terminal event handlers for focus, locale, and preference changes.

  Provides stub implementations for terminal-level event handling.
  """
  def handle_focus_change(_a, _b), do: :ok
  def handle_locale_changed(_a), do: :ok
  def handle_preference_changed(_a, _b), do: :ok
end
