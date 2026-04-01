defmodule Raxol.Performance.ETS.TableHelper do
  @moduledoc """
  Shared utilities for ETS table lifecycle management.
  """

  @doc """
  Creates a named ETS table if it doesn't already exist.
  Returns the table name (atom) in all cases.

  ## Examples

      ensure_table(:my_cache, [:set, :public, :named_table])
      ensure_table(:my_cache, [:set, :public, :named_table, read_concurrency: true])
  """
  @spec ensure_table(atom(), list()) :: atom()
  def ensure_table(name, opts \\ [:set, :public, :named_table]) do
    case :ets.whereis(name) do
      :undefined ->
        _ref = :ets.new(name, opts)
        name

      _ref ->
        name
    end
  rescue
    ArgumentError -> name
  end
end
