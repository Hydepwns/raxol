defmodule Raxol.Terminal.ManagerPerformanceTest do
  use ExUnit.Case

  alias Raxol.Terminal.Manager
  alias Raxol.Terminal.Emulator
  alias Raxol.Core.Events.Event

  setup do
    # Create a test terminal
    terminal = Emulator.new()

    # Start the terminal manager (handle already_started case)
    manager_pid =
      case Manager.start_link(terminal: terminal, runtime_pid: self()) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    # Add manager to context
    {:ok, %{manager: manager_pid, terminal: terminal}}
  end

  describe "Terminal Manager Performance" do
    test "handles rapid input events efficiently", %{manager: manager} do
      # Generate a sequence of input events
      events = generate_test_events(1000)

      # Process events and measure time
      start_time = System.monotonic_time()

      Enum.each(events, fn event ->
        Manager.process_event(manager, event)
      end)

      end_time = System.monotonic_time()

      total_time =
        System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Assert that processing 1000 events takes less than 100ms
      assert total_time < 100,
             "Processing 1000 events took #{total_time}ms, expected < 100ms"
    end

    test "handles screen updates efficiently", %{manager: manager} do
      # Generate screen update commands
      updates = generate_screen_updates(100)

      # Process updates and measure time
      start_time = System.monotonic_time()

      Enum.each(updates, fn update ->
        Manager.update_screen(manager, update)
      end)

      end_time = System.monotonic_time()

      total_time =
        System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Assert that processing 100 updates takes less than 50ms
      assert total_time < 50,
             "Processing 100 screen updates took #{total_time}ms, expected < 50ms"
    end

    @tag :skip_on_ci
    test "handles concurrent operations efficiently", %{manager: manager} do
      # Create multiple concurrent operations
      operations = [
        fn -> Manager.process_event(manager, Event.key(:enter)) end,
        fn -> Manager.update_screen(manager, %{x: 0, y: 0, char: "X"}) end,
        fn -> Manager.get_terminal_state(manager) end
      ]

      # Process operations and measure time
      start_time = System.monotonic_time()

      Task.async_stream(operations, fn op -> op.() end)
      |> Stream.run()

      end_time = System.monotonic_time()

      total_time =
        System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Assert that concurrent operations take less than 20ms (increased for CI)
      # Note: macOS CI runners are slower than local machines
      assert total_time < 20,
             "Concurrent operations took #{total_time}ms, expected < 20ms"
    end
  end

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
