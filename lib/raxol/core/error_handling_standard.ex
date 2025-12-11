defmodule Raxol.Core.ErrorHandlingStandard do
  alias Raxol.Core.Runtime.Log

  @moduledoc """
  Standardized error handling patterns for the Raxol application.

  This module defines the standard error handling patterns that should be
  used consistently across all Raxol modules.

  ## Error Tuple Convention

  All functions that can fail should return:
  - `{:ok, result}` on success
  - `{:error, reason}` or `{:error, reason, context}` on failure

  ## Error Types

  Use standardized error atoms:
  - `:invalid_argument` - Invalid function arguments
  - `:not_found` - Resource not found
  - `:permission_denied` - Insufficient permissions
  - `:timeout` - Operation timed out
  - `:connection_failed` - Network/connection error
  - `:invalid_state` - Invalid state for operation
  - `:resource_exhausted` - Resource limits exceeded

  ## Pattern Examples

      # Basic error handling
      def process_data(data) do
        with {:ok, validated} <- validate(data),
             {:ok, transformed} <- transform(validated),
             {:ok, result} <- save(transformed) do
          {:ok, result}
        else
          {:error, _reason} = error ->
            Log.error("Failed to process data")
            error
        end
      end

      # Error with context
      def fetch_user(id) do
        case Repo.get(User, id) do
          nil -> {:error, :not_found, %{user_id: id}}
          user -> {:ok, user}
        end
      end
  """
  # Standard error types used across the application.
  @type standard_error ::
          :invalid_argument
          | :not_found
          | :permission_denied
          | :timeout
          | :connection_failed
          | :invalid_state
          | :resource_exhausted
          | :internal_error
          | :not_implemented
          | :conflict
          | :precondition_failed

  # Standard error result tuple.
  @type error_result ::
          {:error, standard_error} | {:error, standard_error, map()}

  # Standard success result tuple.
  @type ok_result(type) :: {:ok, type}

  # Standard result type combining success and error.
  @type result(type) :: ok_result(type) | error_result()

  @doc """
  Converts various error formats to standard error tuples.
  """
  @spec normalize_error(term()) :: error_result()
  def normalize_error({:error, reason}) when is_atom(reason),
    do: {:error, reason}

  def normalize_error({:error, reason, context})
      when is_atom(reason) and is_map(context),
      do: {:error, reason, context}

  def normalize_error({:error, reason}),
    do: {:error, :internal_error, %{original: reason}}

  def normalize_error(:error), do: {:error, :internal_error}
  def normalize_error(other), do: {:error, :internal_error, %{original: other}}

  @doc """
  Chains multiple operations that return result tuples.

  ## Example

      chain_operations([
        fn -> validate_input(input) end,
        fn validated -> process(validated) end,
        fn processed -> save(processed) end
      ])
  """
  @spec chain_operations([(-> result(any()))]) :: result(any())
  def chain_operations(operations) do
    Enum.reduce_while(operations, {:ok, nil}, fn operation, {:ok, _prev} ->
      case operation.() do
        {:ok, result} -> {:cont, {:ok, result}}
        error -> {:halt, normalize_error(error)}
      end
    end)
  end

  @doc """
  Wraps a function that might raise an exception into a result tuple.
  """
  @spec safe_call((-> any()), standard_error()) ::
          {:ok, any()} | {:error, standard_error(), map()}
  def safe_call(fun, error_type \\ :internal_error) do
    try do
      {:ok, fun.()}
    rescue
      e ->
        Log.error("Exception caught: #{inspect(e)}")
        {:error, error_type, %{exception: e, stacktrace: __STACKTRACE__}}
    catch
      kind, reason ->
        Log.error("Caught #{kind}: #{inspect(reason)}")
        {:error, error_type, %{kind: kind, reason: reason}}
    end
  end

  @doc """
  Validates required fields in a map or struct.

  ## Example

      validate_required(%{name: "John"}, [:name, :email])
      # => {:error, :invalid_argument, %{missing_fields: [:email]}}
  """
  @spec validate_required(map(), [atom()]) ::
          {:ok, map()} | {:error, :invalid_argument, map()}
  def validate_required(data, required_fields) do
    missing = Enum.filter(required_fields, &(not Map.has_key?(data, &1)))

    case missing do
      [] -> {:ok, data}
      fields -> {:error, :invalid_argument, %{missing_fields: fields}}
    end
  end

  @doc """
  Retries an operation with exponential backoff.

  ## Options
  - `:max_attempts` - Maximum number of attempts (default: 3)
  - `:initial_delay` - Initial delay in ms (default: 100)
  - `:max_delay` - Maximum delay in ms (default: 5000)
  - `:jitter` - Add random jitter to delay (default: true)
  """
  @spec with_retry((-> result(any())), keyword()) :: result(any())
  def with_retry(fun, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    initial_delay = Keyword.get(opts, :initial_delay, 100)
    max_delay = Keyword.get(opts, :max_delay, 5000)
    jitter = Keyword.get(opts, :jitter, true)

    do_retry(fun, max_attempts, initial_delay, max_delay, jitter, 1)
  end

  defp do_retry(fun, max_attempts, delay, max_delay, jitter, attempt) do
    case fun.() do
      {:ok, _} = success ->
        success

      error when attempt >= max_attempts ->
        Log.warning("Max retry attempts reached (#{max_attempts})")
        error

      _error ->
        actual_delay = calculate_delay(delay, max_delay, jitter)

        Log.debug(
          "Retry attempt #{attempt}/#{max_attempts} after #{actual_delay}ms"
        )

        Process.sleep(actual_delay)

        next_delay = min(delay * 2, max_delay)
        do_retry(fun, max_attempts, next_delay, max_delay, jitter, attempt + 1)
    end
  end

  defp calculate_delay(base_delay, max_delay, true) do
    jitter = :rand.uniform(div(base_delay, 2))
    min(base_delay + jitter, max_delay)
  end

  defp calculate_delay(base_delay, max_delay, false) do
    min(base_delay, max_delay)
  end

  @doc """
  Aggregates multiple errors into a single error result.

  ## Example

      results = [
        {:ok, 1},
        {:error, :not_found, %{id: 2}},
        {:error, :timeout}
      ]

      aggregate_errors(results)
      # => {:error, :multiple_errors, %{errors: [...]}}
  """
  @spec aggregate_errors([result(any())]) ::
          {:ok, [any()]} | {:error, :multiple_errors, map()}
  def aggregate_errors(results) do
    {oks, errors} = Enum.split_with(results, &match?({:ok, _}, &1))

    case errors do
      [] ->
        values = Enum.map(oks, fn {:ok, value} -> value end)
        {:ok, values}

      _ ->
        error_details = Enum.map(errors, &normalize_error/1)

        {:error, :multiple_errors,
         %{errors: error_details, successful: length(oks)}}
    end
  end

  @doc """
  Maps over a result tuple, applying a function to the success value.

  ## Example

      {:ok, 5}
      |> map_ok(&(&1 * 2))
      # => {:ok, 10}
  """
  @spec map_ok(result(a), (a -> b)) :: result(b) when a: any(), b: any()
  def map_ok({:ok, value}, fun), do: {:ok, fun.(value)}
  def map_ok(error, _fun), do: error

  @doc """
  Flat maps over a result tuple.

  ## Example

      {:ok, 5}
      |> flat_map_ok(fn x -> {:ok, x * 2} end)
      # => {:ok, 10}
  """
  @spec flat_map_ok(result(a), (a -> result(b))) :: result(b)
        when a: any(), b: any()
  def flat_map_ok({:ok, value}, fun), do: fun.(value)
  def flat_map_ok(error, _fun), do: error

  @doc """
  Provides a default value for error cases.

  ## Example

      {:error, :not_found}
      |> with_default("default")
      # => "default"
  """
  @spec with_default(result(a), a) :: a when a: any()
  def with_default({:ok, value}, _default), do: value
  def with_default({:error, _}, default), do: default
  def with_default({:error, _, _}, default), do: default

  @doc """
  Logs and returns the error, useful in pipelines.

  ## Example

      {:error, :not_found, %{id: 123}}
      |> tap_error("User lookup failed")
      # Logs: "User lookup failed: {:error, :not_found, %{id: 123}}"
      # Returns: {:error, :not_found, %{id: 123}}
  """
  @spec tap_error(result(any()), String.t()) :: result(any())
  def tap_error({:error, _} = error, message) do
    Log.error("#{message}: #{inspect(error)}")
    error
  end

  def tap_error({:error, _, _} = error, message) do
    Log.error("#{message}: #{inspect(error)}")
    error
  end

  def tap_error(ok, _message), do: ok

  @doc """
  Ensures a result is returned, converting exceptions to errors.

  ## Example

      ensure_result(fn ->
        User.get!(123)
      end)
      # Returns {:ok, user} or {:error, :internal_error, %{...}}
  """
  @spec ensure_result((-> any())) :: result(any())
  def ensure_result(fun) do
    case safe_call(fun) do
      {:ok, {:ok, _} = result} -> result
      {:ok, {:error, _} = error} -> error
      {:ok, {:error, _, _} = error} -> error
      {:ok, value} -> {:ok, value}
      error -> error
    end
  end
end
