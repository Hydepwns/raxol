defmodule Raxol.Query do
  @moduledoc """
  Safe query building utilities for Raxol.

  Provides functions for building parameterized queries to prevent SQL injection.

  ## Example

      {:ok, result} = Raxol.Query.parameterized(
        "SELECT * FROM users WHERE id = ?",
        [user_id]
      )
  """

  @doc """
  Create a parameterized query.

  Returns a query structure that safely separates the query template
  from user-provided values.

  ## Example

      {:ok, query} = Raxol.Query.parameterized(
        "SELECT * FROM users WHERE id = ? AND active = ?",
        [user_id, true]
      )

      # query => %{sql: "SELECT * FROM users WHERE id = $1 AND active = $2", params: [user_id, true]}
  """
  @type query :: %{sql: String.t(), params: list()}

  @spec parameterized(String.t(), list()) :: {:ok, query()}
  def parameterized(template, params)
      when is_binary(template) and is_list(params) do
    # Count placeholders
    placeholder_count = count_placeholders(template)

    if placeholder_count != length(params) do
      {:error, {:param_mismatch, placeholder_count, length(params)}}
    else
      # Convert ? placeholders to numbered placeholders ($1, $2, etc.)
      {sql, _} =
        Enum.reduce(1..placeholder_count, {template, 1}, fn _, {sql, n} ->
          {String.replace(sql, "?", "$#{n}", global: false), n + 1}
        end)

      {:ok, %{sql: sql, params: params, template: template}}
    end
  end

  @doc """
  Execute a parameterized query (stub - requires database adapter).

  In a real implementation, this would execute against a database.
  """
  @spec execute(query()) :: {:ok, []}
  def execute(%{sql: _sql, params: _params}) do
    # This is a stub - actual implementation would use a database adapter
    {:ok, []}
  end

  @doc """
  Build a safe LIKE pattern.

  Escapes special characters in the pattern to prevent injection.

  ## Example

      pattern = Raxol.Query.like_pattern("user%input")
      # => "user\\%input%"
  """
  @spec like_pattern(String.t()) :: String.t()
  def like_pattern(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
    |> Kernel.<>("%")
  end

  @doc """
  Build a safe IN clause.

  ## Example

      {:ok, clause, params} = Raxol.Query.in_clause([1, 2, 3])
      # => {:ok, "$1, $2, $3", [1, 2, 3]}
  """
  @spec in_clause(list()) :: {:ok, String.t(), list()} | {:error, term()}
  def in_clause([]), do: {:error, :empty_list}

  def in_clause(values) when is_list(values) do
    placeholders =
      values
      |> Enum.with_index(1)
      |> Enum.map(fn {_v, i} -> "$#{i}" end)
      |> Enum.join(", ")

    {:ok, placeholders, values}
  end

  @doc """
  Validate that a value is safe for use in a query.

  ## Example

      :ok = Raxol.Query.validate_value("normal string")
      {:error, :unsafe} = Raxol.Query.validate_value("'; DROP TABLE users; --")
  """
  @spec validate_value(any()) :: :ok | {:error, :unsafe}
  def validate_value(value) when is_binary(value) do
    dangerous_patterns = [
      ~r/;\s*DROP\s+/i,
      ~r/;\s*DELETE\s+/i,
      ~r/;\s*UPDATE\s+/i,
      ~r/;\s*INSERT\s+/i,
      ~r/UNION\s+SELECT/i,
      ~r/--\s*$/,
      ~r/\/\*.*\*\//
    ]

    if Enum.any?(dangerous_patterns, &Regex.match?(&1, value)) do
      {:error, :unsafe}
    else
      :ok
    end
  end

  def validate_value(_), do: :ok

  # Private helpers

  defp count_placeholders(template) do
    template
    |> String.graphemes()
    |> Enum.count(&(&1 == "?"))
  end
end
