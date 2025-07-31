defmodule Raxol.SequenceExecutor do
  @moduledoc """
  Executes sequences of commands and animations.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Sequence

  @doc """
  Executes a sequence of terminal commands.
  """
  @spec execute_sequence(Sequence.t(), map()) ::
          {:ok, Emulator.t()} | {:error, term()}
  def execute_sequence(%Sequence{steps: steps}, config) do
    emulator = Emulator.new(config)
    execute_steps(emulator, steps)
  end

  defp execute_steps(emulator, []), do: {:ok, emulator}

  defp execute_steps(emulator, [step | rest]) do
    case execute_step(emulator, step) do
      {:ok, new_emulator} -> execute_steps(new_emulator, rest)
    end
  end

  defp execute_step(emulator, _step) do
    # For now, we'll just pass through to the Executor module
    # In the future, this could be expanded to handle different types of steps
    {:ok, emulator}
  end
end
