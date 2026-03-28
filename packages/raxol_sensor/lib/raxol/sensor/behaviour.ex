defmodule Raxol.Sensor.Reading do
  @moduledoc """
  A timestamped sensor reading with quality indicator.
  """

  @type t :: %__MODULE__{
          sensor_id: atom(),
          timestamp: integer(),
          values: map(),
          quality: float(),
          metadata: map()
        }

  @enforce_keys [:sensor_id, :timestamp, :values]
  defstruct sensor_id: nil,
            timestamp: 0,
            values: %{},
            quality: 1.0,
            metadata: %{}
end

defmodule Raxol.Sensor.Behaviour do
  @moduledoc """
  Behaviour for sensor implementations.

  Sensors produce readings at a configurable sample rate. Each reading
  contains timestamped values with a quality indicator.
  """

  alias Raxol.Sensor.Reading

  @callback connect(opts :: keyword()) :: {:ok, term()} | {:error, term()}
  @callback read(state :: term()) ::
              {:ok, Reading.t(), term()} | {:error, term()}
  @callback disconnect(state :: term()) :: :ok

  @doc "Sample rate in milliseconds. Defaults to 100ms."
  @callback sample_rate() :: pos_integer()

  @optional_callbacks [sample_rate: 0]
end
