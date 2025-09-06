defmodule Raxol.Terminal.Multiplexing.SessionManager.Helpers do
  @moduledoc """
  Helper functions for SessionManager that were separated during refactoring.
  """

  require Logger

  def start_cleanup_timer(interval_minutes) do
    :timer.send_interval(interval_minutes * 60 * 1000, :cleanup_sessions)
  end
end
