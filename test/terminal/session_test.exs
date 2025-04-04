defmodule Raxol.Terminal.SessionTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Session
  alias Raxol.Terminal.{Emulator, Input, Renderer}

  setup do
    # Start the session manager
    start_supervised!(Session)
    :ok
  end

  describe "create_session/2" do
    test "creates a new session with default options" do
      user_id = "user123"
      assert {:ok, session} = Session.create_session(user_id)
      
      assert session.id
      assert session.user_id == user_id
      assert %Emulator{} = session.emulator
      assert %Input{} = session.input
      assert %Renderer{} = session.renderer
      assert session.created_at
      assert session.updated_at
      assert session.metadata == %{}
    end

    test "creates a new session with custom options" do
      user_id = "user123"
      opts = [
        width: 40,
        height: 12,
        metadata: %{name: "Test Session"}
      ]
      
      assert {:ok, session} = Session.create_session(user_id, opts)
      
      assert session.id
      assert session.user_id == user_id
      assert session.emulator.width == 40
      assert session.emulator.height == 12
      assert session.metadata == %{name: "Test Session"}
    end
  end

  describe "get_session/1" do
    test "retrieves an existing session" do
      user_id = "user123"
      {:ok, created_session} = Session.create_session(user_id)
      
      assert {:ok, session} = Session.get_session(created_session.id)
      assert session.id == created_session.id
      assert session.user_id == user_id
    end

    test "returns error for non-existent session" do
      assert {:error, :not_found} = Session.get_session("nonexistent")
    end

    test "updates the last accessed time when retrieving a session" do
      user_id = "user123"
      {:ok, created_session} = Session.create_session(user_id)
      
      # Wait a moment to ensure timestamps are different
      Process.sleep(10)
      
      assert {:ok, session} = Session.get_session(created_session.id)
      assert DateTime.compare(session.updated_at, created_session.updated_at) == :gt
    end
  end

  describe "update_session/2" do
    test "updates an existing session" do
      user_id = "user123"
      {:ok, created_session} = Session.create_session(user_id)
      
      # Modify the session state
      emulator = Emulator.write(created_session.emulator, "Hello")
      input = Input.new()
      renderer = Renderer.new(emulator: emulator)
      
      new_state = %{
        emulator: emulator,
        input: input,
        renderer: renderer
      }
      
      assert {:ok, updated_session} = Session.update_session(created_session.id, new_state)
      assert updated_session.id == created_session.id
      assert updated_session.emulator == emulator
      assert updated_session.input == input
      assert updated_session.renderer == renderer
      assert DateTime.compare(updated_session.updated_at, created_session.updated_at) == :gt
    end

    test "returns error for non-existent session" do
      new_state = %{
        emulator: Emulator.new(80, 24),
        input: Input.new(),
        renderer: Renderer.new()
      }
      
      assert {:error, :not_found} = Session.update_session("nonexistent", new_state)
    end
  end

  describe "delete_session/1" do
    test "deletes an existing session" do
      user_id = "user123"
      {:ok, session} = Session.create_session(user_id)
      
      assert :ok = Session.delete_session(session.id)
      assert {:error, :not_found} = Session.get_session(session.id)
    end

    test "succeeds when deleting a non-existent session" do
      assert :ok = Session.delete_session("nonexistent")
    end
  end

  describe "list_sessions/1" do
    test "lists all sessions for a user" do
      user_id = "user123"
      {:ok, session1} = Session.create_session(user_id)
      {:ok, session2} = Session.create_session(user_id)
      {:ok, _other_session} = Session.create_session("other_user")
      
      sessions = Session.list_sessions(user_id)
      assert length(sessions) == 2
      assert Enum.any?(sessions, fn {_, s} -> s.id == session1.id end)
      assert Enum.any?(sessions, fn {_, s} -> s.id == session2.id end)
    end

    test "returns empty list for user with no sessions" do
      assert [] = Session.list_sessions("nonexistent_user")
    end
  end

  describe "cleanup_old_sessions/1" do
    test "cleans up sessions older than the specified age" do
      user_id = "user123"
      {:ok, session} = Session.create_session(user_id)
      
      # Manually set the updated_at time to be older than the max age
      old_time = DateTime.add(DateTime.utc_now(), -25 * 60 * 60, :second)
      :ets.insert(:terminal_sessions, {session.id, %{session | updated_at: old_time}})
      
      assert count = Session.cleanup_old_sessions(24 * 60 * 60)
      assert count > 0
      assert {:error, :not_found} = Session.get_session(session.id)
    end

    test "does not clean up sessions newer than the specified age" do
      user_id = "user123"
      {:ok, session} = Session.create_session(user_id)
      
      assert count = Session.cleanup_old_sessions(1 * 60 * 60) # 1 hour
      assert count == 0
      assert {:ok, _} = Session.get_session(session.id)
    end
  end
end 