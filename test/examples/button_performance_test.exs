defmodule Raxol.Examples.ButtonPerformanceTest do
  use ExUnit.Case
  use Raxol.Test.Performance

  alias Raxol.Examples.Button

  describe "render performance" do
    test "renders quickly for simple button" do
      button = setup_benchmark_component(Button)
      
      assert_render_time button, fn ->
        render_iterations(button, 1000)
      end, under: 50 # milliseconds
    end

    test "renders efficiently with long label" do
      button = setup_benchmark_component(Button, %{
        label: String.duplicate("Very Long Button Label ", 10)
      })
      
      assert_render_time button, fn ->
        render_iterations(button, 1000)
      end, under: 75 # milliseconds
    end

    test "maintains performance with different themes" do
      button = setup_benchmark_component(Button)
      themes = generate_test_themes(10)
      
      Enum.each(themes, fn theme ->
        button = %{button | state: %{button.state | theme: theme}}
        assert_render_time button, fn ->
          render_iterations(button, 100)
        end, under: 10 # milliseconds
      end)
    end
  end

  describe "memory usage" do
    test "maintains low memory footprint" do
      button = setup_benchmark_component(Button)
      
      {:ok, usage} = assert_memory_usage button, fn component ->
        render_iterations(component, 1000)
      end, under: 1024 * 1024 # 1MB
      
      # Verify specific memory metrics
      assert usage.processes < 512 * 1024, "Process memory too high"
      assert usage.binary < 256 * 1024, "Binary memory too high"
    end

    test "handles large datasets efficiently" do
      button = setup_benchmark_component(Button, %{
        data: generate_large_dataset()
      })
      
      assert_memory_usage button, fn component ->
        render_with_dataset(component)
      end, under: 2 * 1024 * 1024 # 2MB
    end

    test "cleans up resources properly" do
      button = setup_benchmark_component(Button)
      
      {:ok, metrics} = assert_stable_resource_usage button, duration: 1000
      assert metrics.memory.stable?, "Memory usage is not stable"
      assert metrics.processes.stable?, "Process count is not stable"
    end
  end

  describe "event handling" do
    test "processes click events quickly" do
      button = setup_benchmark_component(Button)
      
      assert_event_latency button, {:click, {1, 1}}, under: 1 # millisecond
    end

    test "handles rapid event sequences" do
      button = setup_benchmark_component(Button)
      events = generate_event_sequence(100)
      
      Enum.each(events, fn event ->
        assert_event_latency button, event, under: 2 # milliseconds
      end)
    end
  end

  describe "regression testing" do
    test "maintains baseline performance" do
      button = setup_benchmark_component(Button)
      assert_no_performance_regression(button, "button_baseline")
    end

    test "meets all performance requirements" do
      button = setup_benchmark_component(Button)
      
      assert_performance_requirements button, %{
        render_time: 50,    # ms
        memory_usage: 1024 * 1024, # 1MB
        event_latency: 1    # ms
      }
    end
  end

  # Test Helpers

  defp render_iterations(component, count) do
    Enum.each(1..count, fn _ ->
      capture_render(component)
    end)
  end

  defp render_with_dataset(component) do
    Enum.each(1..10, fn _ ->
      capture_render(component)
      Process.sleep(10) # Simulate some processing
    end)
  end

  defp generate_test_themes(count) do
    colors = [:red, :green, :blue, :yellow, :magenta, :cyan]
    
    Enum.map(1..count, fn i ->
      %{
        normal: %{
          fg: Enum.at(colors, rem(i, length(colors))),
          bg: :black,
          style: :bold
        },
        disabled: %{
          fg: :gray,
          bg: :black,
          style: :dim
        }
      }
    end)
  end

  defp generate_large_dataset do
    Enum.map(1..1000, fn i ->
      %{
        id: "item_#{i}",
        value: "value_#{i}",
        metadata: %{
          timestamp: System.system_time(),
          sequence: i,
          data: String.duplicate("data", 100)
        }
      }
    end)
  end

  defp generate_event_sequence(count) do
    Enum.map(1..count, fn i ->
      case rem(i, 3) do
        0 -> {:click, {rem(i, 10), rem(i, 10)}}
        1 -> :focus
        2 -> :blur
      end
    end)
  end
end 