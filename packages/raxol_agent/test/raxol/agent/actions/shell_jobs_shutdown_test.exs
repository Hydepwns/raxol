defmodule Raxol.Agent.Actions.ShellJobsShutdownTest do
  @moduledoc """
  `Raxol.Agent.Shell.Jobs` teardown against the budget its supervisor honours.

  `terminate/2` is what reaps the OS side, and it only gets to finish if the
  supervisor waits for it. `use GenServer`'s default child_spec declares
  `shutdown: 5_000` while a sequential reap of a full job table needed far
  longer -- up to `Interrupt.default_grace_ms/0` of cooperative wait plus a
  500ms out-of-band group-death confirmation per job, with
  `@max_running_host` at 32. Past the budget the supervisor brutal-kills this
  process and every group not yet reaped is orphaned.

  Not `async` -- these tests stop the globally named `Jobs` singleton.
  """

  use ExUnit.Case, async: false

  @moduletag :unix_only

  alias Raxol.Agent.KillLab
  alias Raxol.Agent.Shell.Jobs

  @death_budget_ms 3_000
  @marker_budget_ms 2_000

  # The budget the OLD child_spec declared, and therefore the window the
  # supervisor used to allow before brutal-killing mid-reap.
  @old_default_shutdown_ms 5_000

  setup do
    owner =
      Path.join(
        System.tmp_dir!(),
        "raxol-shell-shutdown-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(owner)

    # `Jobs` is a globally named singleton and may already be linked to this
    # process (whoever first touched it called `start_link/1`). Stopping a
    # linked process would propagate `:shutdown` here and kill the test before
    # it can assert, so break the link and trap what is left.
    Process.flag(:trap_exit, true)
    {:ok, pid} = ensure_jobs_running()
    Process.unlink(pid)

    on_exit(fn ->
      # Later test modules (and anything else in this VM) still expect the
      # singleton to be up.
      ensure_jobs_running()
      File.rm_rf(owner)
    end)

    {:ok, owner: owner}
  end

  describe "the declared shutdown budget" do
    test "covers what terminate/2 can actually spend reaping" do
      # The defect was a contract mismatch, not a slow reap: the supervisor was
      # TOLD 5s while the callback needed more, so it killed the reap in
      # progress. Assert on what the supervisor consumes.
      spec = Jobs.child_spec([])

      assert spec.shutdown >= Jobs.terminate_timeout_ms(),
             "child_spec declares shutdown: #{inspect(spec.shutdown)}, which is " <>
               "less than terminate/2's own ceiling of " <>
               "#{Jobs.terminate_timeout_ms()}ms -- the supervisor will " <>
               "brutal-kill mid-reap and orphan the surviving process groups"
    end
  end

  describe "shutdown reaps the OS side" do
    test "every running job's tree is dead after a stop, inside the old 5s window",
         %{owner: owner} do
      # Four jobs, each backgrounding a child that outlives its shell, so an
      # unreaped group is directly observable as a live pid rather than
      # inferred from an exit status.
      jobs =
        for i <- 1..4 do
          marker = Path.join(owner, "child_#{i}.pid")

          {:ok, job} =
            Jobs.start("sleep 300 & echo $! > #{marker}; wait",
              owner: owner,
              timeout_ms: 60_000
            )

          {job, read_marker_pid(marker)}
        end

      for {job, child} <- jobs do
        assert KillLab.alive?(job.os_pid)
        assert KillLab.alive?(child)
      end

      # `GenServer.stop/3` with the old default models the supervisor's window:
      # if terminate/2 cannot finish inside it, this exits `:timeout` exactly
      # where the supervisor would have brutal-killed.
      {elapsed_us, :ok} =
        :timer.tc(fn -> GenServer.stop(Jobs, :shutdown, @old_default_shutdown_ms) end)

      for {job, child} <- jobs do
        assert KillLab.await_dead(job.os_pid, @death_budget_ms),
               "job #{job.job_id} survived shutdown"

        assert KillLab.await_dead(child, @death_budget_ms),
               "backgrounded child #{child} outlived shutdown -- orphaned group"
      end

      # Reported rather than asserted tightly: reap cost depends on how fast
      # the OS reaps cooperative children, so a tight bound here would be a
      # flake. The `GenServer.stop` timeout above is the real assertion.
      IO.puts("\n  shutdown reaped #{length(jobs)} jobs in #{div(elapsed_us, 1000)}ms")
    end
  end

  defp ensure_jobs_running do
    case Process.whereis(Jobs) do
      nil -> {:ok, _} = Jobs.start_link([])
      pid when is_pid(pid) -> {:ok, pid}
    end
  end

  defp read_marker_pid(marker, budget_ms \\ @marker_budget_ms)

  defp read_marker_pid(marker, budget_ms) when budget_ms <= 0 do
    flunk("background child never wrote its pid to #{marker}")
  end

  defp read_marker_pid(marker, budget_ms) do
    with {:ok, content} <- File.read(marker),
         {pid, ""} <- Integer.parse(String.trim(content)) do
      pid
    else
      _ ->
        Process.sleep(25)
        read_marker_pid(marker, budget_ms - 25)
    end
  end
end
