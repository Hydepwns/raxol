defmodule Raxol.Sensor.MockSensor do
  @moduledoc """
  Configurable test/demo sensor.

  Options:
  - `sensor_id` -- atom identifier (default: `:mock`)
  - `sample_rate` -- poll interval in ms (default: 100)
  - `generator_fn` -- `(tick :: integer()) -> map()` producing values
  - `fail_after` -- fail read after N ticks (for error testing)
  """

  @behaviour Raxol.Sensor.Behaviour

  alias Raxol.Sensor.Reading

  defstruct sensor_id: :mock,
            sample_rate: 100,
            generator_fn: nil,
            fail_after: nil,
            tick: 0

  @type t :: %__MODULE__{
          sensor_id: atom(),
          sample_rate: pos_integer(),
          generator_fn: (integer() -> map()),
          fail_after: non_neg_integer() | nil,
          tick: non_neg_integer()
        }

  @impl true
  @spec connect(keyword()) :: {:ok, t()}
  def connect(opts) do
    state = %__MODULE__{
      sensor_id: Keyword.get(opts, :sensor_id, :mock),
      sample_rate: Keyword.get(opts, :sample_rate, 100),
      generator_fn: Keyword.get(opts, :generator_fn, &default_generator/1),
      fail_after: Keyword.get(opts, :fail_after),
      tick: 0
    }

    {:ok, state}
  end

  @impl true
  @spec read(t()) :: {:ok, Reading.t(), t()} | {:error, :simulated_failure}
  def read(%__MODULE__{fail_after: n, tick: tick})
      when is_integer(n) and tick >= n do
    {:error, :simulated_failure}
  end

  def read(%__MODULE__{} = state) do
    reading = %Reading{
      sensor_id: state.sensor_id,
      timestamp: System.monotonic_time(:millisecond),
      values: state.generator_fn.(state.tick),
      quality: 1.0,
      metadata: %{}
    }

    {:ok, reading, %__MODULE__{state | tick: state.tick + 1}}
  end

  @impl true
  @spec disconnect(term()) :: :ok
  def disconnect(_state), do: :ok

  @impl true
  def sample_rate, do: 100

  defp default_generator(tick) do
    %{value: :math.sin(tick * 0.1) + :rand.uniform() * 0.1}
  end
end
