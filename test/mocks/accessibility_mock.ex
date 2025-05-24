defmodule Raxol.Mocks.AccessibilityMock do
  @moduledoc """
  Mox mock for Raxol.Core.Accessibility.
  """
  def announce(_message, _opts \\ [], _user_preferences_pid_or_name \\ nil), do: :ok
end
