defmodule Raxol.Config.Schema.Validator do
  @moduledoc """
  Validation logic for Raxol configuration values.

  Handles type checking and constraint validation.
  """

  @doc """
  Validates a configuration value against a field schema.
  """
  def validate(value, schema) do
    do_validate(value, schema, [])
  end

  @doc """
  Validates an entire configuration map against a schema.
  """
  def validate_map(config, schema, path \\ [])

  def validate_map(config, schema, path)
      when is_map(config) and is_map(schema) do
    unknown_keys = Map.keys(config) -- Map.keys(schema)

    unknown_errors =
      Enum.map(unknown_keys, fn key ->
        {path ++ [key], "unknown configuration key"}
      end)

    field_errors =
      schema
      |> Enum.flat_map(fn {key, field_schema} ->
        value = Map.get(config, key)
        field_path = path ++ [key]
        validate_field(value, field_schema, field_path)
      end)

    unknown_errors ++ field_errors
  end

  @doc """
  Returns {:ok, :valid} or {:error, errors} from an error list.
  """
  def handle_validation_result([]), do: {:ok, :valid}
  def handle_validation_result(errors), do: {:error, errors}

  # Private implementation

  defp do_validate(value, %{type: type} = schema, path) do
    with :ok <- validate_type(value, type, path) do
      validate_constraints(value, Map.get(schema, :constraints, []), path)
    end
  end

  defp validate_type(nil, _type, path) do
    {:error, {path, "value cannot be nil"}}
  end

  defp validate_type(value, :string, _path) when is_binary(value), do: :ok
  defp validate_type(value, :integer, _path) when is_integer(value), do: :ok
  defp validate_type(value, :float, _path) when is_float(value), do: :ok
  defp validate_type(value, :boolean, _path) when is_boolean(value), do: :ok
  defp validate_type(value, :atom, _path) when is_atom(value), do: :ok

  defp validate_type(value, {:enum, allowed}, path) do
    validate_enum_value(value in allowed, path, allowed)
  end

  defp validate_type(value, {:list, item_type}, path) when is_list(value) do
    errors =
      value
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        validate_type(item, item_type, path ++ [index])
      end)
      |> Enum.filter(&(&1 != :ok))

    handle_validation_errors(errors)
  end

  defp validate_type(value, {:map, value_type}, path) when is_map(value) do
    errors =
      value
      |> Enum.map(fn {key, val} ->
        validate_type(val, value_type, path ++ [key])
      end)
      |> Enum.filter(&(&1 != :ok))

    handle_validation_errors(errors)
  end

  defp validate_type(_value, type, path) do
    {:error, {path, "expected type #{inspect(type)}"}}
  end

  defp validate_constraints(value, constraints, path) do
    errors =
      constraints
      |> Enum.map(fn constraint ->
        validate_constraint(value, constraint, path)
      end)
      |> Enum.filter(&(&1 != :ok))

    handle_validation_errors(errors)
  end

  defp validate_constraint(value, {:min, min}, path) when is_number(value) do
    validate_minimum(value >= min, path, min)
  end

  defp validate_constraint(value, {:max, max}, path) when is_number(value) do
    validate_maximum(value <= max, path, max)
  end

  defp validate_constraint(value, {:min_length, min}, path)
       when is_binary(value) do
    validate_min_length(String.length(value) >= min, path, min)
  end

  defp validate_constraint(value, {:max_length, max}, path)
       when is_binary(value) do
    validate_max_length(String.length(value) <= max, path, max)
  end

  defp validate_constraint(value, {:format, regex}, path)
       when is_binary(value) do
    validate_format(Regex.match?(regex, value), path)
  end

  defp validate_constraint(value, {:custom, validator}, path)
       when is_function(validator) do
    case validator.(value) do
      :ok -> :ok
      {:error, reason} -> {:error, {path, reason}}
      false -> {:error, {path, "custom validation failed"}}
      true -> :ok
    end
  end

  defp validate_constraint(_value, _constraint, _path), do: :ok

  defp validate_field(value, field_schema, field_path) do
    cond do
      is_nil(value) and Map.get(field_schema, :required, false) ->
        [{field_path, "required field is missing"}]

      is_nil(value) ->
        []

      is_map(field_schema) and not Map.has_key?(field_schema, :type) ->
        validate_map(value, field_schema, field_path)

      true ->
        case do_validate(value, field_schema, field_path) do
          :ok -> []
          {:error, errors} when is_list(errors) -> errors
          {:error, error} -> [error]
        end
    end
  end

  defp validate_enum_value(true, _path, _allowed), do: :ok

  defp validate_enum_value(false, path, allowed),
    do: {:error, {path, "must be one of: #{inspect(allowed)}"}}

  defp handle_validation_errors([]), do: :ok
  defp handle_validation_errors(errors), do: {:error, errors}

  defp validate_minimum(true, _path, _min), do: :ok

  defp validate_minimum(false, path, min),
    do: {:error, {path, "must be >= #{min}"}}

  defp validate_maximum(true, _path, _max), do: :ok

  defp validate_maximum(false, path, max),
    do: {:error, {path, "must be <= #{max}"}}

  defp validate_min_length(true, _path, _min), do: :ok

  defp validate_min_length(false, path, min),
    do: {:error, {path, "minimum length is #{min}"}}

  defp validate_max_length(true, _path, _max), do: :ok

  defp validate_max_length(false, path, max),
    do: {:error, {path, "maximum length is #{max}"}}

  defp validate_format(true, _path), do: :ok
  defp validate_format(false, path), do: {:error, {path, "invalid format"}}
end
