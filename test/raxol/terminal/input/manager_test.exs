defmodule Raxol.Terminal.Input.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Input.Manager

  setup do
    manager = Manager.new()
    {:ok, %{manager: manager}}
  end

  describe "new/1" do
    test "creates a new input manager with default options", %{manager: manager} do
      assert manager.buffer != nil
      assert manager.processor != nil
      assert manager.key_mappings == %{}
      assert length(manager.validation_rules) == 3
      assert manager.metrics.processed_events == 0
      assert manager.metrics.validation_failures == 0
      assert manager.metrics.buffer_overflows == 0
      assert manager.metrics.custom_mappings == 0
    end

    test 'creates manager with custom buffer size' do
      manager = Manager.new(buffer_size: 2048)
      assert manager.buffer.max_size == 2048
    end
  end

  describe "process_key_event/2" do
    test "processes valid key event", %{manager: manager} do
      event = %{
        key: "a",
        modifiers: [:shift],
        timestamp: System.system_time(:millisecond)
      }

      assert {:ok, updated_manager} = Manager.process_key_event(manager, event)
      assert updated_manager.metrics.processed_events == 1
    end

    test "rejects invalid key", %{manager: manager} do
      event = %{
        key: "",
        modifiers: [:shift],
        timestamp: System.system_time(:millisecond)
      }

      assert {:error, :validation_failed} =
               Manager.process_key_event(manager, event)

      assert manager.metrics.validation_failures == 1
    end

    test "rejects invalid modifiers", %{manager: manager} do
      event = %{
        key: "a",
        modifiers: [:invalid],
        timestamp: System.system_time(:millisecond)
      }

      assert {:error, :validation_failed} =
               Manager.process_key_event(manager, event)

      assert manager.metrics.validation_failures == 1
    end

    test "rejects invalid timestamp", %{manager: manager} do
      event = %{
        key: "a",
        modifiers: [:shift],
        timestamp: -1
      }

      assert {:error, :validation_failed} =
               Manager.process_key_event(manager, event)

      assert manager.metrics.validation_failures == 1
    end
  end

  describe "add_key_mapping/3" do
    test "adds custom key mapping", %{manager: manager} do
      updated_manager = Manager.add_key_mapping(manager, "a", "b")
      assert updated_manager.key_mappings["a"] == "b"
      assert updated_manager.metrics.custom_mappings == 1
    end

    test "applies key mapping during processing", %{manager: manager} do
      manager = Manager.add_key_mapping(manager, "a", "b")

      event = %{
        key: "a",
        modifiers: [:shift],
        timestamp: System.system_time(:millisecond)
      }

      {:ok, updated_manager} = Manager.process_key_event(manager, event)

      assert updated_manager.buffer.events |> List.first() |> Map.get(:key) ==
               "b"
    end
  end

  describe "add_validation_rule/2" do
    test "adds custom validation rule", %{manager: manager} do
      rule = fn event -> if event.key == "special", do: :ok, else: :error end
      updated_manager = Manager.add_validation_rule(manager, rule)
      assert length(updated_manager.validation_rules) == 4
    end

    test "applies custom validation rule", %{manager: manager} do
      rule = fn event -> if event.key == "special", do: :ok, else: :error end
      manager = Manager.add_validation_rule(manager, rule)

      event = %{
        key: "special",
        modifiers: [:shift],
        timestamp: System.system_time(:millisecond)
      }

      assert {:ok, _} = Manager.process_key_event(manager, event)

      event = %{
        key: "normal",
        modifiers: [:shift],
        timestamp: System.system_time(:millisecond)
      }

      assert {:error, :validation_failed} =
               Manager.process_key_event(manager, event)
    end
  end

  describe "get_metrics/1" do
    test "returns current metrics", %{manager: manager} do
      metrics = Manager.get_metrics(manager)
      assert metrics.processed_events == 0
      assert metrics.validation_failures == 0
      assert metrics.buffer_overflows == 0
      assert metrics.custom_mappings == 0
    end
  end

  describe "flush_buffer/1" do
    test "clears the input buffer", %{manager: manager} do
      event = %{
        key: "a",
        modifiers: [:shift],
        timestamp: System.system_time(:millisecond)
      }

      {:ok, manager} = Manager.process_key_event(manager, event)

      updated_manager = Manager.flush_buffer(manager)
      assert updated_manager.buffer.events == []
    end
  end
end
