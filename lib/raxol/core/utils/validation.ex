defmodule Raxol.Core.Utils.Validation do
  @moduledoc """
  Common validation utilities to reduce code duplication across the codebase.
  Provides standardized validation functions for dimensions, configs, and common patterns.
  """

  @doc """
  Validates that a dimension is a positive integer, returning default if invalid.
  """
  @spec validate_dimension(integer(), non_neg_integer()) :: non_neg_integer()
  def validate_dimension(dimension, _default) when is_integer(dimension) and dimension > 0 do
    dimension
  end

  def validate_dimension(_, default), do: default

  @doc """
  Validates that coordinates are valid non-negative integers.
  """
  @spec validate_coordinates(integer(), integer()) :: {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, :invalid_coordinates}
  def validate_coordinates(x, y) when is_integer(x) and x >= 0 and is_integer(y) and y >= 0 do
    {:ok, {x, y}}
  end

  def validate_coordinates(_, _), do: {:error, :invalid_coordinates}

  @doc """
  Validates a configuration map against required keys.
  """
  @spec validate_config(map(), list(atom())) :: {:ok, map()} | {:error, {:missing_keys, list(atom())}}
  def validate_config(config, required_keys) when is_map(config) do
    missing_keys = Enum.reject(required_keys, &Map.has_key?(config, &1))

    case missing_keys do
      [] -> {:ok, config}
      keys -> {:error, {:missing_keys, keys}}
    end
  end

  def validate_config(_, _), do: {:error, :invalid_config}

  @doc """
  Validates that a value is within specified bounds.
  """
  @spec validate_bounds(number(), number(), number()) :: {:ok, number()} | {:error, :out_of_bounds}
  def validate_bounds(value, min, max) when is_number(value) and value >= min and value <= max do
    {:ok, value}
  end

  def validate_bounds(_, _, _), do: {:error, :out_of_bounds}

  @doc """
  Validates that a list contains only specific types.
  """
  @spec validate_list_types(list(), atom()) :: {:ok, list()} | {:error, :invalid_types}
  def validate_list_types(list, type) when is_list(list) do
    valid = Enum.all?(list, fn item ->
      case type do
        :atom -> is_atom(item)
        :string -> is_binary(item)
        :integer -> is_integer(item)
        :number -> is_number(item)
        :map -> is_map(item)
        _ -> false
      end
    end)

    case valid do
      true -> {:ok, list}
      false -> {:error, :invalid_types}
    end
  end

  def validate_list_types(_, _), do: {:error, :invalid_types}

  @doc """
  Validates that a string is not empty and optionally matches a pattern.
  """
  @spec validate_string(binary(), Regex.t() | nil) :: {:ok, binary()} | {:error, :invalid_string}
  def validate_string(str, pattern \\ nil)

  def validate_string(str, nil) when is_binary(str) and byte_size(str) > 0 do
    {:ok, str}
  end

  def validate_string(str, pattern) when is_binary(str) and byte_size(str) > 0 do
    case Regex.match?(pattern, str) do
      true -> {:ok, str}
      false -> {:error, :invalid_string}
    end
  end

  def validate_string(_, _), do: {:error, :invalid_string}

  @doc """
  Validates that a value is one of the allowed options.
  """
  @spec validate_enum(any(), list()) :: {:ok, any()} | {:error, :invalid_option}
  def validate_enum(value, allowed) when is_list(allowed) do
    case value in allowed do
      true -> {:ok, value}
      false -> {:error, :invalid_option}
    end
  end

  def validate_enum(_, _), do: {:error, :invalid_option}
end