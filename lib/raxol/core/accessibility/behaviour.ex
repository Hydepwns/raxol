defmodule Raxol.Core.Accessibility.Behaviour do
  @moduledoc """
  Behaviour for accessibility implementations.
  """

  @callback enable(
              options :: keyword() | map(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: :ok

  @callback disable(user_preferences_pid_or_name :: atom() | pid() | nil) :: :ok

  @callback set_large_text(
              enabled :: boolean(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) ::
              :ok

  @callback get_focus_history() :: list(String.t() | nil)

  @callback enabled?() :: boolean
  @callback announce(message :: String.t(), level :: :verbose | :normal) :: :ok
  @callback get_option(key :: atom, default :: any) :: any
  @callback set_option(key :: atom, value :: any) :: :ok
  @callback get_component_hint(
              component_id :: atom,
              hint_level :: :basic | :detailed
            ) :: String.t() | nil

  @callback register_element_metadata(
              element_id :: String.t(),
              metadata :: map()
            ) :: :ok

  @callback get_element_metadata(element_id :: String.t()) :: map() | nil

  @callback register_component_style(
              component_type :: atom(),
              style :: map()
            ) :: :ok

  @callback get_component_style(component_type :: atom()) :: map()

  @callback unregister_element_metadata(element_id :: String.t()) :: :ok

  @callback unregister_component_style(component_type :: atom()) :: :ok

  @callback announce(
              message :: String.t(),
              opts :: keyword(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: :ok

  @callback get_next_announcement(
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) :: String.t() | nil

  @callback clear_announcements() :: :ok
end
