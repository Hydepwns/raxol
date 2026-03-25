defmodule Raxol.Config.Schema do
  @moduledoc """
  Configuration schema definitions and validation.

  Defines the structure, types, and constraints for all configuration options
  in Raxol, providing compile-time and runtime validation.
  """

  @compile {:no_warn_undefined, Raxol.Config.Schema.Definitions}
  @compile {:no_warn_undefined, Raxol.Config.Schema.Validator}
  @compile {:no_warn_undefined, Raxol.Config.Schema.Documentation}

  alias Raxol.Config.Schema.Definitions
  alias Raxol.Config.Schema.Documentation
  alias Raxol.Config.Schema.Validator

  @type schema_type ::
          :string
          | :integer
          | :float
          | :boolean
          | :atom
          | {:list, schema_type()}
          | {:map, schema_type()}
          | {:enum, [term()]}
          | {:struct, module()}
          | {:one_of, [schema_type()]}

  @type constraint ::
          {:min, number()}
          | {:max, number()}
          | {:min_length, non_neg_integer()}
          | {:max_length, non_neg_integer()}
          | {:format, Regex.t()}
          | {:custom, fun()}

  @type field_schema :: %{
          type: schema_type(),
          required: boolean(),
          default: term(),
          constraints: [constraint()],
          description: String.t(),
          deprecated: boolean()
        }

  @doc """
  Returns the complete configuration schema.
  """
  def schema do
    %{
      terminal: Definitions.terminal_schema(),
      buffer: Definitions.buffer_schema(),
      rendering: Definitions.rendering_schema(),
      plugins: Definitions.plugins_schema(),
      security: Definitions.security_schema(),
      performance: Definitions.performance_schema(),
      theme: Definitions.theme_schema(),
      logging: Definitions.logging_schema(),
      accessibility: Definitions.accessibility_schema(),
      keybindings: Definitions.keybindings_schema()
    }
  end

  @doc """
  Validates a configuration value against a schema.
  """
  def validate(value, schema) do
    Validator.validate(value, schema)
  end

  @doc """
  Validates an entire configuration map.
  """
  def validate_config(config, schema \\ schema()) do
    errors = Validator.validate_map(config, schema)
    Validator.handle_validation_result(errors)
  end

  @doc """
  Gets the schema for a specific configuration path.
  """
  def get_schema(path) when is_list(path) do
    get_nested_schema(schema(), path)
  end

  @doc """
  Generates documentation for configuration options.
  """
  def generate_docs do
    Documentation.generate_docs(schema())
  end

  defp get_nested_schema(schema, []), do: schema

  defp get_nested_schema(schema, [key | rest]) do
    case Map.get(schema, key) do
      nil -> nil
      nested -> get_nested_schema(nested, rest)
    end
  end
end
