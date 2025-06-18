defmodule Raxol.Test.EventAssertions do
  @moduledoc '''
  Event-based assertion helpers for ExUnit tests.
  Provides wrappers for assert_receive and refute_receive for event-driven code.
  '''

  import ExUnit.Assertions

  @doc '''
  Asserts that a message matching the given pattern is received within the timeout.
  '''
  defmacro assert_event_received(pattern, timeout \\ 1000) do
    quote do
      assert_receive unquote(pattern), unquote(timeout)
    end
  end

  @doc '''
  Refutes that a message matching the given pattern is received within the timeout.
  '''
  defmacro refute_event_received(pattern, timeout \\ 1000) do
    quote do
      refute_receive unquote(pattern), unquote(timeout)
    end
  end
end
