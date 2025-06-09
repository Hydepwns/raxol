defmodule Raxol.Core.KeyboardShortcutsBehaviour do
  @moduledoc """
  Behaviour for the KeyboardShortcuts module.
  This allows for mocking the KeyboardShortcuts module in tests.
  """

  @type shortcut :: String.t()
  @type shortcut_name :: atom() | String.t()
  @type shortcut_callback :: function()
  @type shortcut_opts :: keyword()
  @type shortcut_context :: atom() | nil

  @callback init() :: :ok
  @callback cleanup() :: :ok
  @callback register_shortcut(
              shortcut :: shortcut(),
              name :: shortcut_name(),
              callback :: shortcut_callback(),
              opts :: shortcut_opts()
            ) :: :ok

  @callback unregister_shortcut(
              name :: shortcut_name(),
              context :: shortcut_context()
            ) :: :ok
  @callback set_context(context :: shortcut_context()) :: :ok
  @callback get_current_context() :: shortcut_context()

  @callback get_shortcuts_for_context(context :: shortcut_context()) ::
              list(map())

  # show_shortcuts_help/0 in KeyboardShortcuts returns {:ok, String.t()}
  @callback show_shortcuts_help(
              user_preferences_pid_or_name :: pid() | atom() | nil
            ) :: {:ok, String.t()} | :ok

  @callback trigger_shortcut(
              name :: shortcut_name(),
              context :: shortcut_context()
            ) ::
              :ok | {:error, :shortcut_not_found}

  # Based on KeyboardShortcuts.handle_keyboard_event/1
  @callback handle_keyboard_event(event :: tuple()) :: :ok
end
