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
    |> Enum.map(&parse_single_param/1)
  end

  defp parse_single_param(""), do: nil

  defp parse_single_param(param) when is_binary(param) do
    case String.split(param, ":", parts: 2) do
      [param] ->
        parse_int(param)

      [param, _] ->
        param
        |> String.split(":")
        |> Enum.map(&parse_subparam/1)
    end
  end

  defp parse_single_param(param), do: parse_int(param)

  defp parse_subparam(""), do: nil
  defp parse_subparam(subparam), do: parse_int(subparam)

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
  @spec get_param(list(integer() | nil), non_neg_integer(), integer()) ::
          integer()
  def get_param(params, index, default \\ 1) do
    # Get the parameter at 0-based index, with default value
    case Enum.at(params, index) do
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
      # Only return the value if the remainder is empty
      {val, ""} -> val
      # Return nil for incomplete parses or errors
      _ -> nil
    end
  end
end
