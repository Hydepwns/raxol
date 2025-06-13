defmodule Raxol.Terminal.ANSI.SequenceParser do
  @moduledoc """
  Helper module for parsing ANSI escape sequences.

  This module provides common utilities for parsing and handling ANSI sequences,
  extracted from duplicate implementations in other ANSI-related modules.
  """

  @doc """
  Parses parameters from an ANSI sequence.

  Splits the parameter string by semicolons and converts them to integers.

  ## Returns

  * `{:ok, params}` - Successfully parsed parameters
  * `:error` - Failed to parse parameters
  """
  @spec parse_params(binary()) :: {:ok, list(integer())} | :error
  def parse_params(params) do
    case String.split(params, ";", trim: true) do
      [] ->
        {:ok, []}

      param_strings ->
        case Enum.map(param_strings, &Integer.parse/1) do
          list when length(list) == length(param_strings) ->
            {:ok, Enum.map(list, fn {num, _} -> num end)}

          _ ->
            :error
        end
    end
  end

  @doc """
  Generic parser for ANSI sequences that follow the pattern: params + operation code.

  ## Parameters

  * `sequence` - The binary sequence to parse
  * `operation_decoder` - Function to decode operation from character code

  ## Returns

  * `{:ok, operation, params}` - Successfully parsed sequence
  * `:error` - Failed to parse sequence
  """
  @spec parse_sequence(binary(), function()) ::
          {:ok, atom(), list(integer())} | :error
  def parse_sequence(sequence, operation_decoder) do
    case Regex.run(~r/^([0-9;]*)([a-zA-Z])$/, sequence, capture: :all_but_first) do
      [param_string, command_char] ->
        if String.length(command_char) == 1 do
          case parse_params(param_string) do
            {:ok, parsed_params} ->
              operation_code = :binary.first(command_char)
              {:ok, operation_decoder.(operation_code), parsed_params}

            :error ->
              :error
          end
        else
          :error
        end

      _ ->
        # Sequence doesn't match the expected format (params + command)
        :error
    end
  end
end
