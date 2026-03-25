defmodule Raxol.Swarm.CRDT.LWWRegister do
  @moduledoc """
  Last-Writer-Wins Register CRDT.

  Each value is tagged with a timestamp. On merge, the entry with the
  highest timestamp wins. Ties are broken by lexicographic node name.

  Timestamps use microseconds for ordering precision. Other swarm modules
  use milliseconds for intervals/thresholds -- do not compare across units.
  """

  @behaviour Raxol.Swarm.CRDT

  @type t :: %__MODULE__{
          value: term(),
          timestamp: integer(),
          node: node()
        }

  defstruct [:value, :timestamp, :node]

  @doc "Creates a new register with the given value."
  @spec new(term(), node()) :: t()
  def new(value, node \\ Node.self()) do
    %__MODULE__{
      value: value,
      timestamp: System.monotonic_time(:microsecond),
      node: node
    }
  end

  @doc "Updates the register value, advancing the timestamp."
  @spec update(t(), term()) :: t()
  def update(%__MODULE__{} = reg, value) do
    %__MODULE__{
      reg
      | value: value,
        timestamp: System.monotonic_time(:microsecond)
    }
  end

  @doc """
  Merges two registers. Keeps the one with the highest timestamp.
  Ties broken by lexicographic node name comparison.
  """
  @impl Raxol.Swarm.CRDT
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = a, %__MODULE__{} = b) do
    cond do
      a.timestamp > b.timestamp -> a
      b.timestamp > a.timestamp -> b
      a.node >= b.node -> a
      true -> b
    end
  end

  @doc "Returns the current value."
  @spec value(t()) :: term()
  def value(%__MODULE__{value: val}), do: val
end
