defmodule Raxol.Terminal.Commands.WindowHandlerBenchmark do
  use ExUnit.Case
  alias Raxol.Terminal.Commands.WindowHandler
  alias Raxol.Test.PerformanceHelper
  alias Raxol.Test.WindowTestHelper

  setup do
    {:ok, emulator: WindowUnifiedTestHelper.create_test_emulator()}
  end

  describe "window handlers performance" do
    test "basic window operations", %{emulator: emulator} do
      for {params, name} <- WindowUnifiedTestHelper.basic_window_operations() do
        PerformanceHelper.assert_performance(
          fn -> WindowHandler.handle_t(emulator, params) end,
          name
        )
      end
    end

    test "window reporting operations", %{emulator: emulator} do
      for {params, name} <- WindowUnifiedTestHelper.reporting_operations() do
        PerformanceHelper.assert_performance(
          fn -> WindowHandler.handle_t(emulator, params) end,
          name
        )
      end
    end

    test "parameter validation performance", %{emulator: emulator} do
      for {params, name} <- WindowUnifiedTestHelper.invalid_parameters() do
        PerformanceHelper.assert_performance(
          fn -> WindowHandler.handle_t(emulator, params) end,
          name
        )
      end
    end

    test "buffer resize performance", %{emulator: emulator} do
      for {width, height} <- WindowUnifiedTestHelper.test_window_sizes() do
        PerformanceHelper.assert_performance(
          fn -> WindowHandler.handle_t(emulator, [4, width, height]) end,
          "#{width}x#{height} resize",
          0.005
        )
      end
    end

    test "concurrent operations", %{emulator: emulator} do
      operations =
        Enum.map(WindowUnifiedTestHelper.basic_window_operations(), fn {params, _} ->
          fn -> WindowHandler.handle_t(emulator, params) end
        end)

      PerformanceHelper.assert_concurrent_performance(
        operations,
        "concurrent window"
      )
    end
  end
end
