defmodule Raxol.Core.Runtime.Plugins.FileWatcher.CoreTest do
  use ExUnit.Case
  import Mox
  alias Raxol.Core.Runtime.Plugins.FileWatcher.Core
  alias FileWatcherTestHelper, as: Helper

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Define mocks
  defmock(FileSystemMock, for: FileSystem.Behaviour)

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
      {pid, enabled?} = Core.setup_file_watching(state)

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
      {pid, enabled?} = Core.setup_file_watching(state)

      # Verify results
      assert pid == nil
      assert enabled? == false
    end
  end

  describe "update_file_watcher/1" do
    test "updates reverse paths when file watching is enabled" do
      # Setup test state
      state = Helper.create_test_state()
      state = put_in(state.file_watching_enabled?, true)
      state = put_in(state.plugin_paths, %{
        "plugin1" => "test/plugins/plugin1.ex",
        "plugin2" => "test/plugins/plugin2.ex"
      })

      # Call the function
      new_state = Core.update_file_watcher(state)

      # Verify results
      assert map_size(new_state.reverse_plugin_paths) == 2
      assert new_state.reverse_plugin_paths[Path.expand("test/plugins/plugin1.ex")] == "plugin1"
      assert new_state.reverse_plugin_paths[Path.expand("test/plugins/plugin2.ex")] == "plugin2"
    end

    test "returns unchanged state when file watching is disabled" do
      # Setup test state
      state = Helper.create_test_state()
      state = put_in(state.plugin_paths, %{"plugin1" => "test/plugins/plugin1.ex"})

      # Call the function
      new_state = Core.update_file_watcher(state)

      # Verify state is unchanged
      assert new_state == state
    end
  end
end
