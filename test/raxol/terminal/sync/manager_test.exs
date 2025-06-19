defmodule Raxol.Terminal.Sync.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Sync.Manager

  setup do
    # Start the sync manager
    {:ok, _pid} = Manager.start_link()
    :ok
  end

  describe "component registration" do
    test "registers a new component" do
      assert :ok == Manager.register_component("test_split", :split)
      assert :ok == Manager.register_component("test_window", :window)
      assert :ok == Manager.register_component("test_tab", :tab)
    end

    test "prevents duplicate registration" do
      assert :ok == Manager.register_component("test_component", :split)

      assert {:error, :already_registered} ==
               Manager.register_component("test_component", :split)
    end

    test "unregisters a component" do
      assert :ok == Manager.register_component("test_component", :split)
      assert :ok == Manager.unregister_component("test_component")

      assert {:error, :not_found} ==
               Manager.unregister_component("test_component")
    end
  end

  describe "state synchronization" do
    test "syncs state for a registered component" do
      # Register component
      assert :ok == Manager.register_component("test_split", :split)

      # Sync state
      state = %{content: "test content", cursor: {0, 0}}
      assert :ok == Manager.sync_state("test_split", state)

      # Get state
      assert {:ok, ^state} = Manager.get_state("test_split")
    end

    test "handles sync for non-existent component" do
      state = %{content: "test content"}
      assert {:error, :not_found} == Manager.sync_state("nonexistent", state)
    end

    test "updates state with new values" do
      # Register component
      assert :ok == Manager.register_component("test_window", :window)

      # Initial state
      initial_state = %{content: "initial", cursor: {0, 0}}
      assert :ok == Manager.sync_state("test_window", initial_state)

      # Update state
      updated_state = %{content: "updated", cursor: {1, 1}}
      assert :ok == Manager.sync_state("test_window", updated_state)

      # Verify update
      assert {:ok, ^updated_state} = Manager.get_state("test_window")
    end
  end

  describe "consistency levels" do
    test "enforces strong consistency for splits" do
      # Register split
      assert :ok == Manager.register_component("test_split", :split)

      # Initial state
      initial_state = %{content: "initial", version: 1}
      assert :ok == Manager.sync_state("test_split", initial_state)

      # Try to update with lower version
      updated_state = %{content: "updated", version: 0}
      assert :ok == Manager.sync_state("test_split", updated_state)

      # Should keep initial state due to strong consistency
      assert {:ok, ^initial_state} = Manager.get_state("test_split")
    end

    test "allows eventual consistency for tabs" do
      # Register tab
      assert :ok == Manager.register_component("test_tab", :tab)

      # Initial state
      initial_state = %{content: "initial", version: 1}
      assert :ok == Manager.sync_state("test_tab", initial_state)

      # Update with higher version
      updated_state = %{content: "updated", version: 2}
      assert :ok == Manager.sync_state("test_tab", updated_state)

      # Should use updated state due to eventual consistency
      assert {:ok, ^updated_state} = Manager.get_state("test_tab")
    end
  end

  describe "component statistics" do
    test "tracks component statistics" do
      # Register component
      assert :ok == Manager.register_component("test_component", :split)

      # Perform some syncs
      state1 = %{content: "state1"}
      state2 = %{content: "state2"}
      state3 = %{content: "state3"}

      assert :ok == Manager.sync_state("test_component", state1)
      assert :ok == Manager.sync_state("test_component", state2)
      assert :ok == Manager.sync_state("test_component", state3)

      # Get stats
      {:ok, stats} = Manager.get_component_stats("test_component")
      assert stats.sync_count == 3
      assert is_integer(stats.last_sync)
    end

    test "handles stats for non-existent component" do
      assert {:error, :not_found} == Manager.get_component_stats("nonexistent")
    end
  end

  describe "multiple components" do
    test "manages multiple components independently" do
      # Register multiple components
      assert :ok == Manager.register_component("split1", :split)
      assert :ok == Manager.register_component("window1", :window)
      assert :ok == Manager.register_component("tab1", :tab)

      # Set different states
      split_state = %{content: "split content"}
      window_state = %{content: "window content"}
      _tab_state = %{content: "tab content"}

      assert :ok == Manager.sync_state("split1", split_state)
      assert :ok == Manager.sync_state("window1", window_state)
      assert :ok == Manager.sync_state("tab1", _tab_state)

      # Verify each component has its own state
      assert {:ok, ^split_state} = Manager.get_state("split1")
      assert {:ok, ^window_state} = Manager.get_state("window1")
      assert {:ok, ^_tab_state} = Manager.get_state("tab1")
    end

    test ~c"handles component cleanup" do
      # Register and sync state
      assert :ok == Manager.register_component("test_component", :split)
      assert :ok == Manager.sync_state("test_component", %{content: "test"})

      # Unregister
      assert :ok == Manager.unregister_component("test_component")

      # Verify component is gone
      assert {:error, :not_found} == Manager.get_state("test_component")

      assert {:error, :not_found} ==
               Manager.get_component_stats("test_component")
    end
  end
end
