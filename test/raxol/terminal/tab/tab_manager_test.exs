defmodule Raxol.Terminal.Tab.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Tab.Manager
  import File, only: [cwd!: 0]

  describe "new/0" do
    test "creates a new tab manager instance" do
      manager = Manager.new()
      assert manager.tabs == %{}
      assert manager.active_tab == nil
      assert manager.next_tab_id == 1
    end
  end

  describe "create_tab/2" do
    test "creates a new tab with default configuration" do
      manager = Manager.new()
      {:ok, tab_id, updated_manager} = Manager.create_tab(manager)

      assert is_binary(tab_id)
      assert String.starts_with?(tab_id, "tab_")
      assert map_size(updated_manager.tabs) == 1
      assert updated_manager.next_tab_id == 2

      {:ok, config} = Manager.get_tab_config(updated_manager, tab_id)
      assert config.title == "Tab #{tab_id}"
      assert config.working_directory == File.cwd!()
      assert config.command == nil
      assert config.state == :inactive
      assert config.window_id == nil
    end

    test "creates a new tab with custom configuration" do
      manager = Manager.new()

      custom_config = %{
        title: "Custom Tab",
        working_directory: "/tmp",
        command: "ls",
        state: :active,
        window_id: "win_1"
      }

      {:ok, tab_id, updated_manager} =
        Manager.create_tab(manager, custom_config)

      {:ok, config} = Manager.get_tab_config(updated_manager, tab_id)
      assert config.title == "Custom Tab"
      assert config.working_directory == "/tmp"
      assert config.command == "ls"
      assert config.state == :active
      assert config.window_id == "win_1"
    end
  end

  describe "delete_tab/2" do
    test "deletes an existing tab" do
      manager = Manager.new()
      {:ok, tab_id, manager} = Manager.create_tab(manager)
      {:ok, updated_manager} = Manager.delete_tab(manager, tab_id)

      assert map_size(updated_manager.tabs) == 0

      assert {:error, :tab_not_found} ==
               Manager.get_tab_config(updated_manager, tab_id)
    end

    test "returns error when deleting non-existent tab" do
      manager = Manager.new()

      assert {:error, :tab_not_found} ==
               Manager.delete_tab(manager, "non_existent")
    end

    test "clears active tab when deleting active tab" do
      manager = Manager.new()
      {:ok, tab_id, manager} = Manager.create_tab(manager)
      {:ok, manager} = Manager.switch_tab(manager, tab_id)
      {:ok, updated_manager} = Manager.delete_tab(manager, tab_id)

      assert updated_manager.active_tab == nil
    end
  end

  describe "switch_tab/2" do
    test "switches to an existing tab" do
      manager = Manager.new()
      {:ok, tab_id, manager} = Manager.create_tab(manager)
      {:ok, updated_manager} = Manager.switch_tab(manager, tab_id)

      assert updated_manager.active_tab == tab_id
    end

    test "returns error when switching to non-existent tab" do
      manager = Manager.new()

      assert {:error, :tab_not_found} ==
               Manager.switch_tab(manager, "non_existent")
    end
  end

  describe "get_tab_config/2" do
    test "returns tab configuration for existing tab" do
      manager = Manager.new()
      {:ok, tab_id, manager} = Manager.create_tab(manager)
      {:ok, config} = Manager.get_tab_config(manager, tab_id)

      assert config.title == "Tab #{tab_id}"
      assert config.working_directory == File.cwd!()
    end

    test "returns error for non-existent tab" do
      manager = Manager.new()

      assert {:error, :tab_not_found} ==
               Manager.get_tab_config(manager, "non_existent")
    end
  end

  describe "update_tab_config/3" do
    test "updates configuration for existing tab" do
      manager = Manager.new()
      {:ok, tab_id, manager} = Manager.create_tab(manager)
      updates = %{title: "Updated Title", state: :active}

      {:ok, updated_manager} =
        Manager.update_tab_config(manager, tab_id, updates)

      {:ok, config} = Manager.get_tab_config(updated_manager, tab_id)

      assert config.title == "Updated Title"
      assert config.state == :active
      # unchanged
      assert config.working_directory == File.cwd!()
    end

    test "returns error when updating non-existent tab" do
      manager = Manager.new()

      assert {:error, :tab_not_found} ==
               Manager.update_tab_config(manager, "non_existent", %{})
    end
  end

  describe "list_tabs/1" do
    test "returns all tabs" do
      manager = Manager.new()
      {:ok, tab1, manager} = Manager.create_tab(manager)
      {:ok, tab2, manager} = Manager.create_tab(manager)

      tabs = Manager.list_tabs(manager)
      assert map_size(tabs) == 2
      assert Map.has_key?(tabs, tab1)
      assert Map.has_key?(tabs, tab2)
    end
  end

  describe "get_active_tab/1" do
    test "returns active tab id" do
      manager = Manager.new()
      {:ok, tab_id, manager} = Manager.create_tab(manager)
      {:ok, manager} = Manager.switch_tab(manager, tab_id)

      assert Manager.get_active_tab(manager) == tab_id
    end

    test "returns nil when no active tab" do
      manager = Manager.new()
      assert Manager.get_active_tab(manager) == nil
    end
  end
end
