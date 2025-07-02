defmodule Raxol.Terminal.Capabilities.ManagerTest do
  use ExUnit.Case, async: false
  alias Raxol.Terminal.Capabilities.Manager

  setup do
    test_name =
      String.to_atom("capabilities_manager_test_#{:rand.uniform(1_000_000)}")

    {:ok, pid} = Manager.start_link(name: test_name)
    %{pid: pid, manager: test_name}
  end

  describe "capability detection" do
    test "can detect and register a new capability", %{manager: manager} do
      assert :ok = Manager.detect_capability(:test_cap, true, manager)
      assert {:ok, true} = Manager.query_capability(:test_cap, manager)
    end

    test "returns error for unsupported capability", %{manager: manager} do
      assert {:error, :unsupported} =
               Manager.query_capability(:nonexistent_cap, manager)
    end
  end

  describe "capability enabling" do
    test "can enable a supported capability", %{manager: manager} do
      :ok = Manager.detect_capability(:test_cap, true, manager)
      assert :ok = Manager.enable_capability(:test_cap, manager)
    end

    test "returns error when enabling unsupported capability", %{
      manager: manager
    } do
      assert {:error, :unsupported} =
               Manager.enable_capability(:nonexistent_cap, manager)
    end
  end

  describe "capability querying" do
    test "returns capability value when supported", %{manager: manager} do
      :ok = Manager.detect_capability(:test_cap, "test_value", manager)
      assert {:ok, "test_value"} = Manager.query_capability(:test_cap, manager)
    end

    test "returns error for unsupported capability", %{manager: manager} do
      assert {:error, :unsupported} =
               Manager.query_capability(:nonexistent_cap, manager)
    end
  end
end
