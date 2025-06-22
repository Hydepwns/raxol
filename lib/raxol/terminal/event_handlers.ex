defmodule EventHandlers do
  def handle_focus_change(_a, _b), do: :ok
  def handle_locale_changed(_a), do: :ok
  def handle_preference_changed(_a, _b), do: :ok
end
