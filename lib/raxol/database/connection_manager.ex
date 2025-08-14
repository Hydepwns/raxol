defmodule Raxol.Database.ConnectionManager do
  @moduledoc """
  Manages database connections and provides retry logic for Postgres errors.
  Functional Programming Version - All try/catch blocks replaced with Task-based error handling.

  This module:
  - Handles graceful connection retries
  - Monitors database connection health
  - Provides tools for debugging connection issues
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Repo

  @max_retries 5
  @retry_delay_ms 1000

  @doc """
  Attempts a database operation with retry logic.

  ## Parameters

  - `operation` - A function that performs a database operation
  - `max_retries` - Maximum number of retry attempts (default: 5)
  - `retry_delay_ms` - Delay between retries in milliseconds (default: 1000)

  ## Returns

  - `{:ok, result}` - Operation succeeded
  - `{:error, error}` - Operation failed after retries
  """
  @spec with_retries(function(), integer(), integer()) ::
          {:ok, any()} | {:error, any()}
  def with_retries(
        operation,
        max_retries \\ @max_retries,
        retry_delay_ms \\ @retry_delay_ms
      ) do
    retry_operation(operation, 0, max_retries, retry_delay_ms)
  end

  @doc """
  Checks if the database connection is healthy.

  ## Returns

  - `true` - Connection is healthy
  - `false` - Connection is unhealthy
  """
  @spec healthy?() :: boolean()
  def healthy? do
    with {:ok, _} <- safe_health_check() do
      true
    else
      {:error, error} ->
        Raxol.Core.Runtime.Log.error(
          "Database connection check failed with exception: #{inspect(error)}"
        )
        false
    end
  end

  @doc """
  Ensures the database connection is reset after application crash.

  This function should be called during application startup.
  """
  @spec ensure_connection() :: :ok
  def ensure_connection do
    if Process.whereis(Repo) do
      with {:ok, :healthy} <- safe_connection_check() do
        Raxol.Core.Runtime.Log.info("Database connection is healthy")
      else
        {:error, :unhealthy} ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Database connection is unhealthy, attempting to restart...",
            %{}
          )
          restart_connection()

        {:error, error} ->
          Raxol.Core.Runtime.Log.error(
            "Error checking database connection: #{inspect(error)}"
          )
          restart_connection()
      end
    else
      Raxol.Core.Runtime.Log.warning(
        "Repo process not found, database may not be started"
      )
    end

    :ok
  end

  @doc """
  Forcibly restarts the database connection.
  """
  @spec restart_connection() :: :ok
  def restart_connection do
    # Only attempt restart if the Repo process exists
    if Process.whereis(Repo) do
      Raxol.Core.Runtime.Log.info(
        "Attempting to restart database connection..."
      )

      # Close existing connections in the pool
      with {:ok, _} <- safe_close_connections() do
        Raxol.Core.Runtime.Log.info("Successfully closed existing connections")
      else
        {:error, error} ->
          Raxol.Core.Runtime.Log.error(
            "Exception closing existing connections: #{inspect(error)}"
          )
      end

      # Check connection again
      if healthy?() do
        Raxol.Core.Runtime.Log.info(
          "Database connection successfully restarted"
        )
      else
        Raxol.Core.Runtime.Log.error("Failed to restart database connection")
      end
    end

    :ok
  end

  # Private functions

  defp retry_operation(operation, attempt, max_retries, retry_delay_ms) do
    with {:ok, result} <- safe_execute_operation(operation) do
      {:ok, result}
    else
      {:error, %Postgrex.Error{} = e} ->
        handle_postgrex_error(
          e,
          operation,
          attempt,
          max_retries,
          retry_delay_ms
        )

      {:error, error} ->
        Raxol.Core.Runtime.Log.error(
          "Database operation failed with error: #{inspect(error)}"
        )

        if attempt < max_retries do
          Raxol.Core.Runtime.Log.info(
            "Retrying operation (attempt #{attempt + 1}/#{max_retries})..."
          )

          Process.sleep(retry_delay_ms)
          retry_operation(operation, attempt + 1, max_retries, retry_delay_ms)
        else
          Raxol.Core.Runtime.Log.error(
            "Operation failed after #{max_retries} attempts"
          )

          {:error, error}
        end
    end
  end

  defp handle_postgrex_error(
         error,
         operation,
         attempt,
         max_retries,
         retry_delay_ms
       ) do
    # Log detailed Postgrex error information for debugging
    Raxol.Core.Runtime.Log.error("Postgrex error: #{inspect(error)}")
    Raxol.Core.Runtime.Log.error("Postgres error code: #{error.postgres.code}")
    Raxol.Core.Runtime.Log.error("Postgres message: #{error.postgres.message}")

    # Check if the error is retryable (connection-related)
    retryable =
      case error.postgres.code do
        # Connection errors
        # connection_exception
        "08000" -> true
        # connection_does_not_exist
        "08003" -> true
        # connection_failure
        "08006" -> true
        # sqlclient_unable_to_establish_sqlconnection
        "08001" -> true
        # sqlserver_rejected_establishment_of_sqlconnection
        "08004" -> true
        # admin_shutdown
        "57P01" -> true
        # crash_shutdown
        "57P02" -> true
        # cannot_connect_now
        "57P03" -> true
        # Lock and deadlock errors (retryable)
        # deadlock_detected
        "40P01" -> true
        # lock_not_available
        "55P03" -> true
        # Other potentially retryable errors
        # serialization_failure
        "40001" -> true
        # statement_completion_unknown
        "40003" -> true
        # disk_full
        "53100" -> true
        # out_of_memory
        "53200" -> true
        # too_many_connections
        "53300" -> true
        _ -> false
      end

    if retryable and attempt < max_retries do
      # Exponential backoff for connection errors
      backoff_ms = retry_delay_ms * :math.pow(2, attempt)

      Raxol.Core.Runtime.Log.info(
        "Retrying operation after #{backoff_ms}ms (attempt #{attempt + 1}/#{max_retries})..."
      )

      Process.sleep(round(backoff_ms))
      retry_operation(operation, attempt + 1, max_retries, retry_delay_ms)
    else
      if not retryable do
        Raxol.Core.Runtime.Log.error(
          "Non-retryable Postgres error, giving up immediately"
        )
      else
        Raxol.Core.Runtime.Log.error(
          "Operation failed after #{max_retries} attempts"
        )
      end

      {:error, error}
    end
  end

  # Functional helper functions replacing try/catch with Task-based error handling

  defp safe_health_check do
    Task.async(fn -> Repo.custom_query("SELECT 1") end)
    |> Task.yield(5000)
    |> case do
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:health_check_failed, reason}}
      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_connection_check do
    Task.async(fn ->
      if healthy?() do
        :healthy
      else
        :unhealthy
      end
    end)
    |> Task.yield(3000)
    |> case do
      {:ok, :healthy} -> {:ok, :healthy}
      {:ok, :unhealthy} -> {:error, :unhealthy}
      {:exit, reason} -> {:error, {:connection_check_failed, reason}}
      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_close_connections do
    Task.async(fn ->
      Repo.custom_query(
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid()"
      )
    end)
    |> Task.yield(10000)
    |> case do
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:close_connections_failed, reason}}
      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end

  defp safe_execute_operation(operation) do
    Task.async(fn -> operation.() end)
    |> Task.yield(30000)
    |> case do
      {:ok, result} -> {:ok, result}
      {:exit, reason} -> {:error, reason}
      nil ->
        Task.shutdown(Task.async(fn -> :timeout end), :brutal_kill)
        {:error, :timeout}
    end
  end
end