defmodule Raxol.Terminal.Commands.Parser do
  @moduledoc """
  Handles parsing of command parameters in terminal sequences.

  This module is part of the terminal command execution system. It provides
  utilities for parsing and extracting parameters from CSI, OSC, and DCS
  sequence parameter strings.
  """

  @doc """
  Parses a raw parameter string buffer into a list of integers or nil values.

  Handles empty or malformed parameters by converting them to nil.
  Handles parameters with sub-parameters (separated by ':')

  ## Examples

      iex> Parser.parse_params("5;10;15")
      [5, 10, 15]

      iex> Parser.parse_params("5;10;;15")
      [5, 10, nil, 15]

      iex> Parser.parse_params("5:1;10:2;15:3")
      [[5, 1], [10, 2], [15, 3]]
  """
  @spec parse_params(String.t()) ::
          list(integer() | nil | list(integer() | nil))
  def parse_params(""), do: []
  def parse_params(nil), do: []

  def parse_params(params_string) do
    params_string
    |> String.split(";")
    |> Enum.map(fn param ->
      cond do
        # Handle empty parameter
        param == "" ->
          nil

        # Handle parameter with sub-parameters
        String.contains?(param, ":") ->
          param
          |> String.split(":")
          |> Enum.map(fn subparam ->
            if subparam == "" do
              nil
            else
              parse_int(subparam)
            end
          end)

        # Handle regular parameter
        true ->
          parse_int(param)
      end
    end)
  end

  @doc """
  Gets a parameter at a specific index from the params list.

  If the parameter is not available, returns the provided default value.

  ## Examples

      iex> Parser.get_param([5, 10, 15], 2)
      10

      iex> Parser.get_param([5, 10], 3)
      1

      iex> Parser.get_param([5, 10], 3, 0)
      0
  """
  @spec get_param(list(integer() | nil), pos_integer(), integer()) :: integer()
  def get_param(params, index, default \\ 1) do
    # Get the parameter at 1-based index, with default value
    case Enum.at(params, index - 1) do
      nil -> default
      val -> val
    end
  end

  @doc """
  Safely parses a string into an integer.

  Returns the parsed integer, or nil on failure.

  ## Examples

      iex> Parser.parse_int("123")
      123

      iex> Parser.parse_int("abc")
      nil
  """
  @spec parse_int(String.t()) :: integer() | nil
  def parse_int(str) do
    case Integer.parse(str) do
      {val, ""} -> val # Only return the value if the remainder is empty
      _ -> nil        # Return nil for incomplete parses or errors
    end
  end
end
