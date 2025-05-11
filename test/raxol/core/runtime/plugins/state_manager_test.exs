defmodule Raxol.Core.Runtime.Plugins.StateManagerTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.StateManager

  describe "update_state_maps/6" do
    test "updates all state maps with new plugin" do
      # Setup initial state maps
      state_maps = %{
        plugins: %{},
        metadata: %{},
        plugin_states: %{},
        load_order: [],
        plugin_config: %{}
      }

      # Call the function
      updated_maps = StateManager.update_state_maps(
        "test_plugin",
        TestPlugin,
        %{version: "1.0.0"},
        %{initialized: true},
        %{setting: "value"},
        state_maps
      )

      # Verify results
      assert updated_maps.plugins == %{"test_plugin" => TestPlugin}
      assert updated_maps.metadata == %{"test_plugin" => %{version: "1.0.0"}}
      assert updated_maps.plugin_states == %{"test_plugin" => %{initialized: true}}
      assert updated_maps.load_order == ["test_plugin"]
      assert updated_maps.plugin_config == %{"test_plugin" => %{setting: "value"}}
    end

    test "appends to existing state maps" do
      # Setup initial state maps with existing plugin
      state_maps = %{
        plugins: %{"existing_plugin" => ExistingPlugin},
        metadata: %{"existing_plugin" => %{version: "0.9.0"}},
        plugin_states: %{"existing_plugin" => %{initialized: true}},
        load_order: ["existing_plugin"],
        plugin_config: %{"existing_plugin" => %{setting: "old"}}
      }

      # Call the function
      updated_maps = StateManager.update_state_maps(
        "test_plugin",
        TestPlugin,
        %{version: "1.0.0"},
        %{initialized: true},
        %{setting: "value"},
        state_maps
      )

      # Verify results
      assert updated_maps.plugins == %{
        "existing_plugin" => ExistingPlugin,
        "test_plugin" => TestPlugin
      }
      assert updated_maps.metadata == %{
        "existing_plugin" => %{version: "0.9.0"},
        "test_plugin" => %{version: "1.0.0"}
      }
      assert updated_maps.plugin_states == %{
        "existing_plugin" => %{initialized: true},
        "test_plugin" => %{initialized: true}
      }
      assert updated_maps.load_order == ["existing_plugin", "test_plugin"]
      assert updated_maps.plugin_config == %{
        "existing_plugin" => %{setting: "old"},
        "test_plugin" => %{setting: "value"}
      }
    end
  end

  describe "remove_plugin/2" do
    test "removes plugin from all state maps" do
      # Setup initial state maps
      state_maps = %{
        plugins: %{"test_plugin" => TestPlugin},
        metadata: %{"test_plugin" => %{version: "1.0.0"}},
        plugin_states: %{"test_plugin" => %{initialized: true}},
        load_order: ["test_plugin"],
        plugin_config: %{"test_plugin" => %{setting: "value"}}
      }

      # Call the function
      updated_maps = StateManager.remove_plugin("test_plugin", state_maps)

      # Verify results
      assert updated_maps.plugins == %{}
      assert updated_maps.metadata == %{}
      assert updated_maps.plugin_states == %{}
      assert updated_maps.load_order == []
      assert updated_maps.plugin_config == %{}
    end

    test "removes only specified plugin when multiple exist" do
      # Setup initial state maps with multiple plugins
      state_maps = %{
        plugins: %{
          "test_plugin" => TestPlugin,
          "other_plugin" => OtherPlugin
        },
        metadata: %{
          "test_plugin" => %{version: "1.0.0"},
          "other_plugin" => %{version: "0.9.0"}
        },
        plugin_states: %{
          "test_plugin" => %{initialized: true},
          "other_plugin" => %{initialized: true}
        },
        load_order: ["test_plugin", "other_plugin"],
        plugin_config: %{
          "test_plugin" => %{setting: "value"},
          "other_plugin" => %{setting: "other"}
        }
      }

      # Call the function
      updated_maps = StateManager.remove_plugin("test_plugin", state_maps)

      # Verify results
      assert updated_maps.plugins == %{"other_plugin" => OtherPlugin}
      assert updated_maps.metadata == %{"other_plugin" => %{version: "0.9.0"}}
      assert updated_maps.plugin_states == %{"other_plugin" => %{initialized: true}}
      assert updated_maps.load_order == ["other_plugin"]
      assert updated_maps.plugin_config == %{"other_plugin" => %{setting: "other"}}
    end
  end

  describe "update_plugin_state/3" do
    test "updates plugin state" do
      # Setup initial state maps
      state_maps = %{
        plugins: %{"test_plugin" => TestPlugin},
        metadata: %{"test_plugin" => %{version: "1.0.0"}},
        plugin_states: %{"test_plugin" => %{initialized: true}},
        load_order: ["test_plugin"],
        plugin_config: %{"test_plugin" => %{setting: "value"}}
      }

      # Call the function
      updated_maps = StateManager.update_plugin_state(
        "test_plugin",
        %{initialized: false},
        state_maps
      )

      # Verify results
      assert updated_maps.plugin_states == %{"test_plugin" => %{initialized: false}}
      # Verify other maps are unchanged
      assert updated_maps.plugins == state_maps.plugins
      assert updated_maps.metadata == state_maps.metadata
      assert updated_maps.load_order == state_maps.load_order
      assert updated_maps.plugin_config == state_maps.plugin_config
    end
  end

  describe "get_plugin_state/2" do
    test "returns plugin state when found" do
      # Setup state maps
      state_maps = %{
        plugin_states: %{"test_plugin" => %{initialized: true}}
      }

      # Call the function
      state = StateManager.get_plugin_state("test_plugin", state_maps)

      # Verify results
      assert state == %{initialized: true}
    end

    test "returns nil when plugin not found" do
      # Setup state maps
      state_maps = %{
        plugin_states: %{}
      }

      # Call the function
      state = StateManager.get_plugin_state("unknown_plugin", state_maps)

      # Verify results
      assert state == nil
    end
  end

  describe "get_plugin_module/2" do
    test "returns plugin module when found" do
      # Setup state maps
      state_maps = %{
        plugins: %{"test_plugin" => TestPlugin}
      }

      # Call the function
      module = StateManager.get_plugin_module("test_plugin", state_maps)

      # Verify results
      assert module == TestPlugin
    end

    test "returns nil when plugin not found" do
      # Setup state maps
      state_maps = %{
        plugins: %{}
      }

      # Call the function
      module = StateManager.get_plugin_module("unknown_plugin", state_maps)

      # Verify results
      assert module == nil
    end
  end

  describe "get_plugin_metadata/2" do
    test "returns plugin metadata when found" do
      # Setup state maps
      state_maps = %{
        metadata: %{"test_plugin" => %{version: "1.0.0"}}
      }

      # Call the function
      metadata = StateManager.get_plugin_metadata("test_plugin", state_maps)

      # Verify results
      assert metadata == %{version: "1.0.0"}
    end

    test "returns nil when plugin not found" do
      # Setup state maps
      state_maps = %{
        metadata: %{}
      }

      # Call the function
      metadata = StateManager.get_plugin_metadata("unknown_plugin", state_maps)

      # Verify results
      assert metadata == nil
    end
  end

  describe "get_plugin_config/2" do
    test "returns plugin config when found" do
      # Setup state maps
      state_maps = %{
        plugin_config: %{"test_plugin" => %{setting: "value"}}
      }

      # Call the function
      config = StateManager.get_plugin_config("test_plugin", state_maps)

      # Verify results
      assert config == %{setting: "value"}
    end

    test "returns nil when plugin not found" do
      # Setup state maps
      state_maps = %{
        plugin_config: %{}
      }

      # Call the function
      config = StateManager.get_plugin_config("unknown_plugin", state_maps)

      # Verify results
      assert config == nil
    end
  end
end
