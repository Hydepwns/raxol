defmodule Raxol.Test.MockDB do
  @moduledoc """
  A mock database adapter for testing purposes that implements all required Ecto adapter behaviors.
  """

  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Storage
  @behaviour Ecto.Adapter.Queryable
  @behaviour Ecto.Adapter.Schema
  @behaviour Ecto.Adapter.Migration

  defmacro __before_compile__(_env) do
    quote do
      def __adapter__, do: Raxol.Test.MockDB
      def __repo__, do: unquote(__MODULE__)
      def __pool__, do: Ecto.Adapters.SQL.Sandbox
    end
  end

  # Ecto.Adapter.Storage callbacks
  def storage_up(_config) do
    :ok
  end

  def storage_down(_config) do
    :ok
  end

  def storage_status(_config) do
    :up
  end

  # Ecto.Adapter callbacks
  def init(opts) do
    child_spec = %{
      id: __MODULE__,
      start: {Task, :start_link, [fn -> :ok end]},
      restart: :permanent,
      type: :worker
    }

    meta = %{pid: self(), repo: Keyword.get(opts, :repo)}
    {:ok, child_spec, meta}
  end

  def checked_out?(_meta), do: true

  def checkout(_, _, _) do
    {:ok, nil}
  end

  def loaders(_, _) do
    [&{:ok, &1}]
  end

  def dumpers(_, _) do
    [&{:ok, &1}]
  end

  def ensure_all_started(_config, _type) do
    {:ok, []}
  end

  def child_spec(_opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [[]]}}
  end

  def start_link(config) do
    case Task.start_link(fn -> Process.sleep(:infinity) end) do
      {:ok, pid} -> {:ok, pid, config}
      {:error, {:already_started, pid}} -> {:ok, pid, config}
      other -> other
    end
  end

  # Ecto.Adapter.Queryable callbacks
  def prepare(:explain, query), do: {:nocache, query}
  def prepare(_operation, query), do: {:cache, query, query}

  def execute(_meta, _query_cache, _query_params, _opts, _log) do
    # Return {:ok, num_rows, result}
    {:ok, 0, []}
  end

  def stream(_meta, _query_cache, _query_params, _opts, _log) do
    Stream.resource(
      fn -> [] end,
      fn
        [] -> {:halt, []}
        [h | t] -> {[h], t}
      end,
      fn _ -> :ok end
    )
  end

  # Ecto.Adapter.Schema callbacks
  def autogenerate(type) when type in [:id, :binary_id] do
    {:ok, Ecto.UUID.generate()}
  end

  def autogenerate(_other) do
    nil
  end

  def insert(_meta, _schema_meta, _fields, _on_conflict, returning, _log) do
    {:ok, Enum.map(returning, fn {_key, index} -> {index, nil} end)}
  end

  def insert_all(
        _meta,
        _schema_meta,
        _header,
        rows,
        _on_conflict,
        returning,
        _placeholders,
        _log
      ) do
    returned_rows =
      Enum.map(rows, fn _row ->
        Enum.map(returning, fn {_key, index} -> {index, nil} end)
      end)

    # Return {:ok, num_inserted, returned_values}
    {:ok, length(rows), returned_rows}
  end

  def update(_meta, _schema_meta, _fields, _filters, returning, _log) do
    {:ok, Enum.map(returning, fn {_key, index} -> {index, nil} end)}
  end

  def delete(_meta, _schema_meta, _filters, returning, _log) do
    {:ok, Enum.map(returning, fn {_key, index} -> {index, nil} end)}
  end

  # Ecto.Adapter.Migration callbacks
  def supports_ddl_transaction? do
    true
  end

  def execute_ddl(_command, _opts, _log) do
    :ok
  end

  def lock_for_migrations(_meta, _config, _lock) do
    # Mock success
    {:ok, nil}
  end

  def transaction(_, _, _) do
    {:ok, :mock_transaction}
  end

  def rollback(_, _) do
    {:ok, :mock_rollback}
  end
end
