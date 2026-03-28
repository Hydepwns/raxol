defmodule Raxol.Terminal.Commands.WindowHandlerBenchmark do
  use ExUnit.Case

  alias Raxol.Terminal.Commands.WindowHandler
  alias Raxol.Test.PerformanceHelper

  @moduletag :slow

  # Thresholds in ms, averaged over iterations.
  # Simple ops (struct updates): < 0.05ms avg
  # Resize ops (ScreenBuffer.resize allocation): < 5ms avg
  # Concurrent (all basic ops serially per iteration): < 1ms avg
  @simple_threshold_ms 0.05
  @resize_threshold_ms 5.0
  @concurrent_threshold_ms 1.0
  @iterations 500

  setup do
    {:ok, emulator: Raxol.Test.WindowTestHelper.create_test_emulator()}
  end

  describe "window handlers performance" do
    test "basic window operations", %{emulator: emulator} do
      for {params, name} <- Raxol.Test.WindowTestHelper.basic_window_operations() do
        PerformanceHelper.assert_operation_performance(
          fn -> WindowHandler.handle_t(emulator, params) end,
          name,
          @resize_threshold_ms,
          @iterations
        )
      end
    end

    test "window reporting operations are fast struct reads", %{emulator: emulator} do
      for {params, name} <- Raxol.Test.WindowTestHelper.reporting_operations() do
        PerformanceHelper.assert_operation_performance(
          fn -> WindowHandler.handle_t(emulator, params) end,
          name,
          @simple_threshold_ms,
          @iterations
        )
      end
    end

    test "parameter validation handles bad input", %{emulator: emulator} do
      for {params, name} <- Raxol.Test.WindowTestHelper.invalid_parameters() do
        PerformanceHelper.assert_operation_performance(
          fn -> WindowHandler.handle_t(emulator, params) end,
          name,
          @resize_threshold_ms,
          @iterations
        )
      end
    end

    test "buffer resize scales with size", %{emulator: emulator} do
      for {width, height} <- Raxol.Test.WindowTestHelper.test_window_sizes() do
        PerformanceHelper.assert_operation_performance(
          fn -> WindowHandler.handle_t(emulator, [4, width, height]) end,
          "#{width}x#{height} resize",
          @resize_threshold_ms,
          @iterations
        )
      end
    end

    test "concurrent operations", %{emulator: emulator} do
      operations =
        Enum.map(Raxol.Test.WindowTestHelper.basic_window_operations(), fn {params, _} ->
          fn -> WindowHandler.handle_t(emulator, params) end
        end)

      PerformanceHelper.assert_concurrent_performance(
        operations,
        "concurrent window",
        @concurrent_threshold_ms,
        @iterations
      )
    end
  end
end
