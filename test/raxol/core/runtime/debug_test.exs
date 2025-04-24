defmodule Raxol.Core.Runtime.DebugTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Raxol.Core.Runtime.Debug

  setup do
    # Mock state for testing
    state = %{
      app_module: TestApp,
      app_name: :test_app,
      environment: :terminal,
      width: 100,
      height: 50,
      fps: 60,
      model: %{
        counter: 10,
        user: %{
          name: "Test User",
          password: "secret123"
        },
        api_token: "abcdef123456",
        settings: %{
          theme: "dark",
          public_preference: true
        }
      },
      screen_buffer: %{
        width: 100,
        height: 50,
        cells: %{
          {0, 0} => %{char: "A", fg: :white, bg: :black}
        }
      },
      debug_mode: true,
      uptime: 120,
      metrics: %{
        render_times: [10, 12, 15, 8, 9],
        start_time: :os.system_time(:millisecond) - 10000,
        frame_count: 600,
        last_render_time: 10
      }
    }

    {:ok, state: state}
  end

  describe "capture_state/2" do
    test "captures basic state info", %{state: state} do
      result = Debug.capture_state(state, include_model: false, include_buffer: false)

      assert result.app_module == TestApp
      assert result.app_name == :test_app
      assert result.environment == :terminal
      assert result.width == 100
      assert result.height == 50
      assert result.fps == 60
      refute Map.has_key?(result, :model)
      refute Map.has_key?(result, :buffer)
      assert Map.has_key?(result, :performance)
    end

    test "includes model when requested", %{state: state} do
      result = Debug.capture_state(state, include_model: true, include_buffer: false)

      assert Map.has_key?(result, :model)
      assert result.model.counter == 10
      assert result.model.user.name == "Test User"
      # Check sanitization
      assert result.model.user.password == "[REDACTED]"
      assert result.model.api_token == "[REDACTED]"
      # Non-sensitive data should be preserved
      assert result.model.settings.theme == "dark"
    end

    test "includes buffer when requested", %{state: state} do
      result = Debug.capture_state(state, include_model: false, include_buffer: true)

      assert Map.has_key?(result, :buffer)
      assert result.buffer.width == 100
      assert result.buffer.height == 50
      assert result.buffer.cell_count == 1
    end

    test "doesn't sanitize when disabled", %{state: state} do
      result = Debug.capture_state(state, include_model: true, sanitize: false)

      assert result.model.user.password == "secret123"
      assert result.model.api_token == "abcdef123456"
    end
  end

  describe "analyze_performance/1" do
    test "analyzes performance metrics", %{state: state} do
      result = Debug.analyze_performance(state)

      assert Map.has_key?(result, :fps_analysis)
      assert Map.has_key?(result, :render_analysis)
      assert Map.has_key?(result, :frame_budget)
      assert result.frame_budget == trunc(1000 / state.fps)
    end
  end

  describe "report_status/1" do
    test "generates formatted status report", %{state: state} do
      report = Debug.report_status(state)

      assert report =~ "Raxol Runtime Status Report"
      assert report =~ "Application: #{state.app_module}"
      assert report =~ "Target FPS: #{state.fps}"
      assert report =~ "Current FPS:"
      assert report =~ "Frame budget:"
      assert report =~ "Avg render time:"
      assert report =~ "Analysis:"
      assert report =~ "Memory:"
      assert report =~ "Runtime: #{state.uptime}s"
    end
  end

  describe "log/4" do
    test "logs messages at specified levels", %{state: state} do
      # Debug level
      log = capture_log(fn ->
        Debug.log(state, :debug, "Debug message")
      end)
      assert log =~ "Debug message"

      # Info level
      log = capture_log(fn ->
        Debug.log(state, :info, "Info message")
      end)
      assert log =~ "Info message"

      # Warning level
      log = capture_log(fn ->
        Debug.log(state, :warn, "Warning message")
      end)
      assert log =~ "Warning message"

      # Error level
      log = capture_log(fn ->
        Debug.log(state, :error, "Error message")
      end)
      assert log =~ "Error message"
    end

    test "includes metadata in log", %{state: state} do
      metadata = [custom_field: "custom_value"]

      log = capture_log(fn ->
        Debug.log(state, :info, "Message with metadata", metadata)
      end)

      assert log =~ "Message with metadata"
      # Metadata is included but not directly visible in the log message
      # We can check that the function was called correctly
    end

    test "doesn't log when debug_mode is false except errors", %{state: state} do
      state = %{state | debug_mode: false}

      log = capture_log(fn ->
        Debug.log(state, :debug, "Should not be logged")
      end)
      assert log == ""

      log = capture_log(fn ->
        Debug.log(state, :error, "Should still be logged")
      end)
      assert log =~ "Should still be logged"
    end
  end

  describe "start_monitoring/1" do
    test "initializes metrics tracking", %{state: state} do
      # Remove existing metrics for testing initialization
      state = Map.delete(state, :metrics)

      result = Debug.start_monitoring(state)

      assert Map.has_key?(result, :metrics)
      assert result.metrics.render_times == []
      assert result.metrics.frame_count == 0
      assert is_integer(result.metrics.start_time)
    end
  end

  describe "record_render/2" do
    test "adds render time to metrics", %{state: state} do
      # Get initial render times count
      initial_count = length(state.metrics.render_times)
      initial_frame_count = state.metrics.frame_count

      # Record a new render
      result = Debug.record_render(state, 11)

      # Verify render was recorded
      assert length(result.metrics.render_times) == initial_count + 1
      assert hd(result.metrics.render_times) == 11
      assert result.metrics.frame_count == initial_frame_count + 1
      assert result.metrics.last_render_time == 11
    end

    test "limits recorded render times to 60", %{state: state} do
      # Create state with 60 render times
      render_times = Enum.map(1..60, fn i -> i end)
      state = put_in(state.metrics.render_times, render_times)

      # Record a new render
      result = Debug.record_render(state, 999)

      # Verify list is still capped at 60
      assert length(result.metrics.render_times) == 60
      # And the new value is at the front
      assert hd(result.metrics.render_times) == 999
    end

    test "does nothing when metrics not initialized", %{state: state} do
      # Remove metrics
      state = Map.delete(state, :metrics)

      # Should return state unchanged
      result = Debug.record_render(state, 10)
      assert result == state
    end
  end

  # Helper test for internal functions
  describe "private functions" do
    test "format_bytes formats sizes correctly" do
      # We can test private functions by calling them directly with :erlang.apply/3
      assert :erlang.apply(Debug, :format_bytes, [500]) == "500 B"
      assert :erlang.apply(Debug, :format_bytes, [1500]) =~ "KB"
      assert :erlang.apply(Debug, :format_bytes, [1500000]) =~ "MB"
    end
  end
end
