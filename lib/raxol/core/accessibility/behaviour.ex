defmodule Raxol.Core.Accessibility.Behaviour do
  @moduledoc """
  Behaviour for accessibility implementations.
  """

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
  @callback get_component_hint(component_id :: atom, hint_level :: :basic | :detailed) :: String.t() | nil
end
