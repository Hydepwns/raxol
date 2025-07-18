defmodule Raxol.Terminal.ANSI.Parser do
  @moduledoc """
  Provides comprehensive parsing for ANSI escape sequences.
  Determines the type of sequence and extracts its parameters.
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.ANSI.{StateMachine, Monitor}

  @type sequence_type :: :csi | :osc | :sos | :pm | :apc | :esc | :text

  @type sequence :: %{
          type: sequence_type(),
          command: String.t(),
          params: list(String.t()),
          intermediate: String.t(),
          final: String.t(),
          text: String.t()
        }

  @doc """
  Parses a string containing ANSI escape sequences.
  Returns a list of parsed sequences.
  """
  @spec parse(String.t()) :: list(sequence())
  def parse(input) do
    try do
      state = StateMachine.new()
      {_state, sequences} = StateMachine.process(state, input)
      Monitor.record_sequence(input)
      sequences
    rescue
      e ->
        Monitor.record_error(input, "Parse error: #{inspect(e)}", %{
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        })

        log_parse_error(e, input)
        []
    end
  end

  @doc """
  Parses a single ANSI escape sequence.
  Returns a map containing the sequence type and parameters.
  """
  @spec parse_sequence(String.t()) :: sequence() | nil
  def parse_sequence(input) do
    case parse(input) do
      [sequence] -> sequence
      _ -> nil
    end
  end

  @doc """
  Determines if a string contains ANSI escape sequences.
  """
  @spec contains_ansi?(String.t()) :: boolean()
  def contains_ansi?(input) do
    String.contains?(input, "\e")
  end

  @doc """
  Strips all ANSI escape sequences from a string.
  """
  @spec strip_ansi(String.t()) :: String.t()
  def strip_ansi(input) do
    state = StateMachine.new()
    {_state, sequences} = StateMachine.process(state, input)
    Enum.map_join(sequences, "", & &1.text)
  end

  defp log_parse_error(reason, input) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "ANSI Parse Error: #{inspect(reason)}",
      %{input: input}
    )
  end
end
