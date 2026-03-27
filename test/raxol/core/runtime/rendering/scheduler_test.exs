defmodule Raxol.Core.Runtime.Rendering.SchedulerTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Rendering.Scheduler

  defp unique_name, do: :"scheduler_test_#{System.unique_integer([:positive])}"

  defp start_scheduler(opts \\ []) do
    name = Keyword.get(opts, :name, unique_name())
    engine_pid = Keyword.get(opts, :engine_pid, self())
    interval_ms = Keyword.get(opts, :interval_ms, 16)

    {:ok, pid} =
      Scheduler.start_link(
        name: name,
        engine_pid: engine_pid,
        interval_ms: interval_ms
      )

    pid
  end

  describe "init_manager/1" do
    test "starts with default interval" do
      pid = start_scheduler()
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with custom interval" do
      pid = start_scheduler(interval_ms: 100)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "enable/disable via cast" do
    test "sends render_frame to engine when enabled" do
      pid = start_scheduler(interval_ms: 10, engine_pid: self())

      GenServer.cast(pid, :enable)

      assert_receive {:"$gen_cast", :render_frame}, 200
      GenServer.stop(pid)
    end

    test "stops sending after disable" do
      pid = start_scheduler(interval_ms: 10, engine_pid: self())

      GenServer.cast(pid, :enable)
      assert_receive {:"$gen_cast", :render_frame}, 200

      GenServer.cast(pid, :disable)
      # Drain any in-flight messages
      receive do
        {:"$gen_cast", :render_frame} -> :ok
      after
        0 -> :ok
      end

      # After disable, no more frames should arrive
      refute_receive {:"$gen_cast", :render_frame}, 50
      GenServer.stop(pid)
    end

    test "enable is idempotent" do
      pid = start_scheduler(interval_ms: 50, engine_pid: self())

      GenServer.cast(pid, :enable)
      GenServer.cast(pid, :enable)

      # Should still work normally
      assert_receive {:"$gen_cast", :render_frame}, 200
      GenServer.stop(pid)
    end

    test "disable is idempotent" do
      pid = start_scheduler(interval_ms: 50)

      GenServer.cast(pid, :disable)
      GenServer.cast(pid, :disable)

      # Should not crash
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "set_interval via cast" do
    test "changes the tick interval" do
      pid = start_scheduler(interval_ms: 1000, engine_pid: self())

      # Change to fast interval and enable
      GenServer.cast(pid, {:set_interval, 10})
      GenServer.cast(pid, :enable)

      # Should get a frame at the faster rate
      assert_receive {:"$gen_cast", :render_frame}, 200
      GenServer.stop(pid)
    end
  end
end
