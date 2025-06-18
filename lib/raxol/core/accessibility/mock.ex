defmodule Raxol.Core.Accessibility.Mock do
  @moduledoc '''
  Mock implementation of the accessibility module for testing.
  '''

  @behaviour Raxol.Core.Accessibility.Behaviour

  def announce(_message, _opts \\ [], _user_preferences_pid_or_name \\ nil) do
    :ok
  end

  @impl true
  def set_large_text(_enabled, _user_preferences_pid_or_name) do
    :ok
  end

  @impl true
  def get_focus_history do
    []
  end
end
