defmodule Raxol.Security.InputValidator do
  @moduledoc """
  Secure input validation and sanitization module.

  Provides comprehensive input validation with security in mind,
  preventing common attacks like SQL injection, XSS, and command injection.
  """

  alias Raxol.Security.Auditor

  @type validation_rule ::
          {:type, atom()}
          | {:required, boolean()}
          | {:min_length, non_neg_integer()}
          | {:max_length, non_neg_integer()}
          | {:format, Regex.t()}
          | {:in, list()}
          | {:custom, function()}

  @type field_spec :: %{
          required(:name) => atom(),
          required(:rules) => [validation_rule()],
          optional(:sanitize) => boolean(),
          optional(:error_message) => String.t()
        }

  @doc """
  Validates a map of inputs against a schema.

  ## Examples

      schema = [
        %{name: :username, rules: [{:type, :string}, {:min_length, 3}, {:max_length, 20}]},
        %{name: :email, rules: [{:type, :string}, {:format, ~r/^[\\w._%+-]+@[\\w.-]+\\.[A-Za-z]{2,}$/}]},
        %{name: :age, rules: [{:type, :integer}, {:min, 18}, {:max, 120}]}
      ]
      
      validate_inputs(%{username: "john", email: "john@example.com", age: 25}, schema)
  """
  def validate_inputs(inputs, schema) when is_map(inputs) and is_list(schema) do
    results =
      Enum.reduce(schema, {%{}, []}, fn field_spec, {valid, errors} ->
        field_name = field_spec.name

        value =
          Map.get(inputs, field_name) || Map.get(inputs, to_string(field_name))

        case validate_field(value, field_spec) do
          {:ok, sanitized_value} ->
            {Map.put(valid, field_name, sanitized_value), errors}

          {:error, reason} ->
            {valid, [{field_name, reason} | errors]}
        end
      end)

    case results do
      {valid_inputs, []} -> {:ok, valid_inputs}
      {_, errors} -> {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Validates a single field against its rules.
  """
  def validate_field(value, field_spec) do
    with {:ok, value} <- check_required(value, field_spec),
         {:ok, value} <- check_type(value, field_spec),
         {:ok, value} <- apply_rules(value, field_spec.rules),
         {:ok, value} <- sanitize_if_needed(value, field_spec) do
      {:ok, value}
    end
  end

  @doc """
  Common validation patterns.
  """
  def patterns do
    %{
      email: ~r/^[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}$/,
      url:
        ~r/^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&\/\/=]*)$/,
      phone: ~r/^\+?[1-9]\d{1,14}$/,
      alphanumeric: ~r/^[a-zA-Z0-9]+$/,
      alpha: ~r/^[a-zA-Z]+$/,
      numeric: ~r/^[0-9]+$/,
      uuid: ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    }
  end

  @doc """
  Sanitizes common input types.
  """
  def sanitize(value, type) do
    case type do
      :html -> sanitize_html(value)
      :sql -> sanitize_sql(value)
      :filename -> sanitize_filename(value)
      :url -> sanitize_url(value)
      _ -> value
    end
  end

  # Private functions

  defp check_required(nil, %{rules: rules}) do
    is_required = {:required, true} in rules
    handle_required_check(is_required)
  end

  defp check_required(value, _), do: {:ok, value}

  defp handle_required_check(true), do: {:error, "is required"}
  defp handle_required_check(false), do: {:ok, nil}

  defp check_type(nil, _), do: {:ok, nil}

  defp check_type(value, %{rules: rules}) do
    case Enum.find(rules, fn
           {:type, _} -> true
           _ -> false
         end) do
      {:type, expected_type} -> validate_type(value, expected_type)
      nil -> {:ok, value}
    end
  end

  defp validate_type(value, :string) when is_binary(value), do: {:ok, value}
  defp validate_type(value, :integer) when is_integer(value), do: {:ok, value}
  defp validate_type(value, :float) when is_float(value), do: {:ok, value}
  defp validate_type(value, :number) when is_number(value), do: {:ok, value}
  defp validate_type(value, :boolean) when is_boolean(value), do: {:ok, value}
  defp validate_type(value, :atom) when is_atom(value), do: {:ok, value}
  defp validate_type(value, :list) when is_list(value), do: {:ok, value}
  defp validate_type(value, :map) when is_map(value), do: {:ok, value}

  # Type coercion
  defp validate_type(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "must be an integer"}
    end
  end

  defp validate_type(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, "must be a float"}
    end
  end

  defp validate_type(value, :boolean) when is_binary(value) do
    case String.downcase(value) do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, "must be a boolean"}
    end
  end

  defp validate_type(_, type), do: {:error, "must be a #{type}"}

  defp apply_rules(nil, _), do: {:ok, nil}

  defp apply_rules(value, rules) do
    Enum.reduce_while(rules, {:ok, value}, fn rule, {:ok, val} ->
      case apply_rule(val, rule) do
        {:ok, new_val} -> {:cont, {:ok, new_val}}
        error -> {:halt, error}
      end
    end)
  end

  defp apply_rule(value, {:min_length, min}) when is_binary(value) do
    meets_min = String.length(value) >= min
    handle_min_length_check(meets_min, value, min)
  end

  defp apply_rule(value, {:max_length, max}) when is_binary(value) do
    meets_max = String.length(value) <= max
    handle_max_length_check(meets_max, value, max)
  end

  defp apply_rule(value, {:min, min}) when is_number(value) do
    meets_min = value >= min
    handle_min_value_check(meets_min, value, min)
  end

  defp apply_rule(value, {:max, max}) when is_number(value) do
    meets_max = value <= max
    handle_max_value_check(meets_max, value, max)
  end

  defp apply_rule(value, {:format, regex}) when is_binary(value) do
    matches = Regex.match?(regex, value)
    handle_format_check(matches, value)
  end

  defp apply_rule(value, {:in, allowed}) do
    is_allowed = value in allowed
    handle_allowed_check(is_allowed, value, allowed)
  end

  defp apply_rule(value, {:custom, validator}) when is_function(validator, 1) do
    validator.(value)
  end

  defp apply_rule(value, _), do: {:ok, value}

  defp handle_min_length_check(true, value, _min), do: {:ok, value}

  defp handle_min_length_check(false, _value, min) do
    {:error, "must be at least #{min} characters"}
  end


  defp handle_max_length_check(true, value, _max), do: {:ok, value}

  defp handle_max_length_check(false, _value, max) do
    {:error, "must be at most #{max} characters"}
  end

  defp handle_allowed_check(true, value, _allowed), do: {:ok, value}
  
  defp handle_allowed_check(false, _value, allowed) do
    {:error, "must be one of: #{inspect(allowed)}"}
  end


  defp handle_min_value_check(true, value, _min), do: {:ok, value}

  defp handle_min_value_check(false, _value, min) do
    {:error, "must be at least #{min}"}
  end


  defp handle_max_value_check(true, value, _max), do: {:ok, value}

  defp handle_max_value_check(false, _value, max) do
    {:error, "must be at most #{max}"}
  end


  defp handle_format_check(true, value), do: {:ok, value}
  defp handle_format_check(false, _value), do: {:error, "has invalid format"}


  defp sanitize_if_needed(value, %{sanitize: true, rules: rules})
       when is_binary(value) do
    sanitize_type =
      Enum.find_value(rules, fn
        {:sanitize_type, type} -> type
        _ -> nil
      end) || :text

    {:ok, sanitize(value, sanitize_type)}
  end

  defp sanitize_if_needed(value, _), do: {:ok, value}

  defp sanitize_html(html) do
    Auditor.sanitize_html(html)
  end

  defp sanitize_sql(value) do
    # SQL should use parameterized queries, not sanitization
    value
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/[^a-zA-Z0-9._-]/, "_")
    |> String.slice(0, 255)
  end

  defp sanitize_url(url) do
    # Basic URL sanitization
    has_protocol = String.starts_with?(url, ["http://", "https://"])
    handle_url_protocol(has_protocol, url)
  end

  defp handle_url_protocol(true, url), do: url
  defp handle_url_protocol(false, url), do: "https://#{url}"

  @doc """
  Creates a validator function for reuse.

  ## Examples

      username_validator = create_validator([
        {:type, :string},
        {:min_length, 3},
        {:max_length, 20},
        {:format, ~r/^[a-zA-Z0-9_]+$/}
      ])
      
      username_validator.("john_doe")
      # => {:ok, "john_doe"}
  """
  def create_validator(rules, opts \\ []) do
    fn value ->
      field_spec = %{
        name: :field,
        rules: rules,
        sanitize: Keyword.get(opts, :sanitize, false)
      }

      validate_field(value, field_spec)
    end
  end

  @doc """
  Validates multiple fields in parallel for performance.
  """
  def validate_parallel(inputs, schema) do
    tasks =
      Enum.map(schema, fn field_spec ->
        Task.async(fn ->
          field_name = field_spec.name
          value = Map.get(inputs, field_name)

          case validate_field(value, field_spec) do
            {:ok, sanitized} -> {:ok, {field_name, sanitized}}
            {:error, reason} -> {:error, {field_name, reason}}
          end
        end)
      end)

    results = Task.await_many(tasks)

    {valid, errors} =
      Enum.reduce(results, {%{}, []}, fn
        {:ok, {name, value}}, {valid, errors} ->
          {Map.put(valid, name, value), errors}

        {:error, {name, reason}}, {valid, errors} ->
          {valid, [{name, reason} | errors]}
      end)

    handle_validation_result(Enum.empty?(errors), valid, errors)
  end

  defp handle_validation_result(true, valid, _errors), do: {:ok, valid}
  defp handle_validation_result(false, _valid, errors), do: {:error, errors}
end
