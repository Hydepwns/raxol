# End-to-end AGI Cockpit Demo (Phase 2)
#
# Demonstrates the Phase 2 cockpit architecture:
# - Agent.Process with observe/think/act loop
# - Orchestrator with pane management
# - Pilot takeover/release protocol
# - ContextStore persistence across restarts
# - Protocol messages between agents and pilot
#
# Run with: mix run examples/agents/cockpit_e2e.exs

Logger.configure(level: :info)

alias Raxol.Agent.{Orchestrator, ContextStore, Protocol}
alias Raxol.Core.Runtime.Log

# -- Agent Modules (implement observe/think/act) ----------------------------

defmodule E2E.ScoutAgent do
  @moduledoc false

  @scan_files ~w(
    lib/raxol/agent.ex
    lib/raxol/agent/process.ex
    lib/raxol/agent/orchestrator.ex
    lib/raxol/agent/protocol.ex
    lib/raxol/agent/context_store.ex
  )

  @max_scans length(@scan_files)

  def init(_opts), do: {:ok, %{scanned: [], current: nil, total_lines: 0}}

  def observe(events, state) do
    pilot_inputs = for {:pilot_input, input} <- events, do: input
    {:ok, %{pilot_inputs: pilot_inputs}, state}
  end

  def think(%{pilot_inputs: [_ | _] = inputs}, state) do
    # During takeover, just acknowledge pilot input
    {:act, {:log_pilot, inputs}, state}
  end

  def think(_observation, %{scanned: scanned} = state)
      when length(scanned) >= @max_scans do
    {:wait, state}
  end

  def think(_observation, state) do
    remaining = @scan_files -- Enum.map(state.scanned, fn {f, _} -> f end)

    case remaining do
      [file | _] -> {:act, {:scan, file}, %{state | current: file}}
      [] -> {:wait, state}
    end
  end

  def act({:log_pilot, inputs}, state) do
    Enum.each(inputs, fn input ->
      Log.info("[Scout] Pilot typed: #{inspect(input)}")
    end)

    {:ok, state}
  end

  def act({:scan, file}, state) do
    lines =
      case File.read(file) do
        {:ok, content} -> content |> String.split("\n") |> length()
        {:error, _} -> 0
      end

    Log.info("[Scout] Scanned #{Path.basename(file)}: #{lines} lines")

    {:ok,
     %{
       state
       | scanned: [{file, lines} | state.scanned],
         total_lines: state.total_lines + lines,
         current: nil
     }}
  end

  def receive_directive({:priority, file}, state) do
    Log.info("[Scout] Received priority directive for #{file}")
    {:ok, state}
  end

  def receive_directive(_directive, state), do: {:ok, state}

  def context_snapshot(state), do: state
  def restore_context(snapshot), do: {:ok, snapshot}
end

defmodule E2E.AnalystAgent do
  @moduledoc false

  @check_modules ~w(
    Raxol.Agent.Process
    Raxol.Agent.Orchestrator
    Raxol.Agent.Protocol
    Raxol.Agent.ContextStore
    Raxol.Agent.Supervisor
  )

  @max_checks length(@check_modules)

  def init(_opts), do: {:ok, %{results: [], current: nil}}

  def observe(events, state) do
    directives = for {:pilot_input, input} <- events, do: input
    {:ok, %{directives: directives}, state}
  end

  def think(_observation, %{results: results} = state)
      when length(results) >= @max_checks do
    {:wait, state}
  end

  def think(_observation, state) do
    checked = Enum.map(state.results, fn {mod, _} -> mod end)
    remaining = @check_modules -- checked

    case remaining do
      [mod | _] -> {:act, {:check, mod}, %{state | current: mod}}
      [] -> {:wait, state}
    end
  end

  def act({:check, mod_name}, state) do
    module = String.to_existing_atom("Elixir.#{mod_name}")
    has_docs = function_exported?(module, :__info__, 1)

    exports =
      if has_docs do
        module.__info__(:functions) |> length()
      else
        0
      end

    Log.info("[Analyst] #{mod_name}: #{exports} exports")

    {:ok,
     %{
       state
       | results: [{mod_name, exports} | state.results],
         current: nil
     }}
  rescue
    _ ->
      Log.info("[Analyst] #{mod_name}: not loaded")
      {:ok, %{state | results: [{mod_name, 0} | state.results], current: nil}}
  end

  def receive_directive(_directive, state), do: {:ok, state}

  def context_snapshot(state), do: state
  def restore_context(snapshot), do: {:ok, snapshot}
end

# -- Infrastructure ---------------------------------------------------------

defmodule E2E.Infra do
  @moduledoc false

  def ensure_started do
    # Registry (may already be running from application.ex)
    case Registry.start_link(keys: :unique, name: Raxol.Agent.Registry) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # DynamicSupervisor for agents
    case DynamicSupervisor.start_link(
           name: Raxol.Agent.DynSup,
           strategy: :one_for_one
         ) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    ContextStore.init()
    :ok
  end
end

# -- Main Demo Flow ---------------------------------------------------------

defmodule E2E.Demo do
  @moduledoc false

  @separator String.duplicate("-", 60)
  @poll_interval_ms 500
  @max_polls 30

  def run do
    IO.puts("\n#{@separator}")
    IO.puts("  AGI Cockpit -- End-to-End Demo (Phase 2)")
    IO.puts(@separator)

    E2E.Infra.ensure_started()

    # 1. Start the Orchestrator
    IO.puts("\n[1] Starting Orchestrator...")
    {:ok, orch} = Orchestrator.start_link()
    IO.puts("    Orchestrator PID: #{inspect(orch)}")

    # 2. Spawn Scout agent
    IO.puts("\n[2] Spawning Scout agent...")

    {:ok, :scout} =
      Orchestrator.spawn_agent(orch, :scout, E2E.ScoutAgent,
        tick_ms: 300,
        label: "Scout"
      )

    # 3. Spawn Analyst agent
    IO.puts("[3] Spawning Analyst agent...")

    {:ok, :analyst} =
      Orchestrator.spawn_agent(orch, :analyst, E2E.AnalystAgent,
        tick_ms: 400,
        label: "Analyst"
      )

    # 4. Show layout
    layout = Orchestrator.get_layout(orch)
    IO.puts("\n[4] Layout:")
    IO.puts("    Panes: #{Map.keys(layout.panes) |> Enum.join(", ")}")
    IO.puts("    Focused: #{layout.focused}")
    IO.puts("    Mode: #{layout.pilot_mode}")

    # 5. Watch agents work
    IO.puts("\n[5] Watching agents work (observe/think/act cycles)...")
    poll_until_done(orch, 0)

    # 6. Show final statuses
    IO.puts("\n[6] Agent statuses:")
    statuses = Orchestrator.get_statuses(orch)

    for {id, status} <- statuses do
      IO.puts("    #{id}: #{status.status} (#{status.module})")
    end

    # 7. Pilot takeover demo
    IO.puts("\n[7] Pilot takeover of Scout...")
    :ok = Orchestrator.focus_pane(orch, :scout)
    :ok = Orchestrator.pilot_takeover(orch)

    layout = Orchestrator.get_layout(orch)
    IO.puts("    Mode: #{layout.pilot_mode}")
    IO.puts("    Focused: #{layout.focused}")

    # 8. Send pilot input (routed to Scout's event buffer)
    IO.puts("\n[8] Sending pilot input...")
    # No terminal_pid, so this returns :no_terminal -- which is expected
    # since we don't have a real terminal in this demo.
    # Instead, push events directly to show the mechanism.
    Raxol.Agent.Process.push_event(:scout, {:pilot_input, "ls -la"})
    Raxol.Agent.Process.push_event(:scout, {:pilot_input, "cat README.md"})
    IO.puts("    Pushed 2 pilot input events to Scout")

    # Wait for Scout to process them on next tick
    :timer.sleep(500)

    # 9. Pilot release
    IO.puts("\n[9] Releasing takeover...")
    :ok = Orchestrator.pilot_release(orch)

    layout = Orchestrator.get_layout(orch)
    IO.puts("    Mode: #{layout.pilot_mode}")

    # 10. Send a directive via Protocol
    IO.puts("\n[10] Sending Protocol message (directive)...")
    msg = Protocol.new(:pilot, :scout, :directive, %{priority: "agent.ex"})
    IO.puts("     #{inspect(msg.type)}: #{inspect(msg.payload)}")
    Orchestrator.send_directive(orch, :scout, {:priority, "agent.ex"})

    # 11. ContextStore persistence check
    IO.puts("\n[11] Context persistence check...")
    contexts = ContextStore.list()
    IO.puts("     Agents with saved context: #{inspect(contexts)}")

    for agent_id <- contexts do
      case ContextStore.load(agent_id) do
        {:ok, ctx} ->
          summary =
            cond do
              Map.has_key?(ctx, :scanned) ->
                "#{length(ctx.scanned)} files, #{ctx.total_lines} lines"

              Map.has_key?(ctx, :results) ->
                "#{length(ctx.results)} modules checked"

              true ->
                inspect(Map.keys(ctx))
            end

          IO.puts("     #{agent_id}: #{summary}")

        _ ->
          IO.puts("     #{agent_id}: (no context)")
      end
    end

    # 12. Kill and confirm cleanup
    IO.puts("\n[12] Killing agents and cleaning up...")
    Orchestrator.kill_agent(orch, :scout)
    Orchestrator.kill_agent(orch, :analyst)

    layout = Orchestrator.get_layout(orch)
    IO.puts("     Remaining agents: #{layout.agent_count}")

    IO.puts("\n#{@separator}")
    IO.puts("  Demo complete. Phase 2 cockpit verified end-to-end.")
    IO.puts("#{@separator}\n")
  end

  defp poll_until_done(_orch, n) when n >= @max_polls do
    IO.puts("    (max polls reached)")
  end

  defp poll_until_done(orch, n) do
    statuses = Orchestrator.get_statuses(orch)

    all_waiting =
      statuses
      |> Map.values()
      |> Enum.all?(fn s -> s.status == :waiting end)

    if all_waiting and n > 3 do
      IO.puts("    All agents idle after #{n} polls.")
    else
      :timer.sleep(@poll_interval_ms)
      poll_until_done(orch, n + 1)
    end
  end
end

# -- Run --------------------------------------------------------------------

E2E.Demo.run()
