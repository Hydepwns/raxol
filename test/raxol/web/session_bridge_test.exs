defmodule Raxol.Web.SessionBridgeTest do
  use ExUnit.Case, async: false

  alias Raxol.Web.SessionBridge

  setup do
    # Start the SessionBridge GenServer for each test
    case GenServer.whereis(SessionBridge) do
      nil ->
        {:ok, _pid} = SessionBridge.start_link([])

      pid ->
        # Clear any existing state
        :sys.replace_state(pid, fn _state ->
          %{transitions: %{}, sessions: %{}}
        end)
    end

    :ok
  end

  describe "create_transition/2" do
    test "creates a transition token" do
      state = %{cursor: {0, 0}, buffer: "test"}

      {:ok, token} = SessionBridge.create_transition("session1", state)

      assert is_binary(token)
      assert byte_size(token) > 0
    end

    test "creates unique tokens for different transitions" do
      state = %{data: "test"}

      {:ok, token1} = SessionBridge.create_transition("session1", state)
      {:ok, token2} = SessionBridge.create_transition("session1", state)

      assert token1 != token2
    end
  end

  describe "resume_session/1" do
    test "resumes session with valid token" do
      state = %{cursor: {5, 10}, buffer: "hello"}

      {:ok, token} = SessionBridge.create_transition("session1", state)
      {:ok, restored} = SessionBridge.resume_session(token)

      assert restored.cursor == {5, 10}
      assert restored.buffer == "hello"
    end

    test "returns error for invalid token" do
      assert {:error, :invalid_token} = SessionBridge.resume_session("invalid_token")
    end

    test "token can only be used once" do
      state = %{data: "test"}

      {:ok, token} = SessionBridge.create_transition("session1", state)
      {:ok, _restored} = SessionBridge.resume_session(token)

      # Second use should fail
      assert {:error, :invalid_token} = SessionBridge.resume_session(token)
    end
  end

  describe "capture_state/1" do
    test "captures and returns nil for unknown session" do
      result = SessionBridge.capture_state("unknown_session")

      assert result == nil
    end

    test "captures state after restore" do
      state = %{cursor: {1, 2}, data: "test"}

      SessionBridge.restore_state("session1", state)
      captured = SessionBridge.capture_state("session1")

      assert captured.cursor == {1, 2}
      assert captured.data == "test"
    end
  end

  describe "restore_state/2" do
    test "stores state for session" do
      state = %{width: 80, height: 24}

      :ok = SessionBridge.restore_state("session1", state)
      captured = SessionBridge.capture_state("session1")

      assert captured == state
    end

    test "overwrites existing state" do
      SessionBridge.restore_state("session1", %{version: 1})
      SessionBridge.restore_state("session1", %{version: 2})

      captured = SessionBridge.capture_state("session1")

      assert captured.version == 2
    end
  end

  describe "serialize_terminal_state/1" do
    test "serializes emulator state to binary" do
      # Mock emulator state
      emulator = %{
        width: 80,
        height: 24,
        cursor: {0, 0},
        buffer: []
      }

      binary = SessionBridge.serialize_terminal_state(emulator)

      assert is_binary(binary)
    end
  end

  describe "deserialize_terminal_state/1" do
    test "deserializes binary back to state" do
      original = %{
        width: 80,
        height: 24,
        cursor: {5, 10}
      }

      binary = SessionBridge.serialize_terminal_state(original)
      {:ok, restored} = SessionBridge.deserialize_terminal_state(binary)

      assert restored.width == 80
      assert restored.height == 24
      assert restored.cursor == {5, 10}
    end

    test "returns error for invalid binary" do
      assert {:error, _} = SessionBridge.deserialize_terminal_state("not valid binary")
    end
  end

  describe "cleanup_expired/0" do
    test "returns count of cleaned entries" do
      # Store some data
      SessionBridge.restore_state("session1", %{data: "test"})

      {:ok, count} = SessionBridge.cleanup_expired()

      assert is_integer(count)
      assert count >= 0
    end
  end

  describe "list_sessions/0" do
    test "returns empty list when no sessions" do
      assert SessionBridge.list_sessions() == []
    end

    test "returns all session IDs" do
      SessionBridge.restore_state("session1", %{data: "test1"})
      SessionBridge.restore_state("session2", %{data: "test2"})
      SessionBridge.restore_state("session3", %{data: "test3"})

      sessions = SessionBridge.list_sessions()

      assert "session1" in sessions
      assert "session2" in sessions
      assert "session3" in sessions
    end
  end

  describe "delete_session/1" do
    test "removes session and its state" do
      SessionBridge.restore_state("session1", %{data: "test"})

      assert SessionBridge.capture_state("session1") != nil

      :ok = SessionBridge.delete_session("session1")

      assert SessionBridge.capture_state("session1") == nil
    end

    test "removes associated transition tokens" do
      state = %{data: "test"}
      {:ok, token} = SessionBridge.create_transition("session1", state)

      :ok = SessionBridge.delete_session("session1")

      # Token should be invalid after session deletion
      assert {:error, :invalid_token} = SessionBridge.resume_session(token)
    end

    test "returns ok for non-existent session" do
      assert :ok = SessionBridge.delete_session("nonexistent")
    end
  end
end
