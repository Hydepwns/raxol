defmodule Raxol.Core.Utils.ErrorPatterns do
  @moduledoc """
  Consolidated error handling patterns used throughout the Raxol codebase.
  Provides consistent error handling, logging, and recovery mechanisms.
  """

  require Logger

  @type error_reason :: atom() | String.t() | term()
  @type result(success) :: {:ok, success} | {:error, error_reason()}

  @doc """
  Wraps a function call with standardized error handling and logging.
  """
  @spec with_error_handling((-> any()), keyword()) :: result(any())
  def with_error_handling(func, opts \\ []) do
    context = Keyword.get(opts, :context, "operation")
    log_errors = Keyword.get(opts, :log_errors, true)

    try do
      case func.() do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} = error ->
          if log_errors do
            Logger.warning("#{context} failed: #{inspect(reason)}")
          end

          error

        result ->
          {:ok, result}
      end
    rescue
      exception ->
        if log_errors do
          Logger.error("#{context} raised exception: #{inspect(exception)}")
        end

        {:error, {:exception, exception}}
    end
  end

  @doc """
  Validates input parameters with common validation patterns.
  """
  @spec validate_params(map(), list()) :: :ok | {:error, error_reason()}
  def validate_params(params, required_keys)
      when is_map(params) and is_list(required_keys) do
    case find_missing_keys(params, required_keys) do
      [] -> :ok
      missing -> {:error, {:missing_params, missing}}
    end
  end

  @doc """
  Standardized way to handle GenServer initialization errors.
  """
  @spec init_with_validation(any(), (any() -> result(any()))) ::
          {:ok, any()} | {:stop, any()}
  def init_with_validation(args, validator_func) do
    case validator_func.(args) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @doc """
  Common pattern for handling call timeouts.
  """
  @spec call_with_timeout(GenServer.server(), any(), timeout()) :: result(any())
  def call_with_timeout(server, request, timeout \\ 5000) do
    try do
      result = GenServer.call(server, request, timeout)
      {:ok, result}
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
      :exit, reason -> {:error, {:exit, reason}}
    end
  end

  @doc """
  Standardized error recovery with exponential backoff.
  """
  @spec retry_with_backoff((-> result(any())), keyword()) :: result(any())
  def retry_with_backoff(func, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    base_delay = Keyword.get(opts, :base_delay, 100)

    do_retry(func, 0, max_retries, base_delay)
  end

  @doc """
  Common pattern for resource cleanup on errors.
  """
  @spec with_cleanup((-> result(any())), (-> :ok)) :: result(any())
  def with_cleanup(func, cleanup_func) do
    case func.() do
      {:ok, _result} = success ->
        success

      {:error, _reason} = error ->
        cleanup_func.()
        error
    end
  end

  ## Private Functions

  defp find_missing_keys(params, required_keys) do
    required_keys
    |> Enum.filter(&(not Map.has_key?(params, &1)))
  end

  defp do_retry(_func, attempt, max_retries, _delay)
       when attempt >= max_retries do
    {:error, :max_retries_exceeded}
  end

  defp do_retry(func, attempt, max_retries, base_delay) do
    case func.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} when attempt < max_retries - 1 ->
        delay = (base_delay * :math.pow(2, attempt)) |> round()
        Process.sleep(delay)
        do_retry(func, attempt + 1, max_retries, base_delay)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
