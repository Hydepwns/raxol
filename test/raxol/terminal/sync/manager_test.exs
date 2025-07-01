defmodule Raxol.Terminal.Sync.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Sync.Manager

  # Test-specific wrapper functions that use the process name
  defp register_component(
         manager_name,
         component_id,
         component_type,
         initial_state \\ %{}
       ) do
    GenServer.call(
      manager_name,
      {:register_component, component_id, component_type, initial_state}
    )
  end

  defp unregister_component(manager_name, component_id) do
    GenServer.call(manager_name, {:unregister_component, component_id})
  end

  defp sync_state(
         manager_name,
         component_id,
         component_type,
         new_state,
         opts \\ []
       ) do
    GenServer.call(
      manager_name,
      {:sync_state, component_id, component_type, new_state, opts}
    )
  end

  defp sync_state_simple(manager_name, component_id, new_state) do
    GenServer.call(manager_name, {:sync_state_simple, component_id, new_state})
  end

  defp get_state(manager_name, component_id) do
    GenServer.call(manager_name, {:get_state, component_id})
  end

  defp get_component_stats(manager_name, component_id) do
    GenServer.call(manager_name, {:get_component_stats, component_id})
  end

  setup do
    # Start the sync manager with unique name
    name = Raxol.Test.ProcessNaming.generate_name(Manager)
    {:ok, pid} = Manager.start_link(name: name)
    %{manager_pid: pid, manager_name: name}
  end

  describe "component registration" do
    test "registers a new component", %{manager_name: manager_name} do
      assert :ok == register_component(manager_name, "test_split", :split)
      assert :ok == register_component(manager_name, "test_window", :window)
      assert :ok == register_component(manager_name, "test_tab", :tab)
    end

    test "prevents duplicate registration", %{manager_name: manager_name} do
      assert :ok == register_component(manager_name, "test_component", :split)

      assert {:error, :already_registered} ==
               register_component(manager_name, "test_component", :split)
    end

    test "unregisters a component", %{manager_name: manager_name} do
      assert :ok == register_component(manager_name, "test_component", :split)
      assert :ok == unregister_component(manager_name, "test_component")

      assert {:error, :not_found} ==
               unregister_component(manager_name, "test_component")
    end
  end

  describe "state synchronization" do
    test "syncs state for a registered component", %{manager_name: manager_name} do
      # Register component
      assert :ok == register_component(manager_name, "test_split", :split)

      # Sync state
      state = %{content: "test content", cursor: {0, 0}}
      assert :ok == sync_state_simple(manager_name, "test_split", state)

      # Get state
      assert {:ok, ^state} = get_state(manager_name, "test_split")
    end

    test "handles sync for non-existent component", %{
      manager_name: manager_name
    } do
      state = %{content: "test content"}

      assert {:error, :not_found} ==
               sync_state_simple(manager_name, "nonexistent", state)
    end

    test "updates state with new values", %{manager_name: manager_name} do
      # Register component
      assert :ok == register_component(manager_name, "test_window", :window)

      # Initial state
      initial_state = %{content: "initial", cursor: {0, 0}}

      assert :ok ==
               sync_state_simple(manager_name, "test_window", initial_state)

      # Update state
      updated_state = %{content: "updated", cursor: {1, 1}}

      assert :ok ==
               sync_state_simple(manager_name, "test_window", updated_state)

      # Verify update
      assert {:ok, ^updated_state} = get_state(manager_name, "test_window")
    end
  end

  describe "consistency levels" do
    test "enforces strong consistency for splits", %{manager_name: manager_name} do
      # Register split
      assert :ok == register_component(manager_name, "test_split", :split)

      # Initial state
      initial_state = %{content: "initial", version: 1}
      assert :ok == sync_state_simple(manager_name, "test_split", initial_state)

      # Try to update with lower version
      updated_state = %{content: "updated", version: 0}
      assert :ok == sync_state_simple(manager_name, "test_split", updated_state)

      # Should keep initial state due to strong consistency
      assert {:ok, ^initial_state} = get_state(manager_name, "test_split")
    end

    test "allows eventual consistency for tabs", %{manager_name: manager_name} do
      # Register tab
      assert :ok == register_component(manager_name, "test_tab", :tab)

      # Initial state
      initial_state = %{content: "initial", version: 1}
      assert :ok == sync_state_simple(manager_name, "test_tab", initial_state)

      # Update with higher version
      updated_state = %{content: "updated", version: 2}
      assert :ok == sync_state_simple(manager_name, "test_tab", updated_state)

      # Should use updated state due to eventual consistency
      assert {:ok, ^updated_state} = get_state(manager_name, "test_tab")
    end
  end

  describe "component statistics" do
    test "tracks component statistics", %{manager_name: manager_name} do
      # Register component
      assert :ok == register_component(manager_name, "test_component", :split)

      # Perform some syncs
      state1 = %{content: "state1"}
      state2 = %{content: "state2"}
      state3 = %{content: "state3"}

      assert :ok == sync_state_simple(manager_name, "test_component", state1)
      assert :ok == sync_state_simple(manager_name, "test_component", state2)
      assert :ok == sync_state_simple(manager_name, "test_component", state3)

      # Get stats
      {:ok, stats} = get_component_stats(manager_name, "test_component")
      assert stats.sync_count == 3
      assert is_integer(stats.last_sync)
    end

    test "handles stats for non-existent component", %{
      manager_name: manager_name
    } do
      assert {:error, :not_found} ==
               get_component_stats(manager_name, "nonexistent")
    end
  end

  describe "multiple components" do
    test "manages multiple components independently", %{
      manager_name: manager_name
    } do
      # Register multiple components
      assert :ok == register_component(manager_name, "split1", :split)
      assert :ok == register_component(manager_name, "window1", :window)
      assert :ok == register_component(manager_name, "tab1", :tab)

      # Set different states
      split_state = %{content: "split content"}
      window_state = %{content: "window content"}
      tab_state = %{content: "tab content"}

      assert :ok == sync_state_simple(manager_name, "split1", split_state)
      assert :ok == sync_state_simple(manager_name, "window1", window_state)
      assert :ok == sync_state_simple(manager_name, "tab1", tab_state)

      # Verify each component has its own state
      assert {:ok, ^split_state} = get_state(manager_name, "split1")
      assert {:ok, ^window_state} = get_state(manager_name, "window1")
      assert {:ok, ^tab_state} = get_state(manager_name, "tab1")
    end

    test ~c"handles component cleanup", %{manager_name: manager_name} do
      # Register and sync state
      assert :ok == register_component(manager_name, "test_component", :split)

      assert :ok ==
               sync_state_simple(manager_name, "test_component", %{
                 content: "test"
               })

      # Unregister
      assert :ok == unregister_component(manager_name, "test_component")

      # Verify component is gone
      assert {:error, :not_found} == get_state(manager_name, "test_component")

      assert {:error, :not_found} ==
               get_component_stats(manager_name, "test_component")
    end
  end
end
