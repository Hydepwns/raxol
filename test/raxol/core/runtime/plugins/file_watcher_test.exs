defmodule Raxol.Core.Runtime.Plugins.FileWatcherTest do
  use ExUnit.Case
  import Mox
  alias Raxol.Core.Runtime.Plugins.FileWatcher
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

  # Helper function to create a valid file stat
  defp valid_file_stat do
    {:ok,
     %File.Stat{
       size: 0,
       type: :regular,
       access: :read,
       atime: {{2024, 1, 1}, {0, 0, 0}},
       mtime: {{2024, 1, 1}, {0, 0, 0}},
       ctime: {{2024, 1, 1}, {0, 0, 0}},
       mode: 0o644,
       links: 1,
       major_device: 0,
       minor_device: 0,
       inode: 0,
       uid: 0,
       gid: 0
     }}
  end

  # Helper function to create a directory stat
  defp directory_stat do
    {:ok,
     %File.Stat{
       size: 0,
       type: :directory,
       access: :read,
       atime: {{2024, 1, 1}, {0, 0, 0}},
       mtime: {{2024, 1, 1}, {0, 0, 0}},
       ctime: {{2024, 1, 1}, {0, 0, 0}},
       mode: 0o755,
       links: 1,
       major_device: 0,
       minor_device: 0,
       inode: 0,
       uid: 0,
       gid: 0
     }}
  end

  describe "setup_file_watching/1" do
    test "starts file system watcher when FileSystem is available" do
      # Setup test state
      state = Helper.create_test_state()

      # Expect FileSystem to be called
      expect(FileSystemMock, :start_link, fn dirs: dirs ->
        assert dirs == ["test/plugins"]
        {:ok, self()}
      end)

      expect(FileSystemMock, :subscribe, fn _pid -> :ok end)

      # Call the function
      {pid, enabled?} = FileWatcher.setup_file_watching(state)

      # Verify results
      assert is_pid(pid)
      assert enabled? == true
    end

    test "handles FileSystem start failure" do
      # Setup test state
      state = Helper.create_test_state()

      # Expect FileSystem to fail
      expect(FileSystemMock, :start_link, fn dirs: dirs ->
        assert dirs == ["test/plugins"]
        {:error, :some_error}
      end)

      # Call the function
      {pid, enabled?} = FileWatcher.setup_file_watching(state)

      # Verify results
      assert pid == nil
      assert enabled? == false
    end
  end

  describe "handle_file_event/2" do
    test "ignores events for unknown files" do
      # Setup test state
      state = Helper.create_test_state()

      # Call the function
      {:ok, new_state} = FileWatcher.handle_file_event("unknown/path", state)

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
        FileWatcher.handle_file_event(plugin_path, state)
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
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)

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
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)

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
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)

      # Verify old timer was cancelled and new one scheduled
      refute Process.cancel_timer(existing_timer)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "normalizes paths before checking" do
      # Setup test state
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      # Call the function with relative path
      {:ok, new_state} =
        FileWatcher.handle_file_event("test/plugins/test_plugin.ex", state)

      # Verify timer was scheduled
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles file_event_timer as an invalid reference" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")
      # Use an invalid timer reference
      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: make_ref()
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)
      # Should not crash even if timer is not a real timer
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles File.stat returning unexpected tuple" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> :unexpected_tuple end)
      # Should treat as error
      assert {:error, {:file_access_error, :unexpected_tuple}} =
               FileWatcher.handle_file_event(plugin_path, state)
    end

    test "handles nil plugin_id in reverse_plugin_paths" do
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => nil},
        file_event_timer: nil
      }

      # Should treat as unknown file
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert new_state == state
    end

    test "handles file_event_timer already nil when cancelling" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert is_reference(new_state.file_event_timer)
    end

    test "handle_file_event with empty path" do
      state = %{
        reverse_plugin_paths: %{},
        file_event_timer: nil
      }

      {:ok, new_state} = FileWatcher.handle_file_event("", state)
      assert new_state == state
    end

    test "handles File.stat raising an exception" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> raise "stat error" end)

      assert_raise RuntimeError, "stat error", fn ->
        FileWatcher.handle_file_event(plugin_path, state)
      end
    end

    test "handles symlink file type" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path ->
        {:ok, %{type: :symlink, access: :read}}
      end)

      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert new_state == state
    end

    test "handles FIFO file type" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path ->
        {:ok, %{type: :fifo, access: :read}}
      end)

      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert new_state == state
    end

    test "handles regular file but access is not :read" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path ->
        {:ok, %{type: :regular, access: :none}}
      end)

      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert new_state == state
    end

    test "handles File.stat returning nil" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> nil end)

      assert {:error, {:file_access_error, nil}} =
               FileWatcher.handle_file_event(plugin_path, state)
    end

    test "handles path as nil" do
      state = %{
        reverse_plugin_paths: %{},
        file_event_timer: nil
      }

      assert {:ok, new_state} = FileWatcher.handle_file_event(nil, state)
      assert new_state == state
    end

    test "handles path as integer" do
      state = %{
        reverse_plugin_paths: %{},
        file_event_timer: nil
      }

      assert {:ok, new_state} = FileWatcher.handle_file_event(123, state)
      assert new_state == state
    end

    test "handles relative path with .. segments" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)

      {:ok, new_state} =
        FileWatcher.handle_file_event(
          "test/plugins/../plugins/test_plugin.ex",
          state
        )

      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles state missing file_event_timer key" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id}
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles reverse_plugin_paths as nil" do
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: nil,
        file_event_timer: nil
      }

      assert {:ok, new_state} =
               FileWatcher.handle_file_event(plugin_path, state)

      assert new_state == state
    end

    test "handles reverse_plugin_paths as a list" do
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: [],
        file_event_timer: nil
      }

      assert {:ok, new_state} =
               FileWatcher.handle_file_event(plugin_path, state)

      assert new_state == state
    end

    test "handles reverse_plugin_paths as an integer" do
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: 123,
        file_event_timer: nil
      }

      assert {:ok, new_state} =
               FileWatcher.handle_file_event(plugin_path, state)

      assert new_state == state
    end

    test "handles state missing reverse_plugin_paths key" do
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        file_event_timer: nil
      }

      assert {:ok, new_state} =
               FileWatcher.handle_file_event(plugin_path, state)

      assert new_state == state
    end

    test "handles file_event_timer as a string" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: "not_a_timer"
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles file_event_timer as an integer" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: 42
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles File.stat returning non-File.Stat struct" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> {:ok, %{foo: :bar}} end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert new_state == state
    end

    test "handles File.stat returning tuple with unexpected fields" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> {:ok, {1, 2, 3}} end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert new_state == state
    end

    test "handles plugin path as empty string in reverse_plugin_paths" do
      plugin_id = "test_plugin"
      plugin_path = ""

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles plugin path as unicode string" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("тестовый_плагин")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles plugin path as very long string" do
      plugin_id = "test_plugin"
      long_name = String.duplicate("a", 500)
      long_path = Helper.create_test_plugin(long_name)

      state = %{
        reverse_plugin_paths: %{long_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^long_path -> valid_file_stat() end)
      {:ok, new_state} = FileWatcher.handle_file_event(long_path, state)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles plugin_id as empty string" do
      plugin_id = ""
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles plugin_id as integer" do
      plugin_id = 123
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, fn ^plugin_path -> valid_file_stat() end)
      {:ok, new_state} = FileWatcher.handle_file_event(plugin_path, state)
      assert is_reference(new_state.file_event_timer)
      assert Process.cancel_timer(new_state.file_event_timer)
    end

    test "handles multiple rapid file events" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      state = %{
        reverse_plugin_paths: %{plugin_path => plugin_id},
        file_event_timer: nil
      }

      expect(FileMock, :stat, 2, fn ^plugin_path -> valid_file_stat() end)
      {:ok, state1} = FileWatcher.handle_file_event(plugin_path, state)
      {:ok, state2} = FileWatcher.handle_file_event(plugin_path, state1)
      assert is_reference(state2.file_event_timer)
      assert Process.cancel_timer(state2.file_event_timer)
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
        FileWatcher.handle_debounced_events(plugin_id, plugin_path, state)

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
        FileWatcher.handle_debounced_events(plugin_id, plugin_path, state)

      # Verify state
      assert new_state.file_event_timer == nil
    end
  end

  describe "update_file_watcher/1" do
    test "updates reverse path mapping with normalized paths" do
      # Setup test state
      state = Helper.create_test_state()
      state = put_in(state.file_watching_enabled?, true)

      state =
        put_in(state.plugin_paths, %{
          "plugin1" => "path/to/plugin1.ex",
          "plugin2" => "path/to/plugin2.ex"
        })

      # Call the function
      new_state = FileWatcher.update_file_watcher(state)

      # Verify reverse mapping was created with normalized paths
      assert new_state.reverse_plugin_paths == %{
               Path.expand("path/to/plugin1.ex") => "plugin1",
               Path.expand("path/to/plugin2.ex") => "plugin2"
             }
    end

    test "returns unchanged state when file watching is disabled" do
      # Setup test state
      state = Helper.create_test_state()
      state = put_in(state.plugin_paths, %{"plugin1" => "path/to/plugin1.ex"})

      # Call the function
      new_state = FileWatcher.update_file_watcher(state)

      # Verify state is unchanged
      assert new_state == state
    end
  end

  describe "cleanup_file_watching/1" do
    test "stops file watcher process" do
      # Setup test state with watcher PID
      watcher_pid =
        spawn(fn ->
          receive do
            :stop -> :ok
          end
        end)

      state = Helper.create_test_state()
      state = put_in(state.file_watcher_pid, watcher_pid)

      # Call the function
      new_state = FileWatcher.cleanup_file_watching(state)

      # Verify watcher was stopped
      refute Process.alive?(watcher_pid)
      assert new_state == state
    end

    test "cancels pending timer" do
      # Setup test state with timer
      timer_ref = Process.send_after(self(), :test, 1_000_000)
      state = Helper.create_test_state()
      state = put_in(state.file_event_timer, timer_ref)

      # Call the function
      new_state = FileWatcher.cleanup_file_watching(state)

      # Verify timer was cancelled
      refute Process.cancel_timer(timer_ref)
      assert new_state == state
    end
  end

  describe "reload_plugin/2" do
    test "successfully reloads an existing plugin" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      # Mock plugin manager responses
      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:ok, %{id: plugin_id}}
      end)

      expect(ManagerMock, :unload_plugin, fn ^plugin_id ->
        :ok
      end)

      expect(ManagerMock, :load_plugin, fn ^plugin_path ->
        {:ok, %{id: plugin_id}}
      end)

      assert :ok = FileWatcher.reload_plugin(plugin_id, plugin_path)
    end

    test "handles plugin not found error" do
      plugin_id = "nonexistent_plugin"
      plugin_path = Helper.create_test_plugin("nonexistent_plugin")

      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:error, :not_found}
      end)

      assert {:error, :plugin_not_found} =
               FileWatcher.reload_plugin(plugin_id, plugin_path)
    end

    test "handles unload failure" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:ok, %{id: plugin_id}}
      end)

      expect(ManagerMock, :unload_plugin, fn ^plugin_id ->
        {:error, :unload_failed}
      end)

      assert {:error, {:unload_failed, :unload_failed}} =
               FileWatcher.reload_plugin(plugin_id, plugin_path)
    end

    test "handles load failure" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:ok, %{id: plugin_id}}
      end)

      expect(ManagerMock, :unload_plugin, fn ^plugin_id ->
        :ok
      end)

      expect(ManagerMock, :load_plugin, fn ^plugin_path ->
        {:error, :load_failed}
      end)

      assert {:error, {:reload_failed, :load_failed}} =
               FileWatcher.reload_plugin(plugin_id, plugin_path)
    end

    test "handles unexpected errors during reload" do
      plugin_id = "test_plugin"
      plugin_path = Helper.create_test_plugin("test_plugin")

      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:ok, %{id: plugin_id}}
      end)

      expect(ManagerMock, :unload_plugin, fn ^plugin_id ->
        raise "Unexpected error"
      end)

      assert {:error,
              {:reload_error, %RuntimeError{message: "Unexpected error"}}} =
               FileWatcher.reload_plugin(plugin_id, plugin_path)
    end
  end

  @tag :skip
  @doc """
  Skipped: Recursive directory watching implementation incomplete.
  Blocked by: Directory traversal optimization (see docs/testing/test_tracking.md).
  Once recursive watching is implemented, this test should be enabled and completed.
  """
  test "handles recursive directory watching" do
    # NOTE: Implement test for recursive directory watching once the feature is available.
    # This test is currently skipped and serves as a placeholder for future work.
    assert true
  end
end
