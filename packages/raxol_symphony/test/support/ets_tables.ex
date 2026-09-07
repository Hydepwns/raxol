defmodule Raxol.Symphony.Test.EtsTables do
  @moduledoc """
  Teardown for the named ETS tables a test hands to an adapter.

  These tests name a table and let `Raxol.Workflow.Checkpoint.Saver.Ets`,
  `Raxol.Symphony.Orchestrator.PausedSaver.Memory`, `Raxol.Agent.Cache.Ets` or
  `Raxol.Agent.ThreadLog.Ets` create it lazily on first use, which makes the
  creating process the table's owner. ERTS reaps an owner's tables as that
  process exits, and the reaping runs concurrently with `on_exit`, which ExUnit
  executes in its own process once the test process is already down.

  That makes the obvious teardown a check-then-act race:

      if :ets.whereis(table) != :undefined, do: :ets.delete(table)

  `whereis` resolves, the reaper frees the table, and the delete raises
  `ArgumentError`. It took `Raxol.Agent.ThreadLogRouterTest` red on a loaded CI
  runner with every assertion passing and the failure inside `on_exit`.

  Deleting is still worth doing -- a table created inside a runner process that
  outlives the test would otherwise sit there for the rest of the run -- so
  drop the guard and tolerate the one outcome that is the goal state anyway.
  """

  @doc """
  Deletes `tables`, tolerating any that are already gone.

  A table that is still live and still refuses the delete is a real badarg and
  is reraised. Deliberately a copy of `Raxol.Agent.Test.EtsTables`: raxol_agent
  is an optional dependency here and its `test/support` is not shipped.
  """
  def drop(tables) when is_list(tables), do: Enum.each(tables, &drop/1)

  def drop(table) do
    :ets.delete(table)
    :ok
  rescue
    error in ArgumentError ->
      if :ets.whereis(table) == :undefined,
        do: :ok,
        else: reraise(error, __STACKTRACE__)
  end
end
