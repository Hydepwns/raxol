defmodule Raxol.Terminal.ManagerPerformanceTest do
  use ExUnit.Case
  use Raxol.Test.PerformanceHelper
  import Raxol.Test.PerformanceHelper

  alias Raxol.Terminal.Manager
  alias Raxol.Terminal.Emulator
  alias Raxol.Core.Events.Event

  setup do
    # Set up performance test environment
    {:ok, env} = setup_performance_test_env()

    # Create a test terminal
    {:ok, terminal} = Emulator.new(80, 24)

    # Start the terminal manager
    {:ok, manager_pid} =
      Manager.start_link(terminal: terminal, runtime_pid: self())

    # Add manager to context
    env = Map.put(env, :manager, manager_pid)
    env = Map.put(env, :terminal, terminal)

    {:ok, env}
  end

  describe "Terminal Manager Performance" do
    test "handles rapid input events efficiently", %{manager: manager} do
      # Generate a sequence of input events
      events = generate_test_events(1000)

      # Benchmark event processing
      results =
        benchmark(
          fn ->
            Enum.each(events, fn event ->
              Manager.process_event(manager, event)
            end)
          end,
          iterations: 100,
          warmup: 10
        )

      # Assert performance requirements
      assert_performance(results,
        # 1ms per event
        max_average_time: 1000,
        # 2ms for 95th percentile
        max_p95_time: 2000,
        min_iterations: 100
      )

      # Log results for analysis
      Raxol.Core.Runtime.Log.info(
        "Terminal Manager Event Processing Performance:\n#{format_benchmark_results(results)}"
      )
    end

    test "handles screen updates efficiently", %{
      manager: manager,
      _terminal: terminal
    } do
      # Generate screen update commands
      updates = generate_screen_updates(100)

      # Benchmark screen updates
      results =
        benchmark(
          fn ->
            Enum.each(updates, fn update ->
              Manager.update_screen(manager, update)
            end)
          end,
          iterations: 100,
          warmup: 10
        )

      # Assert performance requirements
      assert_performance(results,
        # 2ms per update
        max_average_time: 2000,
        # 5ms for 95th percentile
        max_p95_time: 5000,
        min_iterations: 100
      )

      # Log results for analysis
      Raxol.Core.Runtime.Log.info(
        "Terminal Manager Screen Update Performance:\n#{format_benchmark_results(results)}"
      )
    end

    test "handles concurrent operations efficiently", %{manager: manager} do
      # Create multiple concurrent operations
      operations = [
        fn -> Manager.process_event(manager, Event.key(:enter)) end,
        fn -> Manager.update_screen(manager, %{x: 0, y: 0, char: "X"}) end,
        fn -> Manager.get_terminal_state(manager) end
      ]

      # Benchmark concurrent operations
      results =
        benchmark(
          fn ->
            Task.async_stream(operations, fn op -> op.() end)
            |> Stream.run()
          end,
          iterations: 100,
          warmup: 10
        )

      # Assert performance requirements
      assert_performance(results,
        # 5ms for concurrent operations
        max_average_time: 5000,
        # 10ms for 95th percentile
        max_p95_time: 10000,
        min_iterations: 100
      )

      # Log results for analysis
      Raxol.Core.Runtime.Log.info(
        "Terminal Manager Concurrent Operations Performance:\n#{format_benchmark_results(results)}"
      )
    end
  end

  # Helper functions

  defp generate_test_events(count) do
    for _ <- 1..count do
      case :rand.uniform(3) do
        1 -> Event.key({:char, :rand.uniform(26) + ?a})
        2 -> Event.mouse(:left, {:rand.uniform(80), :rand.uniform(24)})
        3 -> Event.window(80, 24, :resize)
      end
    end
  end

  defp generate_screen_updates(count) do
    for _ <- 1..count do
      %{
        x: :rand.uniform(80) - 1,
        y: :rand.uniform(24) - 1,
        char: <<:rand.uniform(26) + ?a>>,
        fg: :rand.uniform(16),
        bg: :rand.uniform(16)
      }
    end
  end
end
