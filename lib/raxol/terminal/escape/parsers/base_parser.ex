defmodule Raxol.Terminal.Escape.Parsers.BaseParser do
  @moduledoc """
  Common utilities for parsing escape sequences.

  This module provides shared functionality for parsing escape sequences,
  including parameter parsing and validation.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Parses numeric parameters from a string, handling empty values.
  Returns a list of integers or nil values.
  """
  @spec parse_params(String.t()) :: [integer() | nil]
  def parse_params(""), do: []

  def parse_params(params_str) do
    params_str
    |> String.split(";", trim: true)
    |> Enum.map(fn
      # Empty param means default (often 1, depends on command)
      "" -> nil
      num_str -> elem(Integer.parse(num_str), 0)
    end)
  end

  @doc """
  Gets a parameter value at the specified index, returning the default if not found.
  """
  @spec param_at([integer() | nil], non_neg_integer(), integer() | nil) :: integer() | nil
  def param_at(params, index, default) do
    case Enum.at(params, index) do
      # Covers both out-of-bounds and explicitly parsed nil ("")
      nil -> default
      val -> val
    end
  end

  @doc """
  Validates if a string could be a valid escape sequence start.
  """
  @spec valid_sequence_start?(String.t()) :: boolean()
  def valid_sequence_start?(data) do
    String.match?(data, ~r/^[\d;?]*[@A-Za-z~]?$/)
  end

  @doc """
  Logs an unknown sequence with context.
  """
  @spec log_unknown_sequence(String.t(), String.t()) :: :ok
  def log_unknown_sequence(prefix, data) do
    Raxol.Core.Runtime.Log.debug(
      "Unknown #{prefix} sequence: #{inspect(data)}"
    )
  end

  @doc """
  Logs an invalid sequence with context.
  """
  @spec log_invalid_sequence(String.t(), String.t()) :: :ok
  def log_invalid_sequence(prefix, data) do
    Raxol.Core.Runtime.Log.debug(
      "Invalid or unsupported #{prefix} sequence fragment: #{inspect(data)}"
    )
  end
end
