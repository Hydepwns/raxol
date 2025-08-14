defmodule Raxol.Core.CompilerState do
  @moduledoc """
  Thread-safe ETS table management for parallel compilation.

  Fixes race conditions causing: "table identifier does not refer to an existing ETS table"
  during parallel compilation processes accessing shared ETS tables.

  REFACTORED: All try/rescue blocks replaced with functional patterns.
  """

  @doc """
  Ensure ETS table exists with safe concurrency.

  This function handles race conditions where multiple processes might try to create
  the same ETS table simultaneously during parallel compilation.
  """
  def ensure_table(
        name,
        opts \\ [:named_table, :public, :set, {:read_concurrency, true}]
      ) do
    case :ets.info(name) do
      :undefined ->
        # Use a functional approach with safe_create_table
        safe_create_table(name, opts)

      _ ->
        # Table already exists
        :ok
    end
  end

  @doc """
  Safe ETS lookup with existence check.

  Performs ETS lookup operations with proper error handling for cases where
  the table might have been deleted by another process.
  """
  def safe_lookup(table, key) do
    with {:exists, true} <- {:exists, table_exists?(table)},
         {:ok, result} <- perform_safe_lookup(table, key) do
      {:ok, result}
    else
      {:exists, false} -> {:error, :table_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Safe ETS insert with existence check.

  Performs ETS insert operations with proper error handling for cases where
  the table might have been deleted by another process.
  """
  def safe_insert(table, data) do
    with {:exists, true} <- {:exists, table_exists?(table)},
         :ok <- perform_safe_insert(table, data) do
      :ok
    else
      {:exists, false} -> {:error, :table_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Safe ETS delete with existence check.

  Performs ETS delete operations with proper error handling for cases where
  the table might have been deleted by another process.
  """
  def safe_delete(table, key) do
    with {:exists, true} <- {:exists, table_exists?(table)},
         :ok <- perform_safe_delete(table, key) do
      :ok
    else
      {:exists, false} -> {:error, :table_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Safe ETS table deletion with existence check.

  Deletes an entire ETS table with proper error handling.
  """
  def safe_delete_table(table) do
    with {:exists, true} <- {:exists, table_exists?(table)},
         :ok <- perform_safe_delete_table(table) do
      :ok
    else
      {:exists, false} -> {:error, :table_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp table_exists?(table) do
    :ets.info(table) != :undefined
  end

  defp safe_create_table(name, opts) do
    # Use Task to isolate potential crashes and handle race conditions
    task = Task.async(fn ->
      :ets.new(name, opts)
      :ok
    end)

    case Task.yield(task, 100) || Task.shutdown(task, :brutal_kill) do
      {:ok, :ok} ->
        :ok

      nil ->
        # Timeout - check if another process created it
        if table_exists?(name), do: :ok, else: {:error, :creation_timeout}

      {:exit, {:badarg, _}} ->
        # Table creation failed - likely already exists
        if table_exists?(name), do: :ok, else: {:error, :creation_failed}

      {:exit, reason} ->
        # Unexpected error - check table existence as fallback
        if table_exists?(name), do: :ok, else: {:error, {:creation_error, reason}}
    end
  end

  defp perform_safe_lookup(table, key) do
    # Use Task to isolate potential ETS crashes
    task = Task.async(fn ->
      :ets.lookup(table, key)
    end)

    case Task.yield(task, 100) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        {:ok, result}

      nil ->
        {:error, :lookup_timeout}

      {:exit, {:badarg, _}} ->
        # Table was deleted during operation
        {:error, :table_not_found}

      {:exit, reason} ->
        {:error, {:lookup_error, reason}}
    end
  end

  defp perform_safe_insert(table, data) do
    # Use Task to isolate potential ETS crashes
    task = Task.async(fn ->
      :ets.insert(table, data)
    end)

    case Task.yield(task, 100) || Task.shutdown(task, :brutal_kill) do
      {:ok, true} ->
        :ok

      nil ->
        {:error, :insert_timeout}

      {:exit, {:badarg, _}} ->
        # Table was deleted during operation
        {:error, :table_not_found}

      {:exit, reason} ->
        {:error, {:insert_error, reason}}
    end
  end

  defp perform_safe_delete(table, key) do
    # Use Task to isolate potential ETS crashes
    task = Task.async(fn ->
      :ets.delete(table, key)
    end)

    case Task.yield(task, 100) || Task.shutdown(task, :brutal_kill) do
      {:ok, true} ->
        :ok

      nil ->
        {:error, :delete_timeout}

      {:exit, {:badarg, _}} ->
        # Table was deleted during operation
        {:error, :table_not_found}

      {:exit, reason} ->
        {:error, {:delete_error, reason}}
    end
  end

  defp perform_safe_delete_table(table) do
    # Use Task to isolate potential ETS crashes
    task = Task.async(fn ->
      :ets.delete(table)
    end)

    case Task.yield(task, 100) || Task.shutdown(task, :brutal_kill) do
      {:ok, true} ->
        :ok

      nil ->
        {:error, :delete_table_timeout}

      {:exit, {:badarg, _}} ->
        # Table already deleted
        {:error, :table_not_found}

      {:exit, reason} ->
        {:error, {:delete_table_error, reason}}
    end
  end
end