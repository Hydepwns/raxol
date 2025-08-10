defmodule Raxol.DevTools.PropsValidator do
  @moduledoc """
  Runtime props validation system for Raxol components.

  This module provides comprehensive prop validation with:
  - Type checking (string, number, boolean, atom, list, map, function)
  - Required prop validation
  - Custom validation functions
  - Default value handling
  - Nested prop validation
  - Helpful error messages with suggestions
  - Performance optimized validation

  ## Usage

      # Define props schema in component
      defmodule MyButton do
        use Raxol.Component
        
        @props %{
          label: %{type: :string, required: true},
          variant: %{type: :atom, enum: [:primary, :secondary, :danger], default: :primary},
          disabled: %{type: :boolean, default: false},
          on_click: %{type: :function, arity: 0},
          size: %{type: :number, min: 10, max: 100, default: 16},
          children: %{type: :list, of: :component},
          style: %{type: :map, schema: %{color: :string, background: :string}}
        }
        
        def __props__, do: @props
        
        def render(props, context) do
          # Props are automatically validated before render
          # ...
        end
      end
      
      # Manual validation
      case PropsValidator.validate_props(MyButton, props) do
        {:ok, validated_props} -> 
          # Use validated_props
        {:error, errors} ->
          # Handle validation errors
      end
  """

  require Logger

  defmodule ValidationError do
    defstruct [:field, :type, :message, :value, :suggestion]

    def new(field, type, message, value \\ nil, suggestion \\ nil) do
      %__MODULE__{
        field: field,
        type: type,
        message: message,
        value: value,
        suggestion: suggestion
      }
    end
  end

  defmodule PropSchema do
    defstruct [
      :type,
      :required,
      :default,
      :enum,
      :min,
      :max,
      :arity,
      :of,
      :schema,
      :validator,
      :transform
    ]

    def from_config(config) when is_map(config) do
      %__MODULE__{
        type: Map.get(config, :type),
        required: Map.get(config, :required, false),
        default: Map.get(config, :default),
        enum: Map.get(config, :enum),
        min: Map.get(config, :min),
        max: Map.get(config, :max),
        arity: Map.get(config, :arity),
        of: Map.get(config, :of),
        schema: Map.get(config, :schema),
        validator: Map.get(config, :validator),
        transform: Map.get(config, :transform)
      }
    end

    def from_config(type) when is_atom(type) do
      %__MODULE__{type: type}
    end
  end

  ## Public API

  @doc """
  Validates props against a component's prop schema.

  Returns `{:ok, validated_props}` on success or `{:error, errors}` on failure.
  """
  def validate_props(component, props)
      when is_atom(component) and is_map(props) do
    case get_component_schema(component) do
      nil ->
        # No schema defined, return props as-is
        {:ok, props}

      schema ->
        validate_against_schema(props, schema)
    end
  end

  @doc """
  Validates props against a provided schema map.
  """
  def validate_against_schema(props, schema)
      when is_map(props) and is_map(schema) do
    # Convert schema to PropSchema structs
    prop_schemas =
      Map.new(schema, fn {key, config} ->
        {key, PropSchema.from_config(config)}
      end)

    # Validate all props
    case run_validation(props, prop_schemas) do
      {validated_props, []} ->
        {:ok, validated_props}

      {_props, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Validates a single prop value against its schema.
  """
  def validate_prop(prop_name, value, prop_schema) do
    schema = PropSchema.from_config(prop_schema)

    case validate_single_prop(prop_name, value, schema) do
      {:ok, validated_value} -> {:ok, validated_value}
      {:error, error} -> {:error, [error]}
    end
  end

  @doc """
  Gets validation suggestions for common prop mistakes.
  """
  def suggest_fixes(component, props, errors) do
    Enum.map(errors, fn error ->
      suggestion = generate_suggestion(component, error, props)
      %{error | suggestion: suggestion}
    end)
  end

  @doc """
  Creates a prop schema builder for easier schema definition.
  """
  def prop(type, opts \\ []) do
    base_config = %{type: type}

    Enum.reduce(opts, base_config, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  @doc """
  Common prop type shortcuts.
  """
  def string(opts \\ []), do: prop(:string, opts)
  def number(opts \\ []), do: prop(:number, opts)
  def boolean(opts \\ []), do: prop(:boolean, opts)
  def atom(opts \\ []), do: prop(:atom, opts)
  def list(opts \\ []), do: prop(:list, opts)
  def map(opts \\ []), do: prop(:map, opts)
  def function(opts \\ []), do: prop(:function, opts)
  def component(opts \\ []), do: prop(:component, opts)
  def any(opts \\ []), do: prop(:any, opts)

  ## Private Implementation

  defp get_component_schema(component) do
    try do
      if function_exported?(component, :__props__, 0) do
        component.__props__()
      else
        nil
      end
    catch
      _, _ -> nil
    end
  end

  defp run_validation(props, prop_schemas) do
    # Start with props and empty errors
    initial_state = {%{}, []}

    # Validate each schema prop
    {validated_props, errors} =
      Enum.reduce(prop_schemas, initial_state, fn {prop_name, schema},
                                                  {acc_props, acc_errors} ->
        prop_value = Map.get(props, prop_name)

        case validate_single_prop(prop_name, prop_value, schema) do
          {:ok, validated_value} ->
            new_props = Map.put(acc_props, prop_name, validated_value)
            {new_props, acc_errors}

          {:error, error} ->
            {acc_props, [error | acc_errors]}
        end
      end)

    # Add any extra props that weren't in schema
    extra_props = Map.drop(props, Map.keys(prop_schemas))
    final_props = Map.merge(validated_props, extra_props)

    {final_props, Enum.reverse(errors)}
  end

  defp validate_single_prop(prop_name, value, schema) do
    with {:ok, value} <- check_required(prop_name, value, schema),
         {:ok, value} <- apply_default(prop_name, value, schema),
         {:ok, value} <- check_type(prop_name, value, schema),
         {:ok, value} <- check_enum(prop_name, value, schema),
         {:ok, value} <- check_range(prop_name, value, schema),
         {:ok, value} <- check_arity(prop_name, value, schema),
         {:ok, value} <- check_nested(prop_name, value, schema),
         {:ok, value} <- check_custom_validator(prop_name, value, schema),
         {:ok, value} <- apply_transform(prop_name, value, schema) do
      {:ok, value}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp check_required(prop_name, nil, %{required: true}) do
    {:error,
     ValidationError.new(prop_name, :required, "#{prop_name} is required")}
  end

  defp check_required(_prop_name, value, _schema) do
    {:ok, value}
  end

  defp apply_default(_prop_name, nil, %{default: default_value}) do
    {:ok, default_value}
  end

  defp apply_default(_prop_name, value, _schema) do
    {:ok, value}
  end

  defp check_type(_prop_name, nil, _schema) do
    {:ok, nil}
  end

  defp check_type(prop_name, value, %{type: :string}) do
    if is_binary(value) do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :type,
         "#{prop_name} must be a string",
         value,
         "try: \"#{value}\""
       )}
    end
  end

  defp check_type(prop_name, value, %{type: :number}) do
    if is_number(value) do
      {:ok, value}
    else
      case Float.parse(to_string(value)) do
        {number, ""} ->
          {:ok, number}

        _ ->
          {:error,
           ValidationError.new(
             prop_name,
             :type,
             "#{prop_name} must be a number",
             value
           )}
      end
    end
  end

  defp check_type(prop_name, value, %{type: :boolean}) do
    if is_boolean(value) do
      {:ok, value}
    else
      case value do
        "true" ->
          {:ok, true}

        "false" ->
          {:ok, false}

        1 ->
          {:ok, true}

        0 ->
          {:ok, false}

        _ ->
          {:error,
           ValidationError.new(
             prop_name,
             :type,
             "#{prop_name} must be a boolean",
             value,
             "try: true or false"
           )}
      end
    end
  end

  defp check_type(prop_name, value, %{type: :atom}) do
    if is_atom(value) do
      {:ok, value}
    else
      try do
        {:ok, String.to_existing_atom(to_string(value))}
      catch
        ArgumentError ->
          {:error,
           ValidationError.new(
             prop_name,
             :type,
             "#{prop_name} must be an atom",
             value,
             "try: :#{value}"
           )}
      end
    end
  end

  defp check_type(prop_name, value, %{type: :list}) do
    if is_list(value) do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :type,
         "#{prop_name} must be a list",
         value,
         "try: [#{value}]"
       )}
    end
  end

  defp check_type(prop_name, value, %{type: :map}) do
    if is_map(value) do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :type,
         "#{prop_name} must be a map",
         value
       )}
    end
  end

  defp check_type(prop_name, value, %{type: :function}) do
    if is_function(value) do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :type,
         "#{prop_name} must be a function",
         value,
         "try: fn -> ... end"
       )}
    end
  end

  defp check_type(prop_name, value, %{type: :component}) do
    if is_component?(value) do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :type,
         "#{prop_name} must be a component",
         value
       )}
    end
  end

  defp check_type(_prop_name, value, %{type: :any}) do
    {:ok, value}
  end

  defp check_type(_prop_name, value, _schema) do
    {:ok, value}
  end

  defp check_enum(_prop_name, nil, _schema) do
    {:ok, nil}
  end

  defp check_enum(prop_name, value, %{enum: valid_values})
       when is_list(valid_values) do
    if value in valid_values do
      {:ok, value}
    else
      suggestion = suggest_closest_enum_value(value, valid_values)

      {:error,
       ValidationError.new(
         prop_name,
         :enum,
         "#{prop_name} must be one of #{inspect(valid_values)}",
         value,
         suggestion
       )}
    end
  end

  defp check_enum(_prop_name, value, _schema) do
    {:ok, value}
  end

  defp check_range(_prop_name, nil, _schema) do
    {:ok, nil}
  end

  defp check_range(prop_name, value, %{min: min_val})
       when is_number(value) and is_number(min_val) do
    if value >= min_val do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :range,
         "#{prop_name} must be >= #{min_val}",
         value
       )}
    end
  end

  defp check_range(prop_name, value, %{max: max_val})
       when is_number(value) and is_number(max_val) do
    if value <= max_val do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :range,
         "#{prop_name} must be <= #{max_val}",
         value
       )}
    end
  end

  defp check_range(prop_name, value, %{min: min_len})
       when is_binary(value) and is_number(min_len) do
    if String.length(value) >= min_len do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :range,
         "#{prop_name} must be at least #{min_len} characters",
         value
       )}
    end
  end

  defp check_range(prop_name, value, %{max: max_len})
       when is_binary(value) and is_number(max_len) do
    if String.length(value) <= max_len do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :range,
         "#{prop_name} must be at most #{max_len} characters",
         value
       )}
    end
  end

  defp check_range(_prop_name, value, _schema) do
    {:ok, value}
  end

  defp check_arity(_prop_name, nil, _schema) do
    {:ok, nil}
  end

  defp check_arity(prop_name, value, %{arity: expected_arity})
       when is_function(value) do
    actual_arity = Function.info(value, :arity) |> elem(1)

    if actual_arity == expected_arity do
      {:ok, value}
    else
      {:error,
       ValidationError.new(
         prop_name,
         :arity,
         "#{prop_name} function must have arity #{expected_arity}, got #{actual_arity}",
         value,
         "try: fn #{Enum.map_join(1..expected_arity, ", ", fn i -> "arg#{i}" end)} -> ... end"
       )}
    end
  end

  defp check_arity(_prop_name, value, _schema) do
    {:ok, value}
  end

  defp check_nested(_prop_name, nil, _schema) do
    {:ok, nil}
  end

  defp check_nested(prop_name, value, %{of: item_schema}) when is_list(value) do
    # Validate each item in the list
    {validated_items, errors} =
      Enum.with_index(value)
      |> Enum.reduce({[], []}, fn {item, index}, {acc_items, acc_errors} ->
        case validate_single_prop(
               "#{prop_name}[#{index}]",
               item,
               PropSchema.from_config(item_schema)
             ) do
          {:ok, validated_item} ->
            {[validated_item | acc_items], acc_errors}

          {:error, error} ->
            {acc_items, [error | acc_errors]}
        end
      end)

    if Enum.empty?(errors) do
      {:ok, Enum.reverse(validated_items)}
    else
      # Return first error for simplicity
      {:error, List.first(errors)}
    end
  end

  defp check_nested(prop_name, value, %{schema: nested_schema})
       when is_map(value) and is_map(nested_schema) do
    case validate_against_schema(value, nested_schema) do
      {:ok, validated_map} ->
        {:ok, validated_map}

      {:error, errors} ->
        # Wrap errors with parent prop name
        wrapped_errors =
          Enum.map(errors, fn error ->
            %{error | field: "#{prop_name}.#{error.field}"}
          end)

        {:error, List.first(wrapped_errors)}
    end
  end

  defp check_nested(_prop_name, value, _schema) do
    {:ok, value}
  end

  defp check_custom_validator(_prop_name, nil, _schema) do
    {:ok, nil}
  end

  defp check_custom_validator(prop_name, value, %{validator: validator_fn})
       when is_function(validator_fn, 1) do
    case validator_fn.(value) do
      true ->
        {:ok, value}

      false ->
        {:error,
         ValidationError.new(
           prop_name,
           :custom,
           "#{prop_name} failed custom validation",
           value
         )}

      {:error, message} ->
        {:error, ValidationError.new(prop_name, :custom, message, value)}

      :ok ->
        {:ok, value}
    end
  end

  defp check_custom_validator(_prop_name, value, _schema) do
    {:ok, value}
  end

  defp apply_transform(_prop_name, nil, _schema) do
    {:ok, nil}
  end

  defp apply_transform(prop_name, value, %{transform: transform_fn})
       when is_function(transform_fn, 1) do
    try do
      {:ok, transform_fn.(value)}
    catch
      kind, reason ->
        {:error,
         ValidationError.new(
           prop_name,
           :transform,
           "Failed to transform #{prop_name}: #{inspect(kind)} - #{inspect(reason)}",
           value
         )}
    end
  end

  defp apply_transform(_prop_name, value, _schema) do
    {:ok, value}
  end

  defp is_component?(value) do
    is_map(value) and Map.has_key?(value, :type)
  end

  defp suggest_closest_enum_value(value, valid_values) do
    string_value = to_string(value)

    closest =
      valid_values
      |> Enum.map(fn valid ->
        {valid, String.jaro_distance(string_value, to_string(valid))}
      end)
      |> Enum.max_by(&elem(&1, 1))
      |> elem(0)

    "did you mean: #{closest}?"
  end

  defp generate_suggestion(component, error, _props) do
    case error.type do
      :required ->
        "#{error.field} is required for #{component}"

      :type ->
        "#{error.field} should be #{error.type}"

      :enum ->
        error.suggestion || "check available options"

      :range ->
        "check the min/max values for #{error.field}"

      _ ->
        nil
    end
  end

  ## Validation Helpers

  @doc """
  Validates props and logs warnings instead of throwing errors.
  Useful for development mode.
  """
  def validate_with_warnings(component, props) do
    case validate_props(component, props) do
      {:ok, validated_props} ->
        validated_props

      {:error, errors} ->
        errors
        |> suggest_fixes(component, props)
        |> Enum.each(fn error ->
          Logger.warning(
            "Props validation warning for #{component}.#{error.field}: #{error.message}" <>
              if(error.suggestion, do: " (#{error.suggestion})", else: "")
          )
        end)

        props
    end
  end

  @doc """
  Creates a validation middleware for automatic prop checking.
  """
  def validation_middleware do
    fn component, props, next ->
      validated_props = validate_with_warnings(component, props)
      next.(component, validated_props)
    end
  end
end
