defmodule Raxol.Core.Accessibility.Legacy do
  @moduledoc """
  Legacy functions for backwards compatibility.
  These functions are deprecated and will be removed in a future version.
  """

  alias Raxol.Core.Accessibility.Preferences

  @doc """
  Check if high contrast mode is enabled.

  ## Returns

  * `true` if high contrast mode is enabled, `false` otherwise.

  ## Examples

      iex> Legacy.high_contrast_enabled?()
      false
  """
  def high_contrast_enabled?(user_preferences_pid_or_name \\ nil) do
    Preferences.get_option(:high_contrast, user_preferences_pid_or_name, false)
  end

  @doc """
  Check if reduced motion mode is enabled.

  ## Returns

  * `true` if reduced motion mode is enabled, `false` otherwise.

  ## Examples

      iex> Legacy.reduced_motion_enabled?()
      false
  """
  def reduced_motion_enabled?(user_preferences_pid_or_name \\ nil) do
    Preferences.get_option(:reduced_motion, user_preferences_pid_or_name, false)
  end

  @doc """
  Check if large text mode is enabled.

  ## Returns

  * `true` if large text mode is enabled, `false` otherwise.

  ## Examples

      iex> Legacy.large_text_enabled?()
      false
  """
  def large_text_enabled?(user_preferences_pid_or_name \\ nil) do
    Preferences.get_option(:large_text, user_preferences_pid_or_name, false)
  end
end
