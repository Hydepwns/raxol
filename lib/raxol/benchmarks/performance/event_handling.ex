defmodule Raxol.Benchmarks.Performance.EventHandling do
  @moduledoc '''
  Event handling performance benchmark functions for Raxol.
  '''

  @doc '''
  Benchmarks event handling latency for different event types and volumes.

  Tests event handling for:
  - Keyboard events
  - Mouse events
  - Window events
  - Custom events
  - High-volume event bursts
  '''
  def benchmark_event_handling do
    IO.puts("Benchmarking event handling latency...")

    # Set up event testing environment
    event_manager = setup_event_test_environment()

    # Measure event handling latency for different event types
    keyboard_latency = measure_event_latency(event_manager, :keyboard, 1000)
    mouse_latency = measure_event_latency(event_manager, :mouse, 1000)
    window_latency = measure_event_latency(event_manager, :window, 100)
    custom_latency = measure_event_latency(event_manager, :custom, 1000)

    # Measure burst handling (100 events dispatched rapidly)
    burst_latency = measure_burst_event_latency(event_manager, 100)

    # Calculate average and percentiles
    results = %{
      keyboard_event_latency_μs: keyboard_latency,
      mouse_event_latency_μs: mouse_latency,
      window_event_latency_μs: window_latency,
      custom_event_latency_μs: custom_latency,
      burst_events_latency_μs: burst_latency,
      events_per_second: calculate_events_per_second(keyboard_latency)
    }

    IO.puts("✓ Event handling benchmarks complete")
    results
  end

  # Helper functions moved from Raxol.Benchmarks.Performance

  defp setup_event_test_environment do
    # Simulate setting up an event manager and environment
    # Return a mock event manager for testing
    %{handlers: %{}, subscriptions: []}
  end

  defp measure_event_latency(event_manager, event_type, iterations) do
    # Create test event based on type
    event = create_test_event(event_type)

    {time, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          # Simulate event dispatch and handling
          dispatch_event(event_manager, event)
        end
      end)

    # Return average microseconds per event
    time / iterations
  end

  defp create_test_event(:keyboard) do
    %{type: :keyboard, key: :enter, modifiers: []}
  end

  defp create_test_event(:mouse) do
    %{type: :mouse, x: 10, y: 10, button: :left, action: :click}
  end

  defp create_test_event(:window) do
    %{type: :window, action: :resize, width: 80, height: 24}
  end

  defp create_test_event(:custom) do
    %{type: :custom, name: :test_event, data: %{value: 42}}
  end

  defp dispatch_event(event_manager, event) do
    # Simulate the work of dispatching an event
    # Find matching handlers
    matching_handlers =
      event_manager.handlers
      |> Map.get(event.type, [])
      |> Enum.filter(fn handler ->
        handler.type == event.type
      end)

    # Process event through handlers
    Enum.each(matching_handlers, fn handler ->
      # Simulate handler execution
      _ = {handler, event}
    end)

    # Return updated manager with event history
    event_manager
  end

  defp measure_burst_event_latency(event_manager, event_count) do
    # Create a burst of mixed events
    events =
      for i <- 1..event_count do
        event_type =
          case rem(i, 4) do
            0 -> :keyboard
            1 -> :mouse
            2 -> :window
            3 -> :custom
          end

        create_test_event(event_type)
      end

    # Measure time to process all events
    {time, _} =
      :timer.tc(fn ->
        Enum.reduce(events, event_manager, fn event, manager ->
          dispatch_event(manager, event)
        end)
      end)

    # Return average microseconds per event in burst
    time / event_count
  end

  defp calculate_events_per_second(event_latency_μs) do
    # Calculate how many events can be processed per second
    trunc(1_000_000 / event_latency_μs)
  end
end
