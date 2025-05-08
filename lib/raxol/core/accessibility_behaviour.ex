defmodule Raxol.Core.Accessibility.Behaviour do
  @moduledoc """
  Defines the behaviour for accessibility services.
  This behaviour outlines the contract for modules that provide accessibility
  functionality such as screen reader announcements, feature toggles (high contrast,
  reduced motion, large text), and preference management related to accessibility.
  """

  @doc """
  Enables accessibility features with the given options.
  """
  @callback enable(
              options :: list(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: :ok

  @doc """
  Disables accessibility features.
  """
  @callback disable() :: :ok

  @doc """
  Makes an announcement for screen readers.
  """
  @callback announce(
              message :: String.t(),
              opts :: list(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: :ok

  @doc """
  Gets the next announcement to be read by screen readers.
  """
  @callback get_next_announcement() :: String.t() | nil

  @doc """
  Clears all pending announcements.
  """
  @callback clear_announcements() :: :ok

  @doc """
  Enables or disables high contrast mode.
  """
  @callback set_high_contrast(
              enabled :: boolean(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: :ok

  @doc """
  Enables or disables reduced motion.
  """
  @callback set_reduced_motion(
              enabled :: boolean(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: :ok

  @doc """
  Enables or disables large text mode.
  """
  @callback set_large_text(
              enabled :: boolean(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: :ok

  @doc """
  Gets the current text scale factor based on the large text setting.
  """
  @callback get_text_scale(user_preferences_pid_or_name :: atom() | pid() | nil) ::
              float()

  @doc """
  Gets the current color scheme based on accessibility settings.
  """
  @callback get_color_scheme() :: map()

  @doc """
  Registers metadata for an element to be used for accessibility features.
  """
  @callback register_element_metadata(
              element_id :: String.t(),
              metadata :: map()
            ) :: :ok

  @doc """
  Gets metadata for an element.
  """
  @callback get_element_metadata(element_id :: String.t()) :: map() | nil

  @doc """
  Registers style settings for a component type.
  """
  @callback register_component_style(component_type :: atom(), style :: map()) ::
              :ok

  @doc """
  Gets style settings for a component type.
  """
  @callback get_component_style(component_type :: atom()) :: map()

  @doc """
  Handles focus change events for accessibility announcements.
  """
  @callback handle_focus_change(event_payload :: tuple()) :: :ok

  @doc """
  Checks if high contrast mode is enabled.
  """
  @callback high_contrast_enabled?(
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: boolean()

  @doc """
  Checks if reduced motion mode is enabled.
  """
  @callback reduced_motion_enabled?(
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: boolean()

  @doc """
  Checks if large text mode is enabled.
  """
  @callback large_text_enabled?(
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: boolean()

  @doc """
  Gets an accessibility option value.
  """
  @callback get_option(
              key :: atom(),
              user_preferences_pid_or_name :: atom() | pid() | nil,
              default :: any()
            ) :: any()

  @doc """
  Sets an accessibility option value.
  """
  @callback set_option(
              key :: atom(),
              value :: any(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: :ok
end
