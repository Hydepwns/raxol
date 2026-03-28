defmodule Raxol.Test.TestUtils do
  @moduledoc false
  # Minimal test utilities for raxol_core standalone tests.

  import ExUnit.Assertions
  import ExUnit.Callbacks

  def setup_test_env(_opts \\ []) do
    Application.put_env(:raxol, :test_mode, true)
    Application.put_env(:raxol, :database_enabled, false)
    {:ok, %{env: :test}}
  end

  def setup_common_mocks, do: :ok

  def create_test_plugin(name, config \\ %{}) do
    %{
      name: name,
      module: String.to_atom("TestPlugin.#{name}"),
      config: config,
      enabled: true
    }
  end

  def cleanup_test_env(_env_or_context \\ :default) do
    Application.delete_env(:raxol, :test_mode)
    Application.delete_env(:raxol, :database_enabled)
    :ok
  end

  def start_named_process(module, opts \\ []) do
    name = :"#{module}_#{System.unique_integer([:positive])}"
    start_supervised({module, Keyword.put(opts, :name, name)})
  end

  def cleanup_process(pid, timeout \\ 5000) do
    if Process.alive?(pid) do
      ref = Process.monitor(pid)
      Process.exit(pid, :normal)

      receive do
        {:DOWN, ^ref, :process, _pid, _reason} -> :ok
      after
        timeout -> :timeout
      end
    else
      :ok
    end
  end

  def wait_for_state(condition_fun, timeout_ms \\ 100) do
    start = System.monotonic_time(:millisecond)
    do_wait(condition_fun, start, timeout_ms)
  end

  defp do_wait(condition_fun, start, timeout_ms) do
    if condition_fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) - start < timeout_ms do
        Process.sleep(10)
        do_wait(condition_fun, start, timeout_ms)
      else
        flunk("Condition not met within #{timeout_ms}ms")
      end
    end
  end
end
