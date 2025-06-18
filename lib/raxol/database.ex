defmodule Raxol.Database do
  @moduledoc '''
  Provides a safe interface for database operations.

  This module:
  - Wraps all database operations with retry logic
  - Provides convenience functions for common database operations
  - Handles database errors gracefully
  '''

  alias Raxol.Database.ConnectionManager
  alias Raxol.Repo

  @doc '''
  Safely executes a database query with retry logic.

  ## Parameters

  - `fun` - Function containing database operations

  ## Returns

  - `{:ok, result}` - Operation succeeded
  - `{:error, reason}` - Operation failed after retries
  '''
  def safe_query(fun) when is_function(fun, 0) do
    ConnectionManager.with_retries(fun)
  end

  @doc '''
  Gets a record by ID with retry logic.

  ## Parameters

  - `schema` - The schema module
  - `id` - The record ID

  ## Returns

  - `{:ok, record}` - Record found
  - `{:error, :not_found}` - Record not found
  - `{:error, reason}` - Query failed
  '''
  def get(schema, id) do
    case safe_query(fn -> Repo.get(schema, id) end) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, record} -> {:ok, record}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc '''
  Creates a record with retry logic.

  ## Parameters

  - `schema` - The schema module
  - `attrs` - The attributes for the new record

  ## Returns

  - `{:ok, record}` - Record created
  - `{:error, changeset}` - Validation failed
  - `{:error, reason}` - Query failed
  '''
  def create(schema, attrs) do
    safe_query(fn ->
      struct(schema)
      |> schema.changeset(attrs)
      |> Repo.insert()
    end)
    |> case do
      {:ok, {:ok, record}} -> {:ok, record}
      {:ok, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc '''
  Updates a record with retry logic.

  ## Parameters

  - `schema` - The schema module
  - `record` - The record to update
  - `attrs` - The new attributes

  ## Returns

  - `{:ok, record}` - Record updated
  - `{:error, changeset}` - Validation failed
  - `{:error, reason}` - Query failed
  '''
  def update(schema, record, attrs) do
    safe_query(fn ->
      record
      |> schema.changeset(attrs)
      |> Repo.update()
    end)
    |> case do
      {:ok, {:ok, updated}} -> {:ok, updated}
      {:ok, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc '''
  Deletes a record with retry logic.

  ## Parameters

  - `record` - The record to delete

  ## Returns

  - `{:ok, record}` - Record deleted
  - `{:error, changeset}` - Deletion validation failed
  - `{:error, reason}` - Query failed
  '''
  def delete(record) do
    safe_query(fn -> Repo.delete(record) end)
    |> case do
      {:ok, {:ok, deleted}} -> {:ok, deleted}
      {:ok, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc '''
  Gets all records of a schema with retry logic.

  ## Parameters

  - `schema` - The schema module
  - `clauses` - Optional where clauses

  ## Returns

  - `{:ok, records}` - Records found
  - `{:error, reason}` - Query failed
  '''
  def all(schema, clauses \\ []) do
    safe_query(fn -> Repo.all(schema, clauses) end)
  end

  @doc '''
  Executes a transaction with retry logic.

  ## Parameters

  - `fun` - Function containing transaction operations

  ## Returns

  - `{:ok, result}` - Transaction succeeded
  - `{:error, reason}` - Transaction failed
  '''
  def transaction(fun) when is_function(fun, 0) do
    safe_query(fn -> Repo.transaction(fun) end)
    |> case do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc '''
  Checks if the database connection is healthy.

  ## Returns

  - `true` - Connection is healthy
  - `false` - Connection is unhealthy
  '''
  def healthy? do
    ConnectionManager.healthy?()
  end

  @doc '''
  Restarts the database connection if it becomes unhealthy.

  ## Returns

  - `:ok` - Connection restart attempted
  '''
  def restart_connection do
    ConnectionManager.restart_connection()
  end
end
