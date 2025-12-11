defmodule Raxol.Core.ErrorHandler do
  alias Raxol.Core.Runtime.Log

  @moduledoc """
  Centralized error handling module for the Raxol application.

  Provides consistent error handling, logging, and recovery mechanisms
  across all modules in the system.

  ## Features

  - Standardized error types and messages
  - Automatic error logging with context
  - Graceful degradation strategies
  - Error recovery mechanisms
  - Telemetry integration for error monitoring

  ## Usage

      import Raxol.Core.ErrorHandler
      
      # Handle errors with automatic logging
      with_error_handling :file_operation do
        File.read!("/path/to/file")
      end
      
      # Custom error recovery
      handle_error {:error, :not_found}, default: "default_value"
  """
  @type error_type ::
          :validation
          | :runtime
          | :system
          | :network
          | :permission
          | :not_found
          | :timeout
  @type error_severity :: :debug | :info | :warning | :error | :critical
  @type error_context :: map()

  @type error_result ::
          {:error, error_type, String.t()}
          | {:error, error_type, String.t(), error_context}

  @doc """
  Wraps a function call with error handling and logging.

  ## Options

  - `:context` - Additional context to log with errors
  - `:severity` - Error severity level (default: :error)
  - `:fallback` - Fallback value on error
  - `:retry` - Number of retry attempts (default: 0)
  - `:retry_delay` - Delay between retries in ms (default: 1000)

  ## Examples

      with_error_handling(:database_query, context: %{user_id: 123}) do
        Repo.get!(User, user_id)
      end
  """
  defmacro with_error_handling(operation, opts \\ [], do: block) do
    quote do
      Raxol.Core.ErrorHandler.execute_with_handling(
        unquote(operation),
        unquote(opts),
        fn -> unquote(block) end
      )
    end
  end

  @doc """
  Executes a function with error handling.
  """
  def execute_with_handling(operation, opts, fun) do
    context = Keyword.get(opts, :context, %{})
    severity = Keyword.get(opts, :severity, :error)
    fallback = Keyword.get(opts, :fallback)
    retry_count = Keyword.get(opts, :retry, 0)
    retry_delay = Keyword.get(opts, :retry_delay, 1000)

    do_execute(
      operation,
      fun,
      context,
      severity,
      fallback,
      retry_count,
      retry_delay
    )
  end

  defp do_execute(
         operation,
         fun,
         context,
         severity,
         fallback,
         retries_left,
         retry_delay
       ) do
    case Raxol.Core.ErrorHandling.safe_call(fun) do
      {:ok, result} ->
        case result do
          {:ok, _} = ok_result -> ok_result
          {:error, _} = error_result -> error_result
          value -> {:ok, value}
        end

      {:error, error} when is_exception(error) ->
        handle_rescued_error(
          operation,
          error,
          context,
          severity,
          fallback,
          retries_left,
          retry_delay,
          fun
        )

      {:error, {:exit, reason}} ->
        handle_rescued_error(
          operation,
          {:exit, reason},
          context,
          severity,
          fallback,
          retries_left,
          retry_delay,
          fun
        )

      {:error, {error, _stacktrace}} ->
        handle_rescued_error(
          operation,
          error,
          context,
          severity,
          fallback,
          retries_left,
          retry_delay,
          fun
        )

      {:error, other_error} ->
        handle_rescued_error(
          operation,
          other_error,
          context,
          severity,
          fallback,
          retries_left,
          retry_delay,
          fun
        )
    end
  end

  @spec handle_rescued_error(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any()
        ) :: {:ok, any()} | {:error, any()}
  defp handle_rescued_error(
         operation,
         error,
         context,
         severity,
         fallback,
         retries_left,
         retry_delay,
         fun
       ) do
    execute_with_retry(
      retries_left > 0,
      operation,
      error,
      context,
      severity,
      fallback,
      retries_left,
      retry_delay,
      fun
    )
  end

  @spec execute_with_retry(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any()
        ) :: any()
  defp execute_with_retry(
         true,
         operation,
         error,
         context,
         severity,
         fallback,
         retries_left,
         retry_delay,
         fun
       ) do
    log_retry(operation, error, retries_left)
    Process.sleep(retry_delay)

    do_execute(
      operation,
      fun,
      context,
      severity,
      fallback,
      retries_left - 1,
      retry_delay
    )
  end

  @spec execute_with_retry(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any()
        ) :: any()
  defp execute_with_retry(
         false,
         operation,
         error,
         context,
         severity,
         fallback,
         _retries_left,
         _retry_delay,
         _fun
       ) do
    log_error(operation, error, context, severity)
    emit_telemetry(operation, :error, context)
    handle_fallback(fallback, error, context)
  end

  @spec handle_fallback(any(), any(), any()) ::
          {:ok, any()} | {:error, atom(), String.t(), map()}
  defp handle_fallback(nil, error, context) do
    {:error, :runtime, format_error_message(error), context}
  end

  defp handle_fallback(fallback, _error, _context) do
    {:ok, fallback}
  end

  @doc """
  Creates a standardized error tuple.

  ## Examples

      error(:validation, "Invalid email format")
      error(:not_found, "User not found", %{user_id: 123})
  """
  def error(type, message, context \\ %{}) do
    {:error, type, message, context}
  end

  @doc """
  Handles an error result with optional recovery.

  ## Examples

      result
      |> handle_error(default: "fallback")
      |> handle_error(with: fn error -> recover(error) end)
  """
  def handle_error({:ok, value}, _opts), do: {:ok, value}

  def handle_error({:error, _type, _message, _context} = error, opts) do
    case {Keyword.get(opts, :default), Keyword.get(opts, :with)} do
      {default, _} when default != nil -> {:ok, default}
      {_, handler} when is_function(handler) -> handler.(error)
      {nil, nil} -> error
    end
  end

  def handle_error({:error, reason}, opts) do
    handle_error({:error, :unknown, inspect(reason), %{}}, opts)
  end

  @doc """
  Converts various error formats to standardized format.
  """
  def normalize_error({:error, type, message, context}) when is_atom(type) do
    {:error, type, message, context}
  end

  def normalize_error({:error, type, message}) when is_atom(type) do
    {:error, type, message, %{}}
  end

  def normalize_error({:error, reason}) do
    {:error, :unknown, inspect(reason), %{}}
  end

  def normalize_error(error) do
    {:error, :unknown, inspect(error), %{}}
  end

  @doc """
  Logs an error with context.
  """
  def log_error(operation, error, context \\ %{}, severity \\ :error) do
    message = format_log_message(operation, error)

    metadata =
      Map.merge(context, %{
        operation: operation,
        error_type: classify_error(error)
      })

    case severity do
      :debug -> Log.debug(message, metadata)
      :info -> Log.info(message, metadata)
      :warning -> Log.warning(message, metadata)
      :error -> Log.error(message, metadata)
      :critical -> Log.error("[CRITICAL] #{message}", metadata)
    end
  end

  @doc """
  Chains multiple operations with error handling.

  ## Examples

      pipeline do
        step :validate_input, &validate/1
        step :process_data, &process/1
        step :save_result, &save/1
      end
  """
  defmacro pipeline(do: steps) do
    quote do
      Raxol.Core.ErrorHandler.execute_pipeline(unquote(steps))
    end
  end

  def execute_pipeline(steps) do
    Enum.reduce_while(steps, {:ok, nil}, fn
      {:step, name, fun}, {:ok, prev_result} ->
        case execute_step(name, fun, prev_result) do
          {:ok, result} -> {:cont, {:ok, result}}
          error -> {:halt, error}
        end
    end)
  end

  defp execute_step(name, fun, input) do
    with_error_handling(name) do
      fun.(input)
    end
  end

  # Private helper functions

  defp format_error_message(error) do
    case error do
      %{message: msg} -> msg
      %{__struct__: module} -> "#{module}: #{inspect(error)}"
      _ -> inspect(error)
    end
  end

  defp format_log_message(operation, error) do
    "[#{operation}] #{format_error_message(error)}"
  end

  defp classify_error(%ArgumentError{}), do: :validation
  defp classify_error(%RuntimeError{}), do: :runtime
  defp classify_error(%File.Error{}), do: :system

  # defp classify_error(%Jason.DecodeError{}), do: :validation  # Commented out due to missing module
  defp classify_error(_error), do: :unknown

  defp log_retry(operation, error, retries_left) do
    Log.info(
      "[#{operation}] Retrying after error: #{inspect(error)}. Retries left: #{retries_left}"
    )
  end

  defp emit_telemetry(operation, event, metadata) do
    :telemetry.execute(
      [:raxol, :error_handler, event],
      %{count: 1},
      Map.merge(metadata, %{operation: operation})
    )
  end

  @doc """
  Creates a supervisor-friendly error handler for GenServer processes.
  """
  def handle_genserver_error(error, state, module) do
    log_error("#{module}.handle_error", error, %{
      module: module,
      state_keys: Map.keys(state)
    })

    case error do
      {:error, :timeout, _msg, _context} ->
        {:stop, :timeout, state}

      {:error, :critical, _msg, _context} ->
        {:stop, :critical_error, state}

      _ ->
        {:noreply, state}
    end
  end
end
