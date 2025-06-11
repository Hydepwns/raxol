defmodule Raxol.Terminal.Capabilities.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Capabilities.Manager

  setup do
    {:ok, pid} = Manager.start_link()
    %{pid: pid}
  end

  describe "capability detection" do
    test "can detect and register a new capability", %{pid: pid} do
      assert :ok = Manager.detect_capability(:test_cap, true)
      assert {:ok, true} = Manager.query_capability(:test_cap)
    end

    test "returns error for unsupported capability", %{pid: pid} do
      assert {:error, :unsupported} = Manager.query_capability(:nonexistent_cap)
    end
  end

  describe "capability enabling" do
    test "can enable a supported capability", %{pid: pid} do
      :ok = Manager.detect_capability(:test_cap, true)
      assert :ok = Manager.enable_capability(:test_cap)
    end

    test "returns error when enabling unsupported capability", %{pid: pid} do
      assert {:error, :unsupported} = Manager.enable_capability(:nonexistent_cap)
    end
  end

  describe "capability querying" do
    test "returns capability value when supported", %{pid: pid} do
      :ok = Manager.detect_capability(:test_cap, "test_value")
      assert {:ok, "test_value"} = Manager.query_capability(:test_cap)
    end

    test "returns error for unsupported capability", %{pid: pid} do
      assert {:error, :unsupported} = Manager.query_capability(:nonexistent_cap)
    end
  end
end
