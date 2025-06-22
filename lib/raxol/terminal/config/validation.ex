defmodule Raxol.Terminal.Config.Validation do
  import Raxol.Guards

  @moduledoc """
  Validation logic for terminal configuration.

  Ensures that configuration values are valid according to their schema.
  """

  alias Raxol.Terminal.Config.Schema

  @doc """
  Validates a complete terminal configuration.

  ## Parameters

  * `config` - The configuration to validate

  ## Returns

  `{:ok, validated_config}` or `{:error, reason}`
  """
  def validate_config(config) do
    # Implementation of full configuration validation
    validate_config_recursive(config, [], Schema.config_schema())
  end

  # Recursive validation of configuration against schema
  defp validate_config_recursive(config, path, schema)
       when map?(config) and map?(schema) do
    # Get all keys from both config and schema
    config_keys = Map.keys(config)
    schema_keys = Map.keys(schema)

    # Check for unknown keys in config
    unknown_keys = config_keys -- schema_keys

    if unknown_keys != [] do
      {:error,
       "Unknown configuration keys at #{inspect(path)}: #{inspect(unknown_keys)}"}
    else
      # Validate each key in the config
      Enum.reduce_while(config, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
        # Get schema for this key
        key_schema = Map.get(schema, key)
        key_path = path ++ [key]

        # Validate value against schema
        case validate_value_with_schema(value, key_path, key_schema) do
          {:ok, validated_value} ->
            {:cont, {:ok, Map.put(acc, key, validated_value)}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp validate_config_recursive(config, path, _schema) do
    {:error, "Expected map at #{inspect(path)}, got: #{inspect(config)}"}
  end

  # Validate a value against its schema
  defp validate_value_with_schema(value, path, schema)
       when map?(schema) and map?(value) do
    # For nested maps, recursively validate
    validate_config_recursive(value, path, schema)
  end

  defp validate_value_with_schema(value, path, {type, _description}) do
    # For simple types, validate directly
    validate_type(value, type, path)
  end

  defp validate_value_with_schema(value, path, {type, options, _description}) do
    # For types with options, validate with options
    validate_type(value, {type, options}, path)
  end

  @doc """
  Validates a specific configuration value against its schema.

  ## Parameters

  * `path` - A list of keys representing the path to the configuration value
  * `value` - The value to validate

  ## Returns

  `{:ok, validated_value}` or `{:error, reason}`
  """
  def validate_value(path, value) do
    case Schema.get_type(path) do
      nil ->
        {:error, "Unknown configuration path: #{inspect(path)}"}

      {type, _description} ->
        validate_type(value, type, path)

      {type, options, _description} ->
        validate_type(value, {type, options}, path)
    end
  end

  @doc """
  Validates configuration updates against the schema.

  ## Parameters

  * `config` - The current configuration
  * `updates` - The updates to validate

  ## Returns

  `:ok` or `{:error, reason}`
  """
  def validate_update(config, updates) when map?(updates) do
    # For now, just validate that the updates are valid configuration keys
    # This is a simplified validation - in a real implementation, you'd want
    # to validate the actual values against the schema
    case validate_config(updates) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Private validation functions for different types
  defp validate_type(value, :integer, _path) when integer?(value),
    do: {:ok, value}

  defp validate_type(value, :float, _path) when float?(value),
    do: {:ok, value}

  defp validate_type(value, :boolean, _path) when boolean?(value),
    do: {:ok, value}

  defp validate_type(value, :string, _path) when binary?(value),
    do: {:ok, value}

  defp validate_type(value, {:enum, options}, path) do
    if value in options do
      {:ok, value}
    else
      {:error,
       "Value #{inspect(value)} at #{inspect(path)} is not one of #{inspect(options)}"}
    end
  end

  defp validate_type(value, type, path) do
    {:error,
     "Invalid value #{inspect(value)} at #{inspect(path)} for type #{inspect(type)}"}
  end
end
