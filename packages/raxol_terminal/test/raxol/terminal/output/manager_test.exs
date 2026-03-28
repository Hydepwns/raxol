defmodule Raxol.Terminal.Output.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Output.Manager

  setup do
    manager = Manager.new()
    {:ok, %{manager: manager}}
  end

  describe "new/1" do
    test "creates a new output manager with default options", %{
      manager: manager
    } do
      assert manager.buffer != nil
      assert length(manager.format_rules) == 3
      assert manager.style_map["default"] != nil
      assert manager.batch_size == 100
      assert manager.metrics.processed_events == 0
      assert manager.metrics.batch_count == 0
      assert manager.metrics.format_applications == 0
      assert manager.metrics.style_applications == 0
    end

    test ~c"creates manager with custom options" do
      opts = [buffer_size: 2048, batch_size: 50]
      manager = Manager.new(opts)
      assert manager.buffer.max_size == 2048
      assert manager.batch_size == 50
    end
  end

  describe "process_output/2" do
    test "processes valid output event", %{manager: manager} do
      event = %{
        content: "Hello, World!",
        style: "default",
        timestamp: System.system_time(:millisecond),
        priority: 1
      }

      assert {:ok, updated_manager} = Manager.process_output(manager, event)
      assert updated_manager.metrics.processed_events == 1
    end

    test "rejects invalid event", %{manager: manager} do
      event = %{
        content: "Hello",
        style: "invalid",
        timestamp: -1,
        priority: "high"
      }

      assert {:error, :invalid_event} = Manager.process_output(manager, event)
    end

    test "applies formatting rules", %{manager: manager} do
      event = %{
        content: "\x1b[1mBold\x1b[0m",
        style: "default",
        timestamp: System.system_time(:millisecond),
        priority: 1
      }

      {:ok, updated_manager} = Manager.process_output(manager, event)
      assert updated_manager.metrics.format_applications > 0
    end
  end

  describe "process_batch/2" do
    test "processes batch of events", %{manager: manager} do
      events = [
        %{
          content: "Event 1",
          style: "default",
          timestamp: System.system_time(:millisecond),
          priority: 1
        },
        %{
          content: "Event 2",
          style: "default",
          timestamp: System.system_time(:millisecond),
          priority: 2
        }
      ]

      assert {:ok, updated_manager} = Manager.process_batch(manager, events)
      assert updated_manager.metrics.batch_count == 1
      assert updated_manager.metrics.processed_events == 2
    end

    test "rejects batch exceeding size limit", %{manager: manager} do
      events =
        Enum.map(1..101, fn i ->
          %{
            content: "Event #{i}",
            style: "default",
            timestamp: System.system_time(:millisecond),
            priority: i
          }
        end)

      assert {:error, :invalid_event} = Manager.process_batch(manager, events)
    end
  end

  describe "add_style/3" do
    test "adds custom style", %{manager: manager} do
      style = %{
        foreground: "red",
        background: "black",
        bold: true,
        italic: false,
        underline: true
      }

      updated_manager = Manager.add_style(manager, "error", style)
      assert updated_manager.style_map["error"] == style
      assert updated_manager.metrics.style_applications == 1
    end

    test "applies custom style to output", %{manager: manager} do
      style = %{
        foreground: "red",
        background: nil,
        bold: true,
        italic: false,
        underline: false
      }

      manager = Manager.add_style(manager, "error", style)

      event = %{
        content: "Error message",
        style: "error",
        timestamp: System.system_time(:millisecond),
        priority: 1
      }

      {:ok, updated_manager} = Manager.process_output(manager, event)
      assert updated_manager.metrics.style_applications > 0
    end
  end

  describe "add_format_rule/2" do
    test "adds custom formatting rule", %{manager: manager} do
      rule = fn content -> String.upcase(content) end
      updated_manager = Manager.add_format_rule(manager, rule)
      assert length(updated_manager.format_rules) == 4
      assert updated_manager.metrics.format_applications == 1
    end

    test "applies custom formatting rule", %{manager: manager} do
      rule = fn content -> String.upcase(content) end
      manager = Manager.add_format_rule(manager, rule)

      event = %{
        content: "hello",
        style: "default",
        timestamp: System.system_time(:millisecond),
        priority: 1
      }

      {:ok, updated_manager} = Manager.process_output(manager, event)
      assert updated_manager.metrics.format_applications > 0
    end
  end

  describe "get_metrics/1" do
    test "returns current metrics", %{manager: manager} do
      metrics = Manager.get_metrics(manager)
      assert metrics.processed_events == 0
      assert metrics.batch_count == 0
      assert metrics.format_applications == 0
      assert metrics.style_applications == 0
    end
  end

  describe "flush_buffer/1" do
    test "clears the output buffer", %{manager: manager} do
      event = %{
        content: "Test content",
        style: "default",
        timestamp: System.system_time(:millisecond),
        priority: 1
      }

      {:ok, manager} = Manager.process_output(manager, event)

      updated_manager = Manager.flush_buffer(manager)
      assert updated_manager.buffer.events == []
    end
  end
end
