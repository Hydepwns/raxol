defmodule Raxol.Terminal.SessionTest do
  use ExUnit.Case, async: true
  use Raxol.DataCase
  # import Raxol.TestHelpers
  import Raxol.Test.TestHelper

  # TODO: Revise tests for GenServer-based session or skip entirely.
  # Current tests expect a different session management API.

  alias Raxol.Terminal.Session
  alias Raxol.Terminal.{Emulator, Input, Renderer}
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  setup do
    # Start the session manager
    start_supervised!(Session)
    :ok
  end

  # Helper: Poll until a condition is met or timeout (default 100ms)
  defp eventually(assertion_fun, timeout_ms \\ 100) do
    wait_for_state(assertion_fun, timeout_ms)
  end

  describe "Session GenServer API" do
    test 'start_link/1 starts a session and process is alive' do
      {:ok, pid} =
        Session.start_link(width: 100, height: 40, title: "Test Terminal")

      assert Process.alive?(pid)
      on_exit(fn -> cleanup_process(pid) end)
    end

    test 'get_state/1 returns the correct initial state' do
      {:ok, pid} =
        Session.start_link(width: 90, height: 30, title: "Test Terminal")

      on_exit(fn -> cleanup_process(pid) end)

      state = Session.get_state(pid)
      assert state.width == 90
      assert state.height == 30
      assert state.title == "Test Terminal"
      assert %EmulatorStruct{} = state.emulator
      assert %Input{} = state.input
      assert %Renderer{} = state.renderer
    end

    test 'update_state/2 updates the session state' do
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

    test 'update_state/2 preserves existing state for unspecified fields' do
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

    test 'update_state/2 handles invalid state updates' do
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

    test 'update_state/2 handles concurrent updates' do
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

    test 'update_state/2 handles process termination' do
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

    test 'get_state/1 handles process termination' do
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
