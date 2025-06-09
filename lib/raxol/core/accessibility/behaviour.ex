defmodule Raxol.Core.Accessibility.Behaviour do
  @callback set_large_text(
              enabled :: boolean(),
              user_preferences_pid_or_name :: atom() | pid() | nil
            ) ::
              :ok

  @callback get_focus_history() :: list(String.t() | nil)
end
