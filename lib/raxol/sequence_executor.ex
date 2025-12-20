defmodule Raxol.SequenceExecutor do
  @moduledoc """
  Executes sequences of commands and animations.
  """

  alias Raxol.Sequence
  alias Raxol.Terminal.Emulator

  @doc """
  Executes a sequence of terminal commands.
  """
  def execute_sequence(%Sequence{steps: steps}, config) do
    width = Map.get(config, :width, 80)
    height = Map.get(config, :height, 24)
    emulator = Emulator.new(width, height)
    execute_steps(emulator, steps)
  end

  defp execute_steps(emulator, []), do: {:ok, emulator}

  defp execute_steps(emulator, [step | rest]) do
    {:ok, new_emulator} = execute_step(emulator, step)
    execute_steps(new_emulator, rest)
  end

  defp execute_step(emulator, _step) do
    # For now, we'll just pass through to the Executor module
    # In the future, this could be expanded to handle different types of steps
    {:ok, emulator}
  end
end
