defmodule Raxol.Terminal.State.ManagerTest do
  use ExUnit.Case
  alias Raxol.Terminal.State.Manager
  alias Raxol.Test.TestUtils

  describe "new/0" do
    test "creates a new state manager with default values" do
      state = Manager.new()
      assert state.modes == %{}
      assert state.attributes == %{}
      assert state.state_stack == []
    end
  end

  describe "get_mode/2" do
    test "returns nil for non-existent mode" do
      emulator = UnifiedTestHelper.create_test_emulator()
      assert Manager.get_mode(emulator, :non_existent) == nil
    end

    test "returns mode value when it exists" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.set_mode(emulator, :test_mode, true)
      assert Manager.get_mode(emulator, :test_mode) == true
    end
  end

  describe "set_mode/3" do
    test "sets a new mode value" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.set_mode(emulator, :test_mode, true)
      assert Manager.get_mode(emulator, :test_mode) == true
    end

    test "updates existing mode value" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.set_mode(emulator, :test_mode, true)
      emulator = Manager.set_mode(emulator, :test_mode, false)
      assert Manager.get_mode(emulator, :test_mode) == false
    end
  end

  describe "get_attribute/2" do
    test "returns nil for non-existent attribute" do
      emulator = UnifiedTestHelper.create_test_emulator()
      assert Manager.get_attribute(emulator, :non_existent) == nil
    end

    test "returns attribute value when it exists" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.set_attribute(emulator, :test_attr, "value")
      assert Manager.get_attribute(emulator, :test_attr) == "value"
    end
  end

  describe "set_attribute/3" do
    test "sets a new attribute value" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.set_attribute(emulator, :test_attr, "value")
      assert Manager.get_attribute(emulator, :test_attr) == "value"
    end

    test "updates existing attribute value" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.set_attribute(emulator, :test_attr, "old")
      emulator = Manager.set_attribute(emulator, :test_attr, "new")
      assert Manager.get_attribute(emulator, :test_attr) == "new"
    end
  end

  describe "state stack operations" do
    test "push_state/1 adds current state to stack" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.set_mode(emulator, :test_mode, true)
      emulator = Manager.push_state(emulator)
      assert length(Manager.get_state_stack(emulator)) == 1
    end

    test "pop_state/1 returns previous state" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.set_mode(emulator, :test_mode, true)
      emulator = Manager.push_state(emulator)
      emulator = Manager.set_mode(emulator, :test_mode, false)
      {emulator, state} = Manager.pop_state(emulator)
      assert Manager.get_mode(emulator, :test_mode) == false
      assert Manager.get_mode(%{emulator | state: state}, :test_mode) == true
    end

    test "pop_state/1 returns nil when stack is empty" do
      emulator = UnifiedTestHelper.create_test_emulator()
      {emulator, state} = Manager.pop_state(emulator)
      assert state == nil
    end

    test "clear_state_stack/1 removes all states from stack" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.push_state(emulator)
      emulator = Manager.push_state(emulator)
      emulator = Manager.clear_state_stack(emulator)
      assert Manager.get_state_stack(emulator) == []
    end
  end

  describe "reset_state/1" do
    test "resets state to initial values" do
      emulator = UnifiedTestHelper.create_test_emulator()
      emulator = Manager.set_mode(emulator, :test_mode, true)
      emulator = Manager.set_attribute(emulator, :test_attr, "value")
      emulator = Manager.push_state(emulator)
      emulator = Manager.reset_state(emulator)
      assert Manager.get_mode(emulator, :test_mode) == nil
      assert Manager.get_attribute(emulator, :test_attr) == nil
      assert Manager.get_state_stack(emulator) == []
    end
  end
end
