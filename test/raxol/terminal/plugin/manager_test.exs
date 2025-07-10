defmodule Raxol.Terminal.Plugin.ManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Plugin.Manager

  setup do
    manager = Manager.new()
    %{manager: manager}
  end

  describe "new/1" do
    test "creates a new plugin manager with default state", %{manager: manager} do
      assert map_size(manager.plugins) == 0
      assert map_size(manager.hooks) == 0
      assert map_size(manager.config) == 0
      assert manager.metrics.plugin_loads == 0
      assert manager.metrics.plugin_unloads == 0
      assert manager.metrics.hook_calls == 0
      assert manager.metrics.config_updates == 0
    end

    test "creates a new plugin manager with custom config", %{manager: _manager} do
      manager = Manager.new(custom_option: "value")
      assert manager.config.custom_option == "value"
    end
  end

  describe "load_plugin/2" do
    test "loads a valid plugin", %{manager: manager} do
      plugin = %{
        name: "test_plugin",
        version: "1.0.0",
        description: "Test plugin",
        author: "Test Author",
        hooks: ["test_hook"],
        config: %{},
        state: %{}
      }

      assert {:ok, updated_manager} = Manager.load_plugin(manager, plugin)
      assert map_size(updated_manager.plugins) == 1
      assert updated_manager.metrics.plugin_loads == 1
    end

    test "returns error for invalid plugin", %{manager: manager} do
      invalid_plugin = %{
        name: "test_plugin",
        version: "1.0.0"
      }

      assert {:error, :invalid_plugin} =
               Manager.load_plugin(manager, invalid_plugin)
    end

    test "returns error for duplicate plugin", %{manager: manager} do
      plugin = %{
        name: "test_plugin",
        version: "1.0.0",
        description: "Test plugin",
        author: "Test Author",
        hooks: ["test_hook"],
        config: %{},
        state: %{}
      }

      {:ok, manager} = Manager.load_plugin(manager, plugin)

      assert {:error, :plugin_already_loaded} =
               Manager.load_plugin(manager, plugin)
    end
  end

  describe "unload_plugin/2" do
    test "unloads an existing plugin", %{manager: manager} do
      plugin = %{
        name: "test_plugin",
        version: "1.0.0",
        description: "Test plugin",
        author: "Test Author",
        hooks: ["test_hook"],
        config: %{},
        state: %{}
      }

      {:ok, manager} = Manager.load_plugin(manager, plugin)

      assert {:ok, updated_manager} =
               Manager.unload_plugin(manager, "test_plugin")

      assert map_size(updated_manager.plugins) == 0
      assert updated_manager.metrics.plugin_unloads == 1
    end

    test "returns error for non-existent plugin", %{manager: manager} do
      assert {:error, :plugin_not_found} =
               Manager.unload_plugin(manager, "non_existent")
    end
  end

  describe "call_hook/3" do
    test "calls a registered hook", %{manager: manager} do
      plugin = %{
        name: "test_plugin",
        version: "1.0.0",
        description: "Test plugin",
        author: "Test Author",
        hooks: ["test_hook"],
        config: %{},
        state: %{}
      }

      {:ok, manager} = Manager.load_plugin(manager, plugin)

      assert {:ok, results, updated_manager} =
               Manager.call_hook(manager, "test_hook", ["arg1"])

      assert length(results) == 1
      assert updated_manager.metrics.hook_calls == 1
    end

    test "returns error for non-existent hook", %{manager: manager} do
      assert {:error, :hook_not_found} =
               Manager.call_hook(manager, "non_existent")
    end
  end

  describe "update_plugin_config/3" do
    test "updates plugin configuration", %{manager: manager} do
      plugin = %{
        name: "test_plugin",
        version: "1.0.0",
        description: "Test plugin",
        author: "Test Author",
        hooks: ["test_hook"],
        config: %{},
        state: %{}
      }

      {:ok, manager} = Manager.load_plugin(manager, plugin)
      new_config = %{option: "value"}

      assert {:ok, updated_manager} =
               Manager.update_plugin_config(manager, "test_plugin", new_config)

      assert updated_manager.plugins["test_plugin"].config.option == "value"
      assert updated_manager.metrics.config_updates == 1
    end

    test "returns error for non-existent plugin", %{manager: manager} do
      assert {:error, :plugin_not_found} =
               Manager.update_plugin_config(manager, "non_existent", %{})
    end
  end

  describe "get_metrics/1" do
    test "returns current metrics", %{manager: manager} do
      metrics = Manager.get_metrics(manager)
      assert metrics.plugin_loads == 0
      assert metrics.plugin_unloads == 0
      assert metrics.hook_calls == 0
      assert metrics.config_updates == 0
    end
  end
end
