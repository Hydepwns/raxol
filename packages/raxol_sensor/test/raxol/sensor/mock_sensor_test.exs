defmodule Raxol.Sensor.MockSensorTest do
  use ExUnit.Case, async: true

  alias Raxol.Sensor.MockSensor

  describe "connect/read/disconnect lifecycle" do
    test "connects with defaults and reads a value" do
      {:ok, state} = MockSensor.connect(sensor_id: :test)
      {:ok, reading, state2} = MockSensor.read(state)

      assert reading.sensor_id == :test
      assert is_map(reading.values)
      assert reading.quality == 1.0
      assert state2.tick == 1
    end

    test "increments tick on each read" do
      {:ok, state} = MockSensor.connect([])
      {:ok, _r1, state} = MockSensor.read(state)
      {:ok, _r2, state} = MockSensor.read(state)
      {:ok, _r3, state} = MockSensor.read(state)

      assert state.tick == 3
    end

    test "custom generator function" do
      gen = fn tick -> %{x: tick * 10} end
      {:ok, state} = MockSensor.connect(generator_fn: gen)
      {:ok, reading, _state} = MockSensor.read(state)

      assert reading.values == %{x: 0}
    end

    test "fail_after triggers error" do
      {:ok, state} = MockSensor.connect(fail_after: 2)
      {:ok, _r, state} = MockSensor.read(state)
      {:ok, _r, state} = MockSensor.read(state)
      assert {:error, :simulated_failure} = MockSensor.read(state)
    end

    test "disconnect returns :ok" do
      {:ok, state} = MockSensor.connect([])
      assert :ok = MockSensor.disconnect(state)
    end
  end
end
