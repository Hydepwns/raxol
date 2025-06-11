defmodule Raxol.Core.Accessibility.Mock do
  @moduledoc """
  Mock implementation for Raxol.Core.Accessibility.
  """
  @behaviour Raxol.Core.Accessibility

  @impl true
  def announce(_message, _opts \\ [], _user_preferences_pid_or_name \\ nil),
    do: :ok
end
