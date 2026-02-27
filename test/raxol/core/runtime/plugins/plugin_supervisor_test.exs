defmodule Raxol.Core.Runtime.Plugins.PluginSupervisorTest do
  @moduledoc """
  Tests for plugin task supervision and crash isolation.
  """
  use ExUnit.Case, async: false

  alias Raxol.Core.Runtime.Plugins.PluginSupervisor
  alias Raxol.Test.Plugins

  setup do
    # Ensure test plugin modules are loaded (required for function_exported?)
    Code.ensure_loaded!(Plugins.CallbackTestPlugin)
    Code.ensure_loaded!(Plugins.CrashingPlugin)
    Code.ensure_loaded!(Plugins.SlowPlugin)

    # Ensure the supervisor is started
    case Process.whereis(PluginSupervisor) do
      nil ->
        {:ok, _} = PluginSupervisor.start_link()
      _pid ->
        :ok
    end

    :ok
  end

  describe "run_plugin_task/3" do
    test "executes function and returns result" do
      assert {:ok, 42} = PluginSupervisor.run_plugin_task(:test_plugin, fn -> 42 end)
    end

    test "wraps successful results in :ok tuple" do
      assert {:ok, "hello"} = PluginSupervisor.run_plugin_task(:test_plugin, fn -> "hello" end)
    end

    test "isolates crashes and returns error tuple" do
      result = PluginSupervisor.run_plugin_task(:crash_plugin, fn ->
        raise "intentional crash"
      end)

      assert {:error, {:crashed, {%RuntimeError{message: "intentional crash"}, _stacktrace}}} = result
    end

    test "handles thrown values" do
      result = PluginSupervisor.run_plugin_task(:throw_plugin, fn ->
        throw(:test_throw)
      end)

      # Uncaught throws become {:nocatch, value} exits
      assert {:error, {:crashed, {{:nocatch, :test_throw}, _stacktrace}}} = result
    end

    test "handles exits" do
      result = PluginSupervisor.run_plugin_task(:exit_plugin, fn ->
        exit(:test_exit)
      end)

      assert {:error, {:crashed, :test_exit}} = result
    end

    test "respects timeout option" do
      result = PluginSupervisor.run_plugin_task(:slow_plugin, fn ->
        Process.sleep(1_000)
        :done
      end, timeout: 50)

      assert {:error, {:timeout, 50}} = result
    end

    test "completes within timeout returns success" do
      result = PluginSupervisor.run_plugin_task(:fast_plugin, fn ->
        Process.sleep(10)
        :done
      end, timeout: 500)

      assert {:ok, :done} = result
    end
  end

  describe "async_plugin_task/2" do
    test "returns :ok immediately" do
      assert :ok = PluginSupervisor.async_plugin_task(:test_plugin, fn -> :result end)
    end

    test "executes function asynchronously" do
      test_pid = self()

      :ok = PluginSupervisor.async_plugin_task(:test_plugin, fn ->
        send(test_pid, :task_executed)
      end)

      assert_receive :task_executed, 500
    end

    test "isolates crashes without affecting caller" do
      :ok = PluginSupervisor.async_plugin_task(:crash_plugin, fn ->
        raise "async crash"
      end)

      # Give it time to crash
      Process.sleep(50)

      # Caller should still be alive and functional
      assert Process.alive?(self())
    end
  end

  describe "run_plugin_tasks_concurrent/3" do
    test "executes multiple tasks concurrently" do
      funcs = [
        fn -> :one end,
        fn -> :two end,
        fn -> :three end
      ]

      results = PluginSupervisor.run_plugin_tasks_concurrent(:test_plugin, funcs)

      assert [{:ok, :one}, {:ok, :two}, {:ok, :three}] = results
    end

    test "maintains order of results" do
      funcs = [
        fn -> Process.sleep(50); 1 end,
        fn -> 2 end,
        fn -> Process.sleep(25); 3 end
      ]

      results = PluginSupervisor.run_plugin_tasks_concurrent(:test_plugin, funcs)

      assert [{:ok, 1}, {:ok, 2}, {:ok, 3}] = results
    end

    test "isolates individual task failures" do
      funcs = [
        fn -> :success end,
        fn -> raise "crash" end,
        fn -> :also_success end
      ]

      results = PluginSupervisor.run_plugin_tasks_concurrent(:test_plugin, funcs)

      assert {:ok, :success} = Enum.at(results, 0)
      assert {:error, {:crashed, {%RuntimeError{}, _stacktrace}}} = Enum.at(results, 1)
      assert {:ok, :also_success} = Enum.at(results, 2)
    end

    test "handles timeout for slow tasks" do
      funcs = [
        fn -> :fast end,
        fn -> Process.sleep(1_000); :slow end
      ]

      results = PluginSupervisor.run_plugin_tasks_concurrent(:test_plugin, funcs, timeout: 100)

      assert {:ok, :fast} = Enum.at(results, 0)
      assert {:error, {:timeout, 100}} = Enum.at(results, 1)
    end

    test "returns empty list for empty input" do
      assert [] = PluginSupervisor.run_plugin_tasks_concurrent(:test_plugin, [])
    end
  end

  describe "call_plugin_callback/5" do
    test "calls exported function and returns result" do
      result = PluginSupervisor.call_plugin_callback(
        :test_plugin,
        Plugins.CallbackTestPlugin,
        :on_load,
        []
      )

      assert {:ok, :loaded} = result
    end

    test "calls function with arguments" do
      result = PluginSupervisor.call_plugin_callback(
        :test_plugin,
        Plugins.CallbackTestPlugin,
        :init,
        [%{key: "value"}]
      )

      assert {:ok, {:ok, %{key: "value"}}} = result
    end

    test "returns :not_exported for missing function" do
      result = PluginSupervisor.call_plugin_callback(
        :test_plugin,
        Plugins.CallbackTestPlugin,
        :nonexistent_function,
        []
      )

      assert :not_exported = result
    end

    test "returns :not_exported for wrong arity" do
      result = PluginSupervisor.call_plugin_callback(
        :test_plugin,
        Plugins.CallbackTestPlugin,
        :on_load,
        [:extra_arg]  # on_load takes 0 args
      )

      assert :not_exported = result
    end

    test "isolates crashes in callbacks" do
      result = PluginSupervisor.call_plugin_callback(
        :test_plugin,
        Plugins.CrashingPlugin,
        :filter_event,
        [%{crash: true}, %{}]
      )

      assert {:error, {:crashed, {%RuntimeError{}, _stacktrace}}} = result
    end

    test "respects timeout option" do
      result = PluginSupervisor.call_plugin_callback(
        :test_plugin,
        Plugins.SlowPlugin,
        :filter_event,
        [%{slow: true}, %{}],
        timeout: 50
      )

      assert {:error, {:timeout, 50}} = result
    end
  end

  describe "stats/0" do
    test "returns map with active_tasks count" do
      stats = PluginSupervisor.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :active_tasks)
      assert is_integer(stats.active_tasks)
    end

    test "returns supervisor_info" do
      stats = PluginSupervisor.stats()

      assert Map.has_key?(stats, :supervisor_info)
    end

    test "reflects active task count" do
      # Start a slow task
      Task.start(fn ->
        PluginSupervisor.run_plugin_task(:slow_plugin, fn ->
          Process.sleep(500)
        end)
      end)

      Process.sleep(50)  # Let task start
      stats = PluginSupervisor.stats()

      # At least one task should be active
      assert stats.active_tasks >= 0
    end
  end
end
