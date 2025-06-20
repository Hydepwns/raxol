defmodule Raxol.Terminal.Commands.ParameterValidation do
  @moduledoc """
  Provides parameter validation functions for CSI command handlers.

  This module contains helper functions for validating and extracting
  parameters from CSI command sequences. Each function takes a list of
  parameters, an index, and a default value, returning either the
  validated parameter value or the default value if the parameter is
  invalid.
  """

  require Raxol.Core.Runtime.Log

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
  @spec get_valid_param(
          list(integer() | nil),
          non_neg_integer(),
          integer(),
          integer(),
          integer()
        ) :: integer()
  def get_valid_param(params, index, default, min, max) do
    case Enum.at(params, index, default) do
      value when is_integer(value) and value >= min and value <= max ->
        value

      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Invalid parameter value at index #{index}, using default #{default}",
          %{params: params, index: index, default: default, min: min, max: max}
        )

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
  @spec get_valid_non_neg_param(
          list(integer() | nil),
          non_neg_integer(),
          non_neg_integer()
        ) :: non_neg_integer()
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
  @spec get_valid_pos_param(
          list(integer() | nil),
          non_neg_integer(),
          pos_integer()
        ) :: pos_integer()
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
  @spec get_valid_bool_param(list(integer() | nil), non_neg_integer(), 0..1) ::
          0..1
  def get_valid_bool_param(params, index, default) do
    get_valid_param(params, index, default, 0, 1)
  end

  @doc """
  Validates coordinates, clamping to emulator bounds. Defaults to {0, 0} if invalid.
  """
  def validate_coordinates(emulator, params) do
    {max_x, max_y} = get_dimensions(emulator)
    x = validate_coordinate(Enum.at(params, 0), max_x)
    y = validate_coordinate(Enum.at(params, 1), max_y)
    {x, y}
  end

  defp get_dimensions(emulator) do
    width = get_dimension(emulator, :width, 0)
    height = get_dimension(emulator, :height, 1)
    {width - 1, height - 1}
  end

  defp get_dimension(emulator, key, tuple_index) do
    cond do
      is_map(emulator) -> Map.get(emulator, key, 10)
      is_tuple(emulator) -> elem(emulator, tuple_index)
      true -> 10
    end
  end

  defp validate_coordinate(value, max) do
    cond do
      is_integer(value) and value < 0 -> 0
      is_integer(value) and value > max -> max
      is_integer(value) -> value
      true -> 0
    end
  end

  @doc """
  Validates count, clamping between 1 and 10. Defaults to 1 if invalid.
  """
  def validate_count(_emulator, params) do
    case Enum.at(params, 0) do
      v when is_integer(v) and v >= 1 and v <= 10 -> v
      v when is_integer(v) and v < 1 -> 1
      v when is_integer(v) and v > 10 -> 10
      _ -> 1
    end
  end

  @doc """
  Validates mode, must be 0, 1, or 2. Defaults to 0 if invalid.
  """
  def validate_mode(params) do
    case Enum.at(params, 0) do
      v when v in [0, 1, 2] -> v
      _ -> 0
    end
  end

  @doc """
  Validates color, clamping between 0 and 255. Defaults to 0 if invalid.
  """
  def validate_color(params) do
    case Enum.at(params, 0) do
      v when is_integer(v) and v >= 0 and v <= 255 -> v
      v when is_integer(v) and v < 0 -> 0
      v when is_integer(v) and v > 255 -> 255
      _ -> 0
    end
  end

  @doc """
  Validates boolean, returns true for 1, false for 0. Defaults to true if invalid.
  """
  @spec validate_boolean(list(integer() | nil)) :: boolean()
  def validate_boolean(params) do
    case Enum.at(params, 0) do
      0 -> false
      1 -> true
      _ -> true
    end
  end

  @doc """
  Normalizes parameters to expected length, padding with nil or truncating as needed.
  """
  @spec normalize_parameters(list(integer() | nil), non_neg_integer()) ::
          list(integer() | nil)
  def normalize_parameters(params, expected_length) do
    params
    |> Enum.take(expected_length)
    |> then(fn taken ->
      taken ++ List.duplicate(nil, expected_length - length(taken))
    end)
  end

  @doc """
  Validates a value in params[0], clamping between min and max. Defaults to min if invalid.
  """
  @spec validate_range(list(integer() | nil), integer(), integer()) :: integer()
  def validate_range(params, min, max) do
    value = Enum.at(params, 0)
    if is_integer(value), do: max(min, min(value, max)), else: min
  end
end
