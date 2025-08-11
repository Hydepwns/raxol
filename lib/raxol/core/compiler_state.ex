defmodule Raxol.Core.CompilerState do
  @moduledoc """
  Thread-safe ETS table management for parallel compilation.

  Fixes race conditions causing: "table identifier does not refer to an existing ETS table"
  during parallel compilation processes accessing shared ETS tables.
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
        try do
          :ets.new(name, opts)
        rescue
          ArgumentError ->
            # Table may have been created by another process while we were trying
            case :ets.info(name) do
              :undefined ->
                # If still undefined after the race, re-raise the original error
                reraise ArgumentError, __STACKTRACE__

              _ ->
                # Table was created by another process, return success
                :ok
            end
        end

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
    case :ets.info(table) do
      :undefined ->
        {:error, :table_not_found}

      _ ->
        try do
          {:ok, :ets.lookup(table, key)}
        rescue
          ArgumentError ->
            {:error, :table_not_found}
        end
    end
  end

  @doc """
  Safe ETS insert with existence check.

  Performs ETS insert operations with proper error handling for cases where
  the table might have been deleted by another process.
  """
  def safe_insert(table, data) do
    case :ets.info(table) do
      :undefined ->
        {:error, :table_not_found}

      _ ->
        try do
          :ets.insert(table, data)
          :ok
        rescue
          ArgumentError ->
            {:error, :table_not_found}
        end
    end
  end

  @doc """
  Safe ETS delete with existence check.

  Performs ETS delete operations with proper error handling for cases where
  the table might have been deleted by another process.
  """
  def safe_delete(table, key) do
    case :ets.info(table) do
      :undefined ->
        {:error, :table_not_found}

      _ ->
        try do
          :ets.delete(table, key)
          :ok
        rescue
          ArgumentError ->
            {:error, :table_not_found}
        end
    end
  end

  @doc """
  Safe ETS table deletion with existence check.

  Deletes an entire ETS table with proper error handling.
  """
  def safe_delete_table(table) do
    case :ets.info(table) do
      :undefined ->
        {:error, :table_not_found}

      _ ->
        try do
          :ets.delete(table)
          :ok
        rescue
          ArgumentError ->
            {:error, :table_not_found}
        end
    end
  end
end
