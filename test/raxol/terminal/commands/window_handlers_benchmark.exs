defmodule Raxol.Terminal.Commands.WindowHandlersBenchmark do
  use ExUnit.Case
  alias Raxol.Terminal.Commands.WindowHandlers
  alias Raxol.Test.PerformanceTestHelper
  alias Raxol.Test.WindowTestHelper

  setup do
    {:ok, emulator: WindowTestHelper.create_test_emulator()}
  end

  describe "window handlers performance" do
    test "basic window operations", %{emulator: emulator} do
      for {params, name} <- WindowTestHelper.basic_window_operations() do
        PerformanceTestHelper.assert_performance(
          fn -> WindowHandlers.handle_t(emulator, params) end,
          name
        )
      end
    end

    test "window reporting operations", %{emulator: emulator} do
      for {params, name} <- WindowTestHelper.reporting_operations() do
        PerformanceTestHelper.assert_performance(
          fn -> WindowHandlers.handle_t(emulator, params) end,
          name
        )
      end
    end

    test "parameter validation performance", %{emulator: emulator} do
      for {params, name} <- WindowTestHelper.invalid_parameters() do
        PerformanceTestHelper.assert_performance(
          fn -> WindowHandlers.handle_t(emulator, params) end,
          name
        )
      end
    end

    test "buffer resize performance", %{emulator: emulator} do
      for {width, height} <- WindowTestHelper.test_window_sizes() do
        PerformanceTestHelper.assert_performance(
          fn -> WindowHandlers.handle_t(emulator, [4, width, height]) end,
          "#{width}x#{height} resize",
          0.005
        )
      end
    end

    test "concurrent operations", %{emulator: emulator} do
      operations = Enum.map(WindowTestHelper.basic_window_operations(), fn {params, _} ->
        fn -> WindowHandlers.handle_t(emulator, params) end
      end)

      PerformanceTestHelper.assert_concurrent_performance(operations, "concurrent window")
    end
  end
end
