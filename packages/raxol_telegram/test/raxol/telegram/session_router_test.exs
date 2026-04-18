defmodule Raxol.Telegram.SessionRouterTest do
  use ExUnit.Case

  alias Raxol.Telegram.SessionRouter

  # SessionRouter requires a running GenServer. These tests verify
  # the public API works correctly with a mock app module.

  setup do
    # Start a fresh SessionRouter for each test
    start_supervised!({SessionRouter, app_module: FakeApp})
    :ok
  end

  describe "session_count/0" do
    test "starts with zero sessions" do
      assert SessionRouter.session_count() == 0
    end
  end

  describe "get_session/1" do
    test "returns nil for unknown chat_id" do
      assert SessionRouter.get_session(999) == nil
    end
  end

  describe "stop_session/1" do
    test "stopping non-existent session is a no-op" do
      assert SessionRouter.stop_session(999) == :ok
    end
  end
end

defmodule FakeApp do
  @moduledoc false
  # Minimal module to satisfy app_module requirement
end
