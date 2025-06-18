defmodule Raxol.Terminal.SessionTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Session

  setup do
    # Start the application
    Application.start(:raxol)

    # Clean up any existing session files
    File.rm_rf!("tmp/sessions")
    File.mkdir_p!("tmp/sessions")

    {:ok, pid} = Session.start_link(id: "test_session")
    %{pid: pid}
  end

  setup_all do
    # Ensure application is stopped after all tests
    on_exit(fn ->
      Application.stop(:raxol)
    end)
  end

  describe "session persistence" do
    test "can save and load a session", %{pid: pid} do
      # Save the session
      assert :ok = Session.save_session(pid)

      # Load the session
      assert {:ok, new_pid} = Session.load_session("test_session")
      assert Process.alive?(new_pid)

      # Verify the loaded session has the same properties
      original_state = Session.get_state(pid)
      loaded_state = Session.get_state(new_pid)

      assert loaded_state.id == original_state.id
      assert loaded_state.width == original_state.width
      assert loaded_state.height == original_state.height
      assert loaded_state.title == original_state.title
    end

    test 'can list saved sessions' do
      # Create and save multiple sessions
      {:ok, pid1} = Session.start_link(id: "session1")
      {:ok, pid2} = Session.start_link(id: "session2")

      Session.save_session(pid1)
      Session.save_session(pid2)

      # List sessions
      assert {:ok, sessions} = Session.list_saved_sessions()
      assert length(sessions) == 2
      assert "session1" in sessions
      assert "session2" in sessions
    end

    test "auto-save functionality", %{pid: pid} do
      # Enable auto-save
      assert :ok = Session.set_auto_save(pid, true)

      # Send some input to trigger auto-save
      Session.send_input(pid, "test input")

      # Wait for auto-save to complete
      Process.sleep(100)

      # Verify session was saved
      assert {:ok, sessions} = Session.list_saved_sessions()
      assert "test_session" in sessions
    end

    test "can disable auto-save", %{pid: pid} do
      # Disable auto-save
      assert :ok = Session.set_auto_save(pid, false)

      # Send input
      Session.send_input(pid, "test input")

      # Wait for potential auto-save
      Process.sleep(100)

      # Verify session was not saved
      assert {:ok, sessions} = Session.list_saved_sessions()
      assert "test_session" not in sessions
    end
  end

  describe "session recovery" do
    test "can recover from saved state", %{pid: pid} do
      # Save initial state
      Session.save_session(pid)

      # Modify state
      Session.send_input(pid, "test input")
      Session.update_config(pid, %{width: 100, height: 30})

      # Load original state
      assert {:ok, recovered_pid} = Session.load_session("test_session")
      recovered_state = Session.get_state(recovered_pid)

      # Verify recovered state matches original
      original_state = Session.get_state(pid)
      assert recovered_state.width == original_state.width
      assert recovered_state.height == original_state.height
    end

    test 'handles invalid session data gracefully' do
      # Try to load non-existent session
      assert {:error, _} = Session.load_session("nonexistent")
    end
  end
end
