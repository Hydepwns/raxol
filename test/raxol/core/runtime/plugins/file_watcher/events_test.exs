defmodule Raxol.Core.Runtime.Plugins.FileWatcher.EventsTest do
  use ExUnit.Case
  import Mox
  alias Raxol.Core.Runtime.Plugins.FileWatcher.Events
  alias FileWatcherTestHelper, as: Helper
  import Raxol.Test.Mocks

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Setup default mocks and test environment
  setup do
    pid = Helper.setup_mocks()
    Helper.cleanup_test_plugins()

    on_exit(fn ->
      Helper.stop_manager(pid)
      Helper.cleanup_test_plugins()
    end)

    :ok
  end

  describe "handle_file_event/2" do
    test "ignores events for unknown files" do
      # Setup test state
      state = Helper.create_test_state()

      # Call the function
      {:ok, new_state} = Events.handle_file_event("unknown/path", state)

      # Verify state is unchanged
      assert new_state == state
    end

    test "handles file access errors" do
      # Setup test state
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")
      state = Helper.create_test_state()
      state = put_in(state.reverse_plugin_paths, %{plugin_path => plugin_id})

      # Mock File.stat to return error
      expect(FileMock, :stat, fn ^plugin_path ->
        {:error, :enoent}
      end)

      # Call the function
      {:error, {:file_access_error, :enoent}} =
        Events.handle_file_event(plugin_path, state)
    end

    test "ignores non-regular files" do
      # Setup test state
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")
      state = Helper.create_test_state()
      state = put_in(state.reverse_plugin_paths, %{plugin_path => plugin_id})

      # Mock File.stat to return directory
      expect(FileMock, :stat, fn ^plugin_path ->
        Helper.directory_stat()
      end)

      # Call the function
      {:ok, new_state} = Events.handle_file_event(plugin_path, state)

      # Verify state is unchanged
      assert new_state == state
    end

    test "schedules reload for valid plugin files" do
      # Setup test state
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")
      state = Helper.create_test_state()
      state = put_in(state.reverse_plugin_paths, %{plugin_path => plugin_id})

      # Mock File.stat to return valid file
      expect(FileMock, :stat, fn ^plugin_path ->
        Helper.valid_file_stat()
      end)

      # Call the function
      {:ok, new_state} = Events.handle_file_event(plugin_path, state)

      # Verify timer was scheduled
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "cancels existing timer when new event arrives" do
      # Setup test state with existing timer
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")
      existing_timer = Process.send_after(self(), :test, 1_000_000)
      state = Helper.create_test_state()
      state = put_in(state.reverse_plugin_paths, %{plugin_path => plugin_id})
      state = put_in(state.file_event_timer, existing_timer)

      # Mock File.stat to return valid file
      expect(FileMock, :stat, fn ^plugin_path ->
        Helper.valid_file_stat()
      end)

      # Call the function
      {:ok, new_state} = Events.handle_file_event(plugin_path, state)

      # Verify old timer was cancelled and new one scheduled
      refute Process.cancel_timer(existing_timer)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "normalizes paths before checking" do
      # Setup test state
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")
      state = Helper.create_test_state()
      state = put_in(state.reverse_plugin_paths, %{plugin_path => plugin_id})

      # Call the function with relative path
      {:ok, new_state} =
        Events.handle_file_event("test/plugins/test_plugin.ex", state)

      # Verify timer was scheduled
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end
  end

  describe "handle_debounced_events/3" do
    test "successfully reloads plugin" do
      # Setup test state
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")
      state = Helper.create_test_state()

      state =
        put_in(
          state.file_event_timer,
          Process.send_after(self(), :test, 1_000_000)
        )

      # Mock plugin reload
      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:ok, %{id: plugin_id}}
      end)

      expect(ManagerMock, :unload_plugin, fn ^plugin_id ->
        :ok
      end)

      expect(ManagerMock, :load_plugin, fn ^plugin_path ->
        {:ok, %{id: plugin_id}}
      end)

      # Call the function
      {:ok, new_state} =
        Events.handle_debounced_events(plugin_id, plugin_path, state)

      # Verify state
      assert new_state.file_event_timer == nil
    end

    test "handles reload failure" do
      # Setup test state
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")
      state = Helper.create_test_state()

      state =
        put_in(
          state.file_event_timer,
          Process.send_after(self(), :test, 1_000_000)
        )

      # Mock plugin reload failure
      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:ok, %{id: plugin_id}}
      end)

      expect(ManagerMock, :unload_plugin, fn ^plugin_id ->
        {:error, :unload_failed}
      end)

      # Call the function
      {:error, {:unload_failed, :unload_failed}, new_state} =
        Events.handle_debounced_events(plugin_id, plugin_path, state)

      # Verify state
      assert new_state.file_event_timer == nil
    end
  end
end
