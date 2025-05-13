defmodule Raxol.TestHelpers do
  @moduledoc """
  Common test helpers and utilities for the Raxol test suite.
  """

  import ExUnit.Assertions

  @doc """
  Waits for a condition to be true, with a timeout.
  Uses event-based synchronization instead of Process.sleep.
  """
  def wait_for_state(condition_fun, timeout_ms \\ 100) do
    start = System.monotonic_time(:millisecond)
    ref = make_ref()
    do_wait_for_state(condition_fun, start, timeout_ms, ref)
  end

  defp do_wait_for_state(condition_fun, start, timeout_ms, ref) do
    if condition_fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) - start < timeout_ms do
        Process.send_after(self(), {:check_condition, ref}, 100)

        receive do
          {:check_condition, received_ref} when received_ref == ref ->
            do_wait_for_state(condition_fun, start, timeout_ms, ref)
        after
          timeout_ms ->
            flunk("Condition not met within #{timeout_ms}ms")
        end
      else
        flunk("Condition not met within #{timeout_ms}ms")
      end
    end
  end

  @doc """
  Cleans up a process and waits for it to be down.
  """
  def cleanup_process(pid, timeout \\ 5000) do
    if Process.alive?(pid) do
      ref = Process.monitor(pid)
      Process.exit(pid, :normal)

      receive do
        {:DOWN, ^ref, :process, _pid, _reason} -> :ok
      after
        timeout -> :timeout
      end
    end
  end

  @doc """
  Cleans up an ETS table.
  """
  def cleanup_ets_table(table) do
    if :ets.whereis(table) != :undefined do
      :ets.delete_all_objects(table)
    end
  end

  @doc """
  Cleans up a registry.
  """
  def cleanup_registry(registry) do
    if Process.whereis(registry) do
      Registry.unregister(registry, self())
    end
  end

  @doc """
  Creates a temporary directory for test files.
  """
  def create_temp_dir do
    dir = Path.join(System.tmp_dir!(), "raxol_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(dir)
    dir
  end

  @doc """
  Cleans up a temporary directory.
  """
  def cleanup_temp_dir(dir) do
    File.rm_rf!(dir)
  end

  def start_test_event_source(args \\ %{}, context \\ %{pid: self()}) do
    case Raxol.Core.Runtime.EventSourceTest.TestEventSource.start_link(
           args,
           context
         ) do
      {:ok, pid} -> pid
      other -> other
    end
  end
end
