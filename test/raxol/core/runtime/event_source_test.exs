defmodule Raxol.Core.Runtime.EventSourceTest do
  @moduledoc """
  Tests for the event source runtime system, including behavior implementation,
  initialization, failure handling, event dispatch, and process monitoring.
  """
  # Must be false due to process monitoring
  use ExUnit.Case, async: false

  alias Raxol.Core.Runtime.EventSourceTest.TestEventSource

  describe "EventSource behaviour" do
    setup do
      context = %{pid: self()}
      {:ok, context: context}
    end

    test "starts and initializes successfully", %{context: context} do
      args = %{data: :test_data}
      assert {:ok, pid} = TestEventSource.start_link(args, context)
      assert is_pid(pid)

      on_exit(fn ->
        if Process.alive?(pid), do: Process.exit(pid, :normal)
      end)
    end

    test "fails to initialize when requested", %{context: context} do
      Process.flag(:trap_exit, true)
      args = %{fail_init: true}
      result = TestEventSource.start_link(args, context)
      assert {:error, :init_failed} = result
    end

    test "sends events to subscriber", %{context: context} do
      args = %{data: :test_data}
      {:ok, pid} = TestEventSource.start_link(args, context)

      on_exit(fn ->
        if Process.alive?(pid), do: Process.exit(pid, :normal)
      end)

      send(pid, :send_event)
      assert_receive {:subscription, {:test_event, :test_data}}
    end

    test "stops normally", %{context: context} do
      args = %{data: :test_data}
      {:ok, pid} = TestEventSource.start_link(args, context)
      ref = Process.monitor(pid)

      send(pid, :stop)
      assert_receive :terminated_normally
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end

    test "handles crashes", %{context: context} do
      # Start a DynamicSupervisor for the test
      {:ok, sup} = DynamicSupervisor.start_link(strategy: :one_for_one)

      on_exit(fn ->
        if Process.alive?(sup), do: Process.exit(sup, :normal)
      end)

      # Start the event source under the supervisor
      child_spec = %{
        id: TestEventSource,
        start: {TestEventSource, :start_link, [%{data: :test_data}, context]},
        restart: :permanent
      }

      {:ok, pid} = DynamicSupervisor.start_child(sup, child_spec)

      # Monitor the process
      ref = Process.monitor(pid)

      # Kill the process
      Process.exit(pid, :kill)

      # Expect DOWN message
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 500

      # Wait for restart
      :timer.sleep(200)

      # Find the new child (should be restarted)
      [new_pid] =
        DynamicSupervisor.which_children(sup)
        |> Enum.map(fn {_, p, _, _} -> p end)

      assert Process.alive?(new_pid)

      # Clean up the new process
      on_exit(fn ->
        if Process.alive?(new_pid), do: Process.exit(new_pid, :normal)
      end)
    end
  end
end
