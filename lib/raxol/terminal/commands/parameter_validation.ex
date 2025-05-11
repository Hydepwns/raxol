defmodule Raxol.Terminal.Commands.ParameterValidation do
  @moduledoc """
  Provides parameter validation functions for CSI command handlers.

  This module contains helper functions for validating and extracting
  parameters from CSI command sequences. Each function takes a list of
  parameters, an index, and a default value, returning either the
  validated parameter value or the default value if the parameter is
  invalid.
  """

  require Logger

  @doc """
  Gets a parameter value with validation.
  Returns the parameter value if valid, or the default value if invalid.

  ## Parameters

    * `params` - List of parameter values
    * `index` - Index of the parameter to get
    * `default` - Default value to use if parameter is invalid
    * `min` - Minimum allowed value
    * `max` - Maximum allowed value

  ## Examples

      iex> ParameterValidation.get_valid_param([1, 2, 3], 0, 0, 0, 9999)
      1

      iex> ParameterValidation.get_valid_param([nil, 2, 3], 0, 0, 0, 9999)
      0

      iex> ParameterValidation.get_valid_param([-1, 2, 3], 0, 0, 0, 9999)
      0
  """
  @spec get_valid_param(list(integer() | nil), non_neg_integer(), integer(), integer(), integer()) :: integer()
  def get_valid_param(params, index, default, min, max) do
    case Enum.at(params, index, default) do
      value when is_integer(value) and value >= min and value <= max ->
        value
      _ ->
        Logger.warning("Invalid parameter value at index #{index}, using default #{default}")
        default
    end
  end

  @doc """
  Gets a parameter value with validation for non-negative integers.
  Returns the parameter value if valid, or the default value if invalid.

  ## Parameters

    * `params` - List of parameter values
    * `index` - Index of the parameter to get
    * `default` - Default value to use if parameter is invalid

  ## Examples

      iex> ParameterValidation.get_valid_non_neg_param([1, 2, 3], 0, 0)
      1

      iex> ParameterValidation.get_valid_non_neg_param([nil, 2, 3], 0, 0)
      0

      iex> ParameterValidation.get_valid_non_neg_param([-1, 2, 3], 0, 0)
      0
  """
  @spec get_valid_non_neg_param(list(integer() | nil), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def get_valid_non_neg_param(params, index, default) do
    get_valid_param(params, index, default, 0, 9999)
  end

  @doc """
  Gets a parameter value with validation for positive integers.
  Returns the parameter value if valid, or the default value if invalid.

  ## Parameters

    * `params` - List of parameter values
    * `index` - Index of the parameter to get
    * `default` - Default value to use if parameter is invalid

  ## Examples

      iex> ParameterValidation.get_valid_pos_param([1, 2, 3], 0, 1)
      1

      iex> ParameterValidation.get_valid_pos_param([nil, 2, 3], 0, 1)
      1

      iex> ParameterValidation.get_valid_pos_param([0, 2, 3], 0, 1)
      1
  """
  @spec get_valid_pos_param(list(integer() | nil), non_neg_integer(), pos_integer()) :: pos_integer()
  def get_valid_pos_param(params, index, default) do
    get_valid_param(params, index, default, 1, 9999)
  end

  @doc """
  Gets a parameter value with validation for boolean values (0 or 1).
  Returns the parameter value if valid, or the default value if invalid.

  ## Parameters

    * `params` - List of parameter values
    * `index` - Index of the parameter to get
    * `default` - Default value to use if parameter is invalid (must be 0 or 1)

  ## Examples

      iex> ParameterValidation.get_valid_bool_param([1, 2, 3], 0, 0)
      1

      iex> ParameterValidation.get_valid_bool_param([nil, 2, 3], 0, 0)
      0

      iex> ParameterValidation.get_valid_bool_param([2, 2, 3], 0, 0)
      0
  """
  @spec get_valid_bool_param(list(integer() | nil), non_neg_integer(), 0..1) :: 0..1
  def get_valid_bool_param(params, index, default) do
    get_valid_param(params, index, default, 0, 1)
  end
end
