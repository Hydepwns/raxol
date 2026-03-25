defmodule Raxol.Sensor.FusionTest do
  use ExUnit.Case, async: true

  alias Raxol.Sensor.Fusion

  describe "batching and fusion" do
    test "batches readings and produces fused state" do
      {:ok, pid} = Fusion.start_link(name: nil, batch_window_ms: 30)
      Fusion.subscribe(pid)

      # Inject readings directly
      send(pid, {:sensor_reading, reading(:temp, %{value: 20.0}, 1.0)})
      send(pid, {:sensor_reading, reading(:temp, %{value: 22.0}, 1.0)})

      assert_receive {:fused_update, fused}, 200

      assert %{sensors: %{temp: sensor_data}} = fused
      assert sensor_data.reading_count == 2
      # Weighted average of 20.0 and 22.0 with equal quality
      assert_in_delta sensor_data.values.value, 21.0, 0.01
    end

    test "handles multiple sensors" do
      {:ok, pid} = Fusion.start_link(name: nil, batch_window_ms: 30)
      Fusion.subscribe(pid)

      send(pid, {:sensor_reading, reading(:temp, %{value: 25.0}, 1.0)})
      send(pid, {:sensor_reading, reading(:pressure, %{value: 1013.0}, 0.8)})

      assert_receive {:fused_update, fused}, 200

      assert Map.has_key?(fused.sensors, :temp)
      assert Map.has_key?(fused.sensors, :pressure)
    end

    test "quality-weighted averaging" do
      {:ok, pid} = Fusion.start_link(name: nil, batch_window_ms: 30)
      Fusion.subscribe(pid)

      # High quality reading: 10.0, low quality: 30.0
      send(pid, {:sensor_reading, reading(:s, %{value: 10.0}, 0.9)})
      send(pid, {:sensor_reading, reading(:s, %{value: 30.0}, 0.1)})

      assert_receive {:fused_update, fused}, 200

      # Weighted: (10*0.9 + 30*0.1) / (0.9+0.1) = 12.0
      assert_in_delta fused.sensors.s.values.value, 12.0, 0.01
    end

    test "threshold alerts" do
      thresholds = %{temp: %{value: {:gt, 50.0}}}

      {:ok, pid} =
        Fusion.start_link(name: nil, batch_window_ms: 30, thresholds: thresholds)

      Fusion.subscribe(pid)

      send(pid, {:sensor_reading, reading(:temp, %{value: 60.0}, 1.0)})

      assert_receive {:fused_update, fused}, 200

      assert [%{key: :value, op: :gt, threshold: 50.0}] =
               fused.sensors.temp.alerts
    end

    test "no alerts when under threshold" do
      thresholds = %{temp: %{value: {:gt, 50.0}}}

      {:ok, pid} =
        Fusion.start_link(name: nil, batch_window_ms: 30, thresholds: thresholds)

      Fusion.subscribe(pid)

      send(pid, {:sensor_reading, reading(:temp, %{value: 40.0}, 1.0)})

      assert_receive {:fused_update, fused}, 200
      assert fused.sensors.temp.alerts == []
    end

    test "empty batch does not notify" do
      {:ok, pid} = Fusion.start_link(name: nil, batch_window_ms: 20)
      Fusion.subscribe(pid)

      # Wait through one flush window with no readings
      refute_receive {:fused_update, _}, 50
    end

    test "get_fused_state returns last fused state" do
      {:ok, pid} = Fusion.start_link(name: nil, batch_window_ms: 20)

      send(pid, {:sensor_reading, reading(:x, %{value: 5.0}, 1.0)})
      Process.sleep(50)

      state = Fusion.get_fused_state(pid)
      assert Map.has_key?(state, :sensors)
    end
  end

  defp reading(sensor_id, values, quality) do
    %Raxol.Sensor.Reading{
      sensor_id: sensor_id,
      timestamp: System.monotonic_time(:millisecond),
      values: values,
      quality: quality,
      metadata: %{}
    }
  end
end
