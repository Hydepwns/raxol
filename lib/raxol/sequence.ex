defmodule Raxol.Sequence do
  @moduledoc """
  Represents a sequence of commands for benchmarking and testing.
  """

  @enforce_keys [:name, :steps]
  defstruct [:name, :steps, :metadata]

  @type t :: %__MODULE__{
          name: String.t(),
          steps: list(String.t()),
          metadata: map() | nil
        }

  @doc """
  Creates a new sequence with the given name and steps.
  """
  @spec new(String.t(), list(String.t()), map()) :: t()
  def new(name, steps, metadata \\ %{}) do
    %__MODULE__{
      name: name,
      steps: steps,
      metadata: metadata
    }
  end

  @doc """
  Validates that a sequence has the required fields.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{name: name, steps: steps})
      when is_binary(name) and is_list(steps) do
    true
  end

  def valid?(_), do: false

  @doc """
  Gets the number of steps in a sequence.
  """
  @spec step_count(t()) :: non_neg_integer()
  def step_count(%__MODULE__{steps: steps}) do
    length(steps)
  end

  @doc """
  Adds metadata to a sequence.
  """
  @spec add_metadata(t(), map()) :: t()
  def add_metadata(%__MODULE__{} = sequence, metadata) when is_map(metadata) do
    %{sequence | metadata: Map.merge(sequence.metadata || %{}, metadata)}
  end

  @doc """
  Gets metadata from a sequence.
  """
  @spec get_metadata(t(), String.t() | atom(), any()) :: any()
  def get_metadata(%__MODULE__{metadata: metadata}, key, default \\ nil) do
    case metadata do
      nil -> default
      meta when is_map(meta) -> Map.get(meta, key, default)
      _ -> default
    end
  end
end
