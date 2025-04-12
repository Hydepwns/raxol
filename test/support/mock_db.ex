defmodule Raxol.Test.MockDB do
  @moduledoc """
  A mock database adapter for testing purposes that implements all required Ecto adapter behaviors.
  """

  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Storage
  @behaviour Ecto.Adapter.Queryable
  @behaviour Ecto.Adapter.Schema
  @behaviour Ecto.Adapter.Migration
  @behaviour Ecto.Adapter.Prepare

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

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {Task, :start_link, [fn -> :ok end]},
      restart: :permanent,
      type: :worker
    }
  end

  def start_link(config) do
    {:ok, pid} = Task.start_link(fn -> Process.sleep(:infinity) end)
    {:ok, pid, config}
  end

  # Ecto.Adapter.Queryable callbacks
  def prepare(operation, query) do
    {:nocache, {operation, query}}
  end

  def execute(_, _, _, _) do
    {:ok, %{rows: [], columns: []}}
  end

  def stream(_, _, _, _) do
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
  def autogenerate(_) do
    {:ok, 1}
  end

  def insert(_, _, _, _) do
    {:ok, %{}}
  end

  def insert_all(_, _, _, _, _, _) do
    {1, []}
  end

  def update(_, _, _, _, _) do
    {:ok, %{}}
  end

  def delete(_, _, _, _) do
    {:ok, %{}}
  end

  # Ecto.Adapter.Migration callbacks
  def supports_ddl_transaction? do
    true
  end

  def execute_ddl(_, _) do
    :ok
  end

  def transaction(_, _, _) do
    {:ok, :mock_transaction}
  end

  def rollback(_, _) do
    {:ok, :mock_rollback}
  end

  # Ecto.Adapter.Prepare callbacks
  def prepare(operation, query, _adapter) do
    {:nocache, {operation, query}}
  end
end
