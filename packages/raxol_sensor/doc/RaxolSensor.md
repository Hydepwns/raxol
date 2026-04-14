# `RaxolSensor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol_sensor.ex#L1)

Sensor fusion framework for Elixir built on OTP.

Poll sensors at configurable intervals, buffer readings, fuse data with
weighted averaging and configurable thresholds, and render real-time HUD
widgets (gauges, sparklines, threat indicators, minimaps).

## Quick Start

    defmodule CpuSensor do
      @behaviour Raxol.Sensor.Behaviour

      @impl true
      def read(_opts) do
        # Return a sensor reading
        {:ok, %Raxol.Sensor.Reading{
          sensor_id: :cpu,
          value: get_cpu_usage(),
          unit: :percent,
          timestamp: System.monotonic_time(:millisecond)
        }}
      end
    end

    # Start the sensor supervisor, then register sensors
    Raxol.Sensor.Feed.start_link(sensor: CpuSensor, interval: 1000)

## Architecture

- `Raxol.Sensor.Behaviour` -- Sensor callback and `Reading` struct
- `Raxol.Sensor.Feed` -- GenServer: polling, buffering, error escalation
- `Raxol.Sensor.Fusion` -- GenServer: batching, weighted averaging, thresholds
- `Raxol.Sensor.HUD` -- Pure functional HUD widgets (gauge, sparkline, threat, minimap)
- `Raxol.Sensor.Supervisor` -- rest_for_one: Registry + DynSup + Fusion

## Optional Nx Backend

When `{:nx, "~> 0.9"}` is available, vectorized fusion operations use Nx tensors
for batch processing sensor readings.

## Documentation

See the [Sensor Fusion guide](https://hexdocs.pm/raxol_sensor/readme.html).

# `version`

Returns the version of RaxolSensor.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
