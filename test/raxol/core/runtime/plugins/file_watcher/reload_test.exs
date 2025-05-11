defmodule Raxol.Core.Runtime.Plugins.FileWatcher.ReloadTest do
  use ExUnit.Case
  import Mox
  alias Raxol.Core.Runtime.Plugins.FileWatcher.Reload

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Define mocks
  defmock(ManagerMock, for: Raxol.Core.Runtime.Plugins.Manager.Behaviour)

  # Setup default mocks
  setup do
    # Set default Manager mock implementation
    stub_with(ManagerMock, ManagerMock)
    :ok
  end

  describe "reload_plugin/2" do
    test "successfully reloads plugin" do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_path = "test/plugins/test_plugin.ex"

      # Mock plugin operations
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
      :ok = Reload.reload_plugin(plugin_id, plugin_path)
    end

    test "handles plugin not found" do
      # Setup test data
      plugin_id = "nonexistent_plugin"
      plugin_path = "test/plugins/nonexistent_plugin.ex"

      # Mock plugin not found
      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:error, :not_found}
      end)

      # Call the function
      {:error, :plugin_not_found} = Reload.reload_plugin(plugin_id, plugin_path)
    end

    test "handles unload failure" do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_path = "test/plugins/test_plugin.ex"

      # Mock plugin operations
      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:ok, %{id: plugin_id}}
      end)

      expect(ManagerMock, :unload_plugin, fn ^plugin_id ->
        {:error, :unload_failed}
      end)

      # Call the function
      {:error, {:unload_failed, :unload_failed}} = Reload.reload_plugin(plugin_id, plugin_path)
    end

    test "handles load failure" do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_path = "test/plugins/test_plugin.ex"

      # Mock plugin operations
      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:ok, %{id: plugin_id}}
      end)

      expect(ManagerMock, :unload_plugin, fn ^plugin_id ->
        :ok
      end)

      expect(ManagerMock, :load_plugin, fn ^plugin_path ->
        {:error, :load_failed}
      end)

      # Call the function
      {:error, {:reload_failed, :load_failed}} = Reload.reload_plugin(plugin_id, plugin_path)
    end

    test "handles unexpected errors during reload" do
      # Setup test data
      plugin_id = "test_plugin"
      plugin_path = "test/plugins/test_plugin.ex"

      # Mock plugin operations
      expect(ManagerMock, :get_plugin, fn ^plugin_id ->
        {:ok, %{id: plugin_id}}
      end)

      expect(ManagerMock, :unload_plugin, fn ^plugin_id ->
        raise "Unexpected error"
      end)

      # Call the function
      {:error, {:reload_error, %RuntimeError{message: "Unexpected error"}}} =
        Reload.reload_plugin(plugin_id, plugin_path)
    end
  end
end
