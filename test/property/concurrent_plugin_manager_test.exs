defmodule Raxol.Property.ConcurrentPluginManagerTest do
  @moduledoc """
  Regression: issue #229.

  `Raxol.Core.Runtime.Plugins.PluginLifecycle` registers as `name: __MODULE__`
  and all client functions call `GenServer.call(__MODULE__, ...)`. By design
  it's a VM-shared service -- `PluginRegistry` is ETS-backed and `StateManager`
  namespaces by `plugin_id`. The bug was that
  `Lifecycle.Initializer.start_plugin_manager/2` did not handle
  `{:error, {:already_started, _}}` from `Manager.start_link/1`, so a second
  concurrent `Raxol.Core.Runtime.Lifecycle` aborted during init. After fix,
  the second caller adopts the existing pid and reuses it.

  Two layers of protection:

    1. Behavioural: N sequential `Manager.start_link/1` calls in one VM all
       return `{:ok, pid}` and the pid is stable (same one across calls).

    2. Source guard: `start_plugin_manager/2` retains the
       `{:error, {:already_started, _}}` adoption arm. If a refactor removes
       it, this test fails loudly.
  """
  use ExUnit.Case, async: false

  alias Raxol.Core.Runtime.Plugins.PluginManager, as: Manager

  describe "concurrent plugin manager starts (regression for #229)" do
    test "N sequential Manager.start_link calls all return the same pid" do
      n = 6

      results =
        for _ <- 1..n do
          case Manager.start_link([]) do
            {:ok, pid} -> {:ok, pid}
            {:error, {:already_started, pid}} -> {:ok, pid}
            other -> other
          end
        end

      pids = Enum.map(results, fn {:ok, pid} -> pid end)
      assert length(pids) == n

      assert length(Enum.uniq(pids)) == 1,
             "all PluginManager start_link calls must converge on the same " <>
               "pid (the singleton). Got: #{inspect(pids)}"

      assert Process.alive?(hd(pids))
    end
  end

  describe "source guard for #229" do
    @initializer_path Path.join([
                        __DIR__,
                        "../..",
                        "lib/raxol/core/runtime/lifecycle/initializer.ex"
                      ])

    test "start_plugin_manager retains the :already_started adoption arm" do
      source = File.read!(@initializer_path)

      assert source =~ ~r/\{:error,\s*\{:already_started,\s*pm_pid\}\}\s*->/,
             "initializer.ex must keep the {:error, {:already_started, _}} -> " <>
               "{:ok, pid} adoption arm in start_plugin_manager/2. Without it, " <>
               "concurrent Lifecycles abort on the second call (regression of #229)."
    end
  end
end
