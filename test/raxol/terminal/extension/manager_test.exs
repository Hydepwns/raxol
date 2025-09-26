defmodule Raxol.Terminal.Extension.ManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Extension.ExtensionManager, as: Manager

  setup do
    manager = Manager.new()
    %{manager: manager}
  end

  describe "new/1" do
    test "creates a new extension manager with default state", %{
      manager: manager
    } do
      assert map_size(manager.extensions) == 0
      assert map_size(manager.events) == 0
      assert map_size(manager.commands) == 0
      assert map_size(manager.config) == 0
      assert manager.metrics.extension_loads == 0
      assert manager.metrics.extension_unloads == 0
      assert manager.metrics.event_handlers == 0
      assert manager.metrics.command_executions == 0
      assert manager.metrics.config_updates == 0
    end

    test "creates a new extension manager with custom config", %{
      manager: manager
    } do
      manager = Manager.new(custom_option: "value")
      assert manager.config.custom_option == "value"
    end
  end

  describe "load_extension/2" do
    test "loads a valid extension", %{manager: manager} do
      extension = %{
        name: "test_extension",
        version: "1.0.0",
        description: "Test extension",
        author: "Test Author",
        events: ["test_event"],
        commands: ["test_command"],
        config: %{},
        state: %{}
      }

      assert {:ok, updated_manager} = Manager.load_extension(manager, extension)
      assert map_size(updated_manager.extensions) == 1
      assert map_size(updated_manager.events) == 1
      assert map_size(updated_manager.commands) == 1
      assert updated_manager.metrics.extension_loads == 1
    end

    test "returns error for invalid extension", %{manager: manager} do
      invalid_extension = %{
        name: "test_extension",
        version: "1.0.0"
      }

      assert {:error, :invalid_extension} =
               Manager.load_extension(manager, invalid_extension)
    end

    test "returns error for duplicate extension", %{manager: manager} do
      extension = %{
        name: "test_extension",
        version: "1.0.0",
        description: "Test extension",
        author: "Test Author",
        events: ["test_event"],
        commands: ["test_command"],
        config: %{},
        state: %{}
      }

      {:ok, manager} = Manager.load_extension(manager, extension)

      assert {:error, :extension_already_loaded} =
               Manager.load_extension(manager, extension)
    end
  end

  describe "unload_extension/2" do
    test "unloads an existing extension", %{manager: manager} do
      extension = %{
        name: "test_extension",
        version: "1.0.0",
        description: "Test extension",
        author: "Test Author",
        events: ["test_event"],
        commands: ["test_command"],
        config: %{},
        state: %{}
      }

      {:ok, manager} = Manager.load_extension(manager, extension)

      assert {:ok, updated_manager} =
               Manager.unload_extension(manager, "test_extension")

      assert map_size(updated_manager.extensions) == 0
      assert map_size(updated_manager.events) == 0
      assert map_size(updated_manager.commands) == 0
      assert updated_manager.metrics.extension_unloads == 1
    end

    test "returns error for non-existent extension", %{manager: manager} do
      assert {:error, :extension_not_found} =
               Manager.unload_extension(manager, "non_existent")
    end
  end

  describe "emit_event/3" do
    test "emits an event to registered handlers", %{manager: manager} do
      extension = %{
        name: "test_extension",
        version: "1.0.0",
        description: "Test extension",
        author: "Test Author",
        events: ["test_event"],
        commands: ["test_command"],
        config: %{},
        state: %{}
      }

      {:ok, manager} = Manager.load_extension(manager, extension)

      assert {:ok, results, updated_manager} =
               Manager.emit_event(manager, "test_event", ["arg1"])

      assert length(results) == 1
      assert updated_manager.metrics.event_handlers == 1
    end

    test "returns error for non-existent event", %{manager: manager} do
      assert {:error, :event_not_found} =
               Manager.emit_event(manager, "non_existent")
    end
  end

  describe "execute_command/3" do
    test "executes a registered command", %{manager: manager} do
      extension = %{
        name: "test_extension",
        version: "1.0.0",
        description: "Test extension",
        author: "Test Author",
        events: ["test_event"],
        commands: ["test_command"],
        config: %{},
        state: %{}
      }

      {:ok, manager} = Manager.load_extension(manager, extension)

      assert {:ok, result, updated_manager} =
               Manager.execute_command(manager, "test_command", ["arg1"])

      assert updated_manager.metrics.command_executions == 1
    end

    test "returns error for non-existent command", %{manager: manager} do
      assert {:error, :command_not_found} =
               Manager.execute_command(manager, "non_existent")
    end
  end

  describe "update_extension_config/3" do
    test "updates extension configuration", %{manager: manager} do
      extension = %{
        name: "test_extension",
        version: "1.0.0",
        description: "Test extension",
        author: "Test Author",
        events: ["test_event"],
        commands: ["test_command"],
        config: %{},
        state: %{}
      }

      {:ok, manager} = Manager.load_extension(manager, extension)
      new_config = %{option: "value"}

      assert {:ok, updated_manager} =
               Manager.update_extension_config(
                 manager,
                 "test_extension",
                 new_config
               )

      assert updated_manager.extensions["test_extension"].config.option ==
               "value"

      assert updated_manager.metrics.config_updates == 1
    end

    test "returns error for non-existent extension", %{manager: manager} do
      assert {:error, :extension_not_found} =
               Manager.update_extension_config(manager, "non_existent", %{})
    end
  end

  describe "get_metrics/1" do
    test "returns current metrics", %{manager: manager} do
      metrics = Manager.get_metrics(manager)
      assert metrics.extension_loads == 0
      assert metrics.extension_unloads == 0
      assert metrics.event_handlers == 0
      assert metrics.command_executions == 0
      assert metrics.config_updates == 0
    end
  end
end
