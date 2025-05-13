defmodule Raxol.Terminal.SessionTest do
  use ExUnit.Case, async: true
  use Raxol.DataCase
  import Raxol.TestHelpers

  # TODO: Revise tests for GenServer-based session or skip entirely.
  # Current tests expect a different session management API.

  alias Raxol.Terminal.Session
  alias Raxol.Terminal.{Emulator, Input, Renderer}

  setup do
    # Start the session manager
    start_supervised!(Session)
    :ok
  end

  # describe "create_session/2" do
  #   @describetag :skip
  #
  #   test "creates a new session with default options" do
  #     user_id = "user123"
  #     assert {:ok, session} = Session.create_session(user_id)
  #
  #     assert session.id
  #     assert session.user_id == user_id
  #     assert %Emulator{} = session.emulator
  #     assert %Input{} = session.input
  #     assert %Renderer{} = session.renderer
  #     assert session.created_at
  #     assert session.updated_at
  #     assert session.metadata == %{}
  #   end
  #
  #   test "creates a new session with custom options" do
  #     user_id = "user123"
  #
  #     opts = [
  #       width: 40,
  #       height: 12,
  #       metadata: %{name: "Test Session"}
  #     ]
  #
  #     assert {:ok, session} = Session.create_session(user_id, opts)
  #
  #     assert session.id
  #     assert session.user_id == user_id
  #     assert session.emulator.width == 40
  #     assert session.emulator.height == 12
  #     assert session.metadata == %{name: "Test Session"}
  #   end
  # end
  #
  # describe "get_session/1" do
  #   test "retrieves an existing session" do
  #     user_id = "user123"
  #     {:ok, created_session} = Session.create_session(user_id)
  #
  #     assert {:ok, session} = Session.get_session(created_session.id)
  #     assert session.id == created_session.id
  #     assert session.user_id == user_id
  #   end
  #
  #   test "returns error for non-existent session" do
  #     assert {:error, :not_found} = Session.get_session("nonexistent")
  #   end
  #
  #   test "updates the last accessed time when retrieving a session" do
  #     user_id = "user123"
  #     {:ok, created_session} = Session.create_session(user_id)
  #
  #     # Wait a moment to ensure timestamps are different
  #     Process.sleep(10)
  #
  #     assert {:ok, session} = Session.get_session(created_session.id)
  #
  #     assert DateTime.compare(session.updated_at, created_session.updated_at) ==
  #              :gt
  #   end
  # end
  #
  # describe "update_session/2" do
  #   test "updates an existing session" do
  #     user_id = "user123"
  #     {:ok, created_session} = Session.create_session(user_id)
  #
  #     # Modify the session state
  #     emulator = Emulator.write(created_session.emulator, "Hello")
  #     input = Input.new()
  #     renderer = Renderer.new(emulator: emulator)
  #
  #     new_state = %{
  #       emulator: emulator,
  #       input: input,
  #       renderer: renderer
  #     }
  #
  #     assert {:ok, updated_session} =
  #              Session.update_session(created_session.id, new_state)
  #
  #     assert updated_session.id == created_session.id
  #     assert updated_session.emulator == emulator
  #     assert updated_session.input == input
  #     assert updated_session.renderer == renderer
  #
  #     assert DateTime.compare(
  #              updated_session.updated_at,
  #              created_session.updated_at
  #            ) == :gt
  #   end
  #
  #   test "returns error for non-existent session" do
  #     new_state = %{
  #       emulator: Emulator.new(80, 24),
  #       input: Input.new(),
  #       renderer: Renderer.new()
  #     }
  #
  #     assert {:error, :not_found} =
  #              Session.update_session("nonexistent", new_state)
  #   end
  # end
  #
  # describe "delete_session/1" do
  #   test "deletes an existing session" do
  #     user_id = "user123"
  #     {:ok, session} = Session.create_session(user_id)
  #
  #     assert :ok = Session.delete_session(session.id)
  #     assert {:error, :not_found} = Session.get_session(session.id)
  #   end
  #
  #   test "succeeds when deleting a non-existent session" do
  #     assert :ok = Session.delete_session("nonexistent")
  #   end
  # end
  #
  # describe "list_sessions/1" do
  #   test "lists all sessions for a user" do
  #     user_id = "user123"
  #     {:ok, session1} = Session.create_session(user_id)
  #     {:ok, session2} = Session.create_session(user_id)
  #     {:ok, _other_session} = Session.create_session("other_user")
  #
  #     sessions = Session.list_sessions(user_id)
  #     assert length(sessions) == 2
  #     assert Enum.any?(sessions, fn {_, s} -> s.id == session1.id end)
  #     assert Enum.any?(sessions, fn {_, s} -> s.id == session2.id end)
  #   end
  #
  #   test "returns empty list for user with no sessions" do
  #     assert [] = Session.list_sessions("nonexistent_user")
  #   end
  # end
  #
  # describe "cleanup_old_sessions/1" do
  #   test "cleans up sessions older than the specified age" do
  #     user_id = "user123"
  #     {:ok, session} = Session.create_session(user_id)
  #
  #     # Manually set the updated_at time to be older than the max age
  #     old_time = DateTime.add(DateTime.utc_now(), -25 * 60 * 60, :second)
  #
  #     :ets.insert(
  #       :terminal_sessions,
  #       {session.id, %{session | updated_at: old_time}}
  #     )
  #
  #     assert count = Session.cleanup_old_sessions(24 * 60 * 60)
  #     assert count > 0
  #     assert {:error, :not_found} = Session.get_session(session.id)
  #   end
  #
  #   test "does not clean up sessions newer than the specified age" do
  #     user_id = "user123"
  #     {:ok, session} = Session.create_session(user_id)
  #
  #     # 1 hour
  #     assert count = Session.cleanup_old_sessions(1 * 60 * 60)
  #     assert count == 0
  #     assert {:ok, _} = Session.get_session(session.id)
  #   end
  # end

  # Helper: Poll until a condition is met or timeout (default 100ms)
  defp eventually(assertion_fun, timeout_ms \\ 100) do
    wait_for_state(assertion_fun, timeout_ms)
  end

  describe "Session GenServer API" do
    test "start_link/1 starts a session and process is alive" do
      {:ok, pid} =
        Session.start_link(width: 100, height: 40, title: "Test Terminal")

      assert Process.alive?(pid)
      on_exit(fn -> cleanup_process(pid) end)
    end

    test "get_state/1 returns the correct initial state" do
      {:ok, pid} =
        Session.start_link(width: 90, height: 30, title: "Test Terminal")

      on_exit(fn -> cleanup_process(pid) end)

      state = Session.get_state(pid)
      assert state.width == 90
      assert state.height == 30
      assert state.title == "Test Terminal"
      assert %Emulator{} = state.emulator
      assert %Input{} = state.input
      assert %Renderer{} = state.renderer
    end

    test "update_state/2 updates the session state" do
      {:ok, pid} =
        Session.start_link(width: 80, height: 24, title: "Test Terminal")

      on_exit(fn -> cleanup_process(pid) end)

      # Get initial state
      initial_state = Session.get_state(pid)
      assert initial_state.width == 80
      assert initial_state.height == 24

      # Update state
      new_state = %{width: 100, height: 40}
      assert :ok = Session.update_state(pid, new_state)

      # Verify state was updated
      updated_state = Session.get_state(pid)
      assert updated_state.width == 100
      assert updated_state.height == 40
      # Unchanged
      assert updated_state.title == "Test Terminal"
    end

    test "update_state/2 preserves existing state for unspecified fields" do
      {:ok, pid} =
        Session.start_link(width: 80, height: 24, title: "Test Terminal")

      on_exit(fn -> cleanup_process(pid) end)

      # Update only width
      assert :ok = Session.update_state(pid, %{width: 100})

      # Verify only width was updated
      state = Session.get_state(pid)
      assert state.width == 100
      assert state.height == 24
      assert state.title == "Test Terminal"
    end

    test "update_state/2 handles invalid state updates" do
      {:ok, pid} =
        Session.start_link(width: 80, height: 24, title: "Test Terminal")

      on_exit(fn -> cleanup_process(pid) end)

      # Try to update with invalid width
      assert {:error, :invalid_state} = Session.update_state(pid, %{width: -1})

      # Verify state was not updated
      state = Session.get_state(pid)
      assert state.width == 80
      assert state.height == 24
    end

    test "update_state/2 handles concurrent updates" do
      {:ok, pid} =
        Session.start_link(width: 80, height: 24, title: "Test Terminal")

      on_exit(fn -> cleanup_process(pid) end)

      # Create multiple update tasks
      tasks = [
        Task.async(fn -> Session.update_state(pid, %{width: 100}) end),
        Task.async(fn -> Session.update_state(pid, %{height: 40}) end),
        Task.async(fn -> Session.update_state(pid, %{title: "Updated"}) end)
      ]

      # Wait for all updates to complete
      results = Task.await_many(tasks, 1000)
      assert Enum.all?(results, &(&1 == :ok))

      # Verify final state
      state = Session.get_state(pid)
      assert state.width == 100
      assert state.height == 40
      assert state.title == "Updated"
    end

    test "update_state/2 handles process termination" do
      {:ok, pid} =
        Session.start_link(width: 80, height: 24, title: "Test Terminal")

      # Terminate the process
      Process.exit(pid, :normal)

      # Wait for process to terminate
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000

      # Verify update fails
      assert {:error, :noproc} = Session.update_state(pid, %{width: 100})
    end

    test "get_state/1 handles process termination" do
      {:ok, pid} =
        Session.start_link(width: 80, height: 24, title: "Test Terminal")

      # Terminate the process
      Process.exit(pid, :normal)

      # Wait for process to terminate
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000

      # Verify get_state fails
      assert {:error, :noproc} = Session.get_state(pid)
    end
  end
end
