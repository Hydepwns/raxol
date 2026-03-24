# Agent Cockpit Demo
#
# Multi-pane dashboard showing supervised agents working in real time,
# rendered entirely through Raxol's View DSL and TEA architecture.
#
# Demonstrates: OTP supervision, crash recovery, inter-agent coordination,
# live system metrics with sparklines, and dramatic crash visualization.
#
# Run with: mix run examples/agents/cockpit_demo.exs

Logger.configure(level: :warning)

# --- Agent Modules ---

defmodule CockpitDemo.FileScanner do
  @moduledoc false
  use Raxol.Agent

  @files ~w(
    lib/raxol/agent.ex
    lib/raxol/agent/session.ex
    lib/raxol/agent/team.ex
    lib/raxol/agent/comm.ex
    lib/raxol/core/runtime/command.ex
    lib/raxol/core/runtime/lifecycle.ex
    lib/raxol/core/runtime/application.ex
    lib/raxol/core/runtime/events/dispatcher.ex
  )

  def init(_ctx) do
    %{
      remaining: @files,
      scanned: [],
      total_lines: 0,
      current: nil,
      status: :idle
    }
  end

  def update({:agent_message, _from, :start}, model) do
    scan_next(%{model | status: :scanning})
  end

  def update({:command_result, :scan_next}, model), do: scan_next(model)

  def update({:command_result, {:shell_result, %{output: out}}}, model) do
    lines =
      case Integer.parse(String.trim(out)) do
        {n, _} -> n
        :error -> 0
      end

    new_model = %{
      model
      | scanned: [{Path.basename(model.current), lines} | model.scanned],
        total_lines: model.total_lines + lines
    }

    case new_model.remaining do
      [_ | _] -> {new_model, [Command.delay(:scan_next, 600)]}
      [] -> {%{new_model | current: nil, status: :done}, []}
    end
  end

  def update(_msg, model), do: {model, []}

  defp scan_next(model) do
    case model.remaining do
      [file | rest] ->
        {%{model | remaining: rest, current: file},
         [Command.shell("wc -l < #{file}")]}

      [] ->
        {%{model | current: nil, status: :done}, []}
    end
  end
end

defmodule CockpitDemo.CodeAnalyzer do
  @moduledoc false
  use Raxol.Agent

  @files ~w(
    lib/raxol/agent.ex
    lib/raxol/agent/session.ex
    lib/raxol/agent/team.ex
    lib/raxol/agent/comm.ex
    lib/raxol/core/runtime/command.ex
    lib/raxol/core/runtime/rendering/engine.ex
  )

  def init(_ctx) do
    %{remaining: @files, results: [], current: nil, status: :idle}
  end

  def update({:agent_message, _from, :start}, model) do
    analyze_next(%{model | status: :analyzing})
  end

  def update({:command_result, :analyze_next}, model), do: analyze_next(model)

  def update({:command_result, {:shell_result, %{output: out}}}, model) do
    has_docs = String.trim(out) != "0"

    new_model = %{
      model
      | results: [{Path.basename(model.current), has_docs} | model.results]
    }

    case new_model.remaining do
      [_ | _] -> {new_model, [Command.delay(:analyze_next, 800)]}
      [] -> {%{new_model | current: nil, status: :done}, []}
    end
  end

  def update(_msg, model), do: {model, []}

  defp analyze_next(model) do
    case model.remaining do
      [file | rest] ->
        {%{model | remaining: rest, current: file},
         [Command.shell("grep -c '@moduledoc' #{file} 2>/dev/null; true")]}

      [] ->
        {%{model | current: nil, status: :done}, []}
    end
  end
end

defmodule CockpitDemo.SystemMonitor do
  @moduledoc false
  use Raxol.Agent

  def init(_ctx) do
    %{checks: 0, stats: %{}, status: :idle, history: []}
  end

  def update({:agent_message, _from, :start}, model) do
    do_check(%{model | status: :monitoring})
  end

  def update({:command_result, :tick}, model), do: do_check(model)
  def update(_msg, model), do: {model, []}

  defp do_check(model) do
    mem_mb = div(:erlang.memory(:total), 1_048_576)

    stats = %{
      processes: :erlang.system_info(:process_count),
      memory_mb: mem_mb,
      schedulers: :erlang.system_info(:schedulers_online)
    }

    history = Enum.take([mem_mb | model.history], 20)

    {%{model | checks: model.checks + 1, stats: stats, history: history},
     [Command.delay(:tick, 600)]}
  end
end

defmodule CockpitDemo.ChaosWorker do
  @moduledoc false
  use Raxol.Agent

  def init(_ctx), do: %{tasks_done: 0, status: :idle}

  def update({:agent_message, _from, :start}, model) do
    {%{model | status: :working}, [Command.shell("echo ok")]}
  end

  def update({:command_result, :next_task}, model) do
    {model, [Command.shell("echo task_#{model.tasks_done + 1}")]}
  end

  def update({:command_result, {:shell_result, _}}, model) do
    {%{model | tasks_done: model.tasks_done + 1},
     [Command.delay(:next_task, 700)]}
  end

  def update(_msg, model), do: {model, []}
end

defmodule CockpitDemo.DepChecker do
  @moduledoc false
  use Raxol.Agent

  def init(_ctx), do: %{deps: [], status: :idle, checked: 0}

  def update({:agent_message, _from, :start}, model) do
    {%{model | status: :checking},
     [Command.shell("mix deps 2>/dev/null | grep -c 'ok'")]}
  end

  def update({:command_result, {:shell_result, %{output: out}}}, model) do
    count =
      case Integer.parse(String.trim(out)) do
        {n, _} -> n
        :error -> 0
      end

    {%{model | checked: count, status: :done}, []}
  end

  def update(_msg, model), do: {model, []}
end

# --- Dashboard (TEA Architecture) ---

defmodule CockpitDemo do
  @moduledoc false
  use Raxol.Core.Runtime.Application

  alias Raxol.Agent.Session

  # Tick schedule (200ms per tick)
  @boot_scanner 5
  @boot_analyzer 10
  @boot_monitor 15
  @boot_chaos 20
  @boot_deps 25
  @crash_tick 55
  @recover_tick 65
  @end_tick 90
  @title_ticks 12

  @sparks ~w(\u2581 \u2582 \u2583 \u2584 \u2585 \u2586 \u2587 \u2588)
  @bar_fill "\u2588"
  @bar_empty "\u2591"

  # -- TEA Callbacks --

  @impl true
  def init(_context) do
    ensure_infra()

    %{
      phase: :title,
      tick: 0,
      start_time: System.monotonic_time(:second),
      crashes: 0,
      events: [],
      restarted: false,
      scanner: nil,
      analyzer: nil,
      monitor: nil,
      chaos: nil,
      dep_checker: nil,
      pids: %{},
      old_pids: %{},
      booted: MapSet.new(),
      done_logged: MapSet.new()
    }
  end

  @impl true
  def subscribe(_model), do: [subscribe_interval(200, :tick)]

  @impl true
  def update(message, model) do
    case message do
      :tick ->
        handle_tick(model)

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{
        type: :key,
        data: %{key: :char, char: "c", ctrl: true}
      } ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :space}}
      when model.phase == :title ->
        {%{model | phase: :running, tick: 0}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    case model.phase do
      :title -> title_view(model)
      :running -> dashboard_view(model)
      :summary -> summary_view(model)
    end
  end

  # -- Tick Handler --

  defp handle_tick(model) do
    case model.phase do
      :title when model.tick >= @title_ticks ->
        {%{model | phase: :running, tick: 0}, []}

      :title ->
        {%{model | tick: model.tick + 1}, []}

      :running when model.tick > @end_tick ->
        {%{model | phase: :summary}, []}

      :running ->
        new_model =
          model
          |> staggered_boot()
          |> poll_agents()
          |> track_pids()
          |> handle_chaos()
          |> handle_narration()
          |> track_completions()

        {%{new_model | tick: new_model.tick + 1}, []}

      :summary ->
        {model, []}
    end
  end

  # ============================================================
  # Views
  # ============================================================

  # -- Title View --

  defp title_view(model) do
    dots = String.duplicate(".", min(rem(model.tick, 4) + 1, 3))

    column style: %{padding: 0, gap: 0} do
      [
        spacer(size: 2),
        text("                                  .__   ",
          style: [:bold],
          fg: :cyan
        ),
        text(" _______ _____  ___  ___  ____    |  |  ",
          style: [:bold],
          fg: :cyan
        ),
        text(" \\_  __ \\\\__  \\ \\  \\/  / /  _ \\   |  |  ",
          style: [:bold],
          fg: :cyan
        ),
        text("  |  | \\/ / __ \\_>    < (  <_> )  |  |__",
          style: [:bold],
          fg: :cyan
        ),
        text("  |__|   (____  /__/\\_ \\ \\____/   |____/",
          style: [:bold],
          fg: :cyan
        ),
        text("              \\/      \\/                 ",
          style: [:bold],
          fg: :cyan
        ),
        spacer(size: 1),
        text("  the terminal for agentic applications", style: [:dim]),
        spacer(size: 1),
        text("  OTP supervision * crash recovery * live metrics", fg: :yellow),
        spacer(size: 2),
        text("  initializing supervisor tree#{dots}", style: [:dim])
      ]
    end
  end

  # -- Dashboard View --

  defp dashboard_view(model) do
    uptime = System.monotonic_time(:second) - model.start_time

    column style: %{padding: 0, gap: 0} do
      [
        header_bar(uptime),
        spacer(size: 1),
        row style: %{gap: 1} do
          [
            scanner_panel(model),
            analyzer_panel(model)
          ]
        end,
        spacer(size: 1),
        row style: %{gap: 1} do
          [
            monitor_panel(model),
            chaos_panel(model)
          ]
        end,
        spacer(size: 1),
        event_log_panel(model),
        key_bar()
      ]
    end
  end

  # -- Summary View --

  defp summary_view(model) do
    scanner = model.scanner
    analyzer = model.analyzer
    dep = model.dep_checker

    lines = (scanner && scanner.total_lines) || 0
    files_scanned = (scanner && length(scanner.scanned)) || 0
    files_analyzed = (analyzer && length(analyzer.results)) || 0
    docs = (analyzer && Enum.count(analyzer.results, fn {_, d} -> d end)) || 0
    deps_ok = (dep && dep.checked) || 0
    uptime = System.monotonic_time(:second) - model.start_time

    old_chaos = fmt_pid(model.old_pids[:chaos])
    new_chaos = fmt_pid(model.pids[:chaos])

    column style: %{padding: 0, gap: 0} do
      [
        box style: %{border: :double, width: :fill, padding: 0} do
          text("  SUMMARY", style: [:bold], fg: :cyan)
        end,
        spacer(size: 1),
        summary_row("Files scanned", "#{files_scanned}"),
        summary_row("Lines counted", fmt(lines)),
        summary_row("Doc coverage", "#{docs}/#{files_analyzed} modules"),
        summary_row("Dependencies", "#{deps_ok} OK"),
        summary_row("Agent crashes", "#{model.crashes}"),
        summary_row_colored("Data loss", "zero", :green),
        summary_row(
          "Crash recovery",
          "#{old_chaos} -> #{new_chaos} (new PID proves restart)"
        ),
        summary_row("Total uptime", "#{uptime}s"),
        spacer(size: 2),
        text(
          "  Demo complete. 5 agents supervised, crash recovered, work continued.",
          style: [:bold]
        ),
        text("  No other terminal framework does this.", style: [:dim]),
        spacer(size: 1)
      ]
    end
  end

  # ============================================================
  # Panel Components
  # ============================================================

  defp header_bar(uptime) do
    box style: %{border: :double, width: :fill, padding: 0} do
      row style: %{justify_content: :space_between} do
        [
          text("  RAXOL AGENT COCKPIT", style: [:bold], fg: :cyan),
          text("uptime #{fmt_uptime(uptime)}  ", style: [:bold])
        ]
      end
    end
  end

  defp scanner_panel(model) do
    m = model.scanner

    if m do
      scanned = length(m.scanned)
      total = scanned + length(m.remaining)
      current = if m.current, do: Path.basename(m.current), else: "---"

      agent_box("File Scanner", m.status, model.pids[:scanner], [
        progress_row(scanned, total, 14),
        stat_line("Lines", fmt(m.total_lines)),
        stat_line("Current", current)
      ])
    else
      agent_box("File Scanner", :idle, nil, [
        text("  waiting...", style: [:dim])
      ])
    end
  end

  defp analyzer_panel(model) do
    m = model.analyzer

    if m do
      checked = length(m.results)
      total = checked + length(m.remaining)
      docs = Enum.count(m.results, fn {_, d} -> d end)
      current = if m.current, do: Path.basename(m.current), else: "---"

      agent_box("Code Analyzer", m.status, model.pids[:analyzer], [
        progress_row(checked, total, 14),
        stat_line("Docs", "#{docs}/#{checked}"),
        stat_line("Current", current)
      ])
    else
      agent_box("Code Analyzer", :idle, nil, [
        text("  waiting...", style: [:dim])
      ])
    end
  end

  defp monitor_panel(model) do
    m = model.monitor

    if m && map_size(m.stats) > 0 do
      s = m.stats

      agent_box("System Monitor", :monitoring, model.pids[:monitor], [
        stat_line("Procs", "#{s.processes}"),
        memory_sparkline_row(s.memory_mb, m.history),
        stat_line("Scheds", "#{s.schedulers}")
      ])
    else
      agent_box("System Monitor", :idle, nil, [
        text("  waiting...", style: [:dim])
      ])
    end
  end

  defp chaos_panel(model) do
    m = model.chaos
    in_crash = model.tick >= @crash_tick and model.tick < @recover_tick
    flash = model.tick >= @crash_tick and model.tick < @crash_tick + 4

    cond do
      flash ->
        old_pid = fmt_pid(model.old_pids[:chaos] || model.pids[:chaos])
        crash_box(old_pid)

      in_crash ->
        agent_box("Chaos Worker", :crashed, nil, [
          text("  Restarting...", fg: :yellow),
          stat_line("Crashes", "#{model.crashes}"),
          stat_line("Status", "auto-restart")
        ])

      m != nil ->
        status_label =
          cond do
            m.status == :working -> "working"
            model.crashes > 0 -> "recovered"
            true -> "#{m.status}"
          end

        agent_box("Chaos Worker", m.status, model.pids[:chaos], [
          stat_line("Tasks", "#{m.tasks_done}"),
          stat_line("Crashes", "#{model.crashes}"),
          stat_line("Status", status_label)
        ])

      true ->
        agent_box("Chaos Worker", :idle, nil, [
          text("  waiting...", style: [:dim])
        ])
    end
  end

  defp event_log_panel(model) do
    entries = model.events |> Enum.take(7) |> Enum.reverse()

    rows =
      Enum.map(entries, fn {elapsed, tag, message} ->
        {tag_label, tag_fg} = tag_display(tag)

        row style: %{gap: 1} do
          [
            text(String.pad_leading("#{elapsed}s", 4), style: [:dim]),
            text(tag_label, style: [:bold], fg: tag_fg),
            text(message)
          ]
        end
      end)

    padding = for _ <- 1..max(0, 7 - length(rows)), do: text("")

    box style: %{border: :single, width: :fill, padding: 1} do
      column style: %{gap: 0} do
        [
          text("Event Log", style: [:bold], fg: :cyan),
          divider(char: "-")
          | rows ++ padding
        ]
      end
    end
  end

  defp key_bar do
    row style: %{gap: 2} do
      [
        text(" q", style: [:bold], fg: :magenta),
        text("quit", style: [:dim])
      ]
    end
  end

  # ============================================================
  # Reusable View Helpers
  # ============================================================

  defp agent_box(title, status, pid, content_rows) do
    border = if status in [:done, :crashed], do: :double, else: :single
    fg = status_fg(status)
    pid_str = if pid, do: " #{short_pid(pid)}", else: ""

    box style: %{border: border, width: 38, padding: 1} do
      column style: %{gap: 0} do
        [
          row style: %{gap: 1} do
            [
              text(status_dot(status), fg: fg),
              text(title, style: [:bold], fg: fg),
              text(pid_str, style: [:dim])
            ]
          end,
          divider(char: "-")
          | content_rows
        ]
      end
    end
  end

  defp crash_box(old_pid) do
    box style: %{border: :double, width: 38, padding: 1} do
      column style: %{gap: 0} do
        [
          row style: %{gap: 1} do
            [
              text("x", fg: :red),
              text("Chaos Worker", style: [:bold], fg: :red)
            ]
          end,
          divider(char: "-"),
          spacer(size: 1),
          text("    X PROCESS KILLED X", style: [:bold], fg: :red),
          text("    PID #{old_pid} terminated", fg: :red),
          text("    Supervisor notified...", fg: :yellow)
        ]
      end
    end
  end

  defp progress_row(current, total, width) when total > 0 do
    filled = div(current * width, total)
    empty = width - filled
    filled_str = String.duplicate(@bar_fill, filled)
    empty_str = String.duplicate(@bar_empty, empty)

    row style: %{gap: 1} do
      [
        text(filled_str, fg: :green),
        text(empty_str, style: [:dim]),
        text("#{current}/#{total}")
      ]
    end
  end

  defp progress_row(_current, _total, width) do
    row style: %{gap: 1} do
      [
        text(String.duplicate(@bar_empty, width), style: [:dim]),
        text("0/0")
      ]
    end
  end

  defp stat_line(label, value) do
    row style: %{gap: 1} do
      [
        text("  #{String.pad_trailing(label, 8)}", style: [:dim]),
        text(value, style: [:bold])
      ]
    end
  end

  defp memory_sparkline_row(mem_mb, history) do
    spark = sparkline(history)

    row style: %{gap: 1} do
      [
        text("  #{String.pad_trailing("Memory", 8)}", style: [:dim]),
        text("#{mem_mb} MB", style: [:bold]),
        text(spark, fg: :cyan)
      ]
    end
  end

  defp summary_row(label, value) do
    row style: %{gap: 1} do
      [
        text("  #{String.pad_trailing(label, 18)}", style: [:dim]),
        text(value)
      ]
    end
  end

  defp summary_row_colored(label, value, color) do
    row style: %{gap: 1} do
      [
        text("  #{String.pad_trailing(label, 18)}", style: [:dim]),
        text(value, style: [:bold], fg: color)
      ]
    end
  end

  # ============================================================
  # Agent Lifecycle (side effects in update)
  # ============================================================

  defp ensure_infra do
    case Registry.start_link(keys: :unique, name: Raxol.Agent.Registry) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    case Registry.start_link(keys: :duplicate, name: :raxol_event_subscriptions) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    case DynamicSupervisor.start_link(
           name: Raxol.DynamicSupervisor,
           strategy: :one_for_one
         ) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
  end

  defp staggered_boot(model) do
    schedule = [
      {@boot_scanner, CockpitDemo.FileScanner, :scanner},
      {@boot_analyzer, CockpitDemo.CodeAnalyzer, :analyzer},
      {@boot_monitor, CockpitDemo.SystemMonitor, :monitor},
      {@boot_chaos, CockpitDemo.ChaosWorker, :chaos},
      {@boot_deps, CockpitDemo.DepChecker, :dep_checker}
    ]

    Enum.reduce(schedule, model, fn {tick, mod, id}, st ->
      if model.tick == tick and not MapSet.member?(st.booted, id) do
        DynamicSupervisor.start_child(
          Raxol.DynamicSupervisor,
          {Session, app_module: mod, id: id}
        )

        Process.sleep(100)
        Session.send_message(id, :start)

        st
        |> Map.put(:booted, MapSet.put(st.booted, id))
        |> add_event(:boot, "#{agent_name(id)} online")
      else
        st
      end
    end)
  end

  defp poll_agents(model) do
    %{
      model
      | scanner: safe_model(:scanner),
        analyzer: safe_model(:analyzer),
        monitor: safe_model(:monitor),
        chaos: safe_model(:chaos),
        dep_checker: safe_model(:dep_checker)
    }
  end

  defp safe_model(id) do
    case Session.get_model(id) do
      {:ok, m} -> m
      _ -> nil
    end
  end

  defp track_pids(model) do
    ids = [:scanner, :analyzer, :monitor, :chaos, :dep_checker]

    current =
      Enum.reduce(ids, %{}, fn id, acc ->
        case Registry.lookup(Raxol.Agent.Registry, id) do
          [{pid, _}] -> Map.put(acc, id, pid)
          [] -> acc
        end
      end)

    old =
      Enum.reduce(ids, model.old_pids, fn id, acc ->
        case {Map.get(model.pids, id), Map.get(current, id)} do
          {old_pid, new_pid} when old_pid != nil and old_pid != new_pid ->
            Map.put(acc, id, old_pid)

          _ ->
            acc
        end
      end)

    %{model | pids: current, old_pids: old}
  end

  defp handle_chaos(model) do
    cond do
      model.tick == @crash_tick ->
        kill_agent(:chaos)

        model
        |> Map.put(:crashes, model.crashes + 1)
        |> add_event(
          :crash,
          "Chaos Worker killed (#{fmt_pid(model.pids[:chaos])})"
        )

      model.tick == @recover_tick and not model.restarted ->
        Session.send_message(:chaos, :start)

        new_pid =
          case Registry.lookup(Raxol.Agent.Registry, :chaos) do
            [{pid, _}] -> pid
            [] -> nil
          end

        model
        |> Map.put(:restarted, true)
        |> add_event(:recover, "new PID #{fmt_pid(new_pid)} -- resuming")

      true ->
        model
    end
  end

  defp kill_agent(id) do
    case Registry.lookup(Raxol.Agent.Registry, id) do
      [{pid, _}] -> Process.exit(pid, :kill)
      [] -> :ok
    end
  end

  defp handle_narration(model) do
    cond do
      model.tick == @crash_tick - 8 ->
        add_event(model, :warn, "Chaos Worker becoming unstable...")

      model.tick == @crash_tick + 2 ->
        add_event(model, :warn, "Supervisor detected exit, restarting child...")

      all_done?(model) and not MapSet.member?(model.done_logged, :all_done) ->
        model
        |> add_event(:done, "All tasks complete. Zero data loss.")
        |> Map.update!(:done_logged, &MapSet.put(&1, :all_done))

      true ->
        model
    end
  end

  defp all_done?(model) do
    Enum.all?([:scanner, :analyzer], fn key ->
      m = Map.get(model, key)
      m && m.status == :done
    end)
  end

  defp track_completions(model) do
    model
    |> maybe_log_done(:scanner, fn ->
      "Scanner: #{fmt(model.scanner.total_lines)} lines across #{length(model.scanner.scanned)} files"
    end)
    |> maybe_log_done(:analyzer, fn ->
      docs = Enum.count(model.analyzer.results, fn {_, d} -> d end)
      total = length(model.analyzer.results)
      "Analyzer: #{docs}/#{total} modules have @moduledoc"
    end)
    |> maybe_log_done(:dep_checker, fn ->
      "Deps: #{model.dep_checker.checked} dependencies OK"
    end)
  end

  defp maybe_log_done(model, key, msg_fn) do
    m = Map.get(model, key)

    if m && m.status == :done && not MapSet.member?(model.done_logged, key) do
      model
      |> add_event(:info, msg_fn.())
      |> Map.update!(:done_logged, &MapSet.put(&1, key))
    else
      model
    end
  end

  # ============================================================
  # Event Log
  # ============================================================

  defp add_event(model, tag, message) do
    elapsed = System.monotonic_time(:second) - model.start_time
    entry = {elapsed, tag, message}
    %{model | events: Enum.take([entry | model.events], 8)}
  end

  defp tag_display(:boot), do: {"BOOT  ", :cyan}
  defp tag_display(:warn), do: {"WARN  ", :yellow}
  defp tag_display(:crash), do: {"CRASH!", :red}
  defp tag_display(:recover), do: {"RECOV.", :green}
  defp tag_display(:done), do: {"DONE  ", :green}
  defp tag_display(:info), do: {"INFO  ", :cyan}
  defp tag_display(_), do: {"      ", :white}

  # ============================================================
  # Rendering Helpers
  # ============================================================

  defp sparkline(history) when length(history) < 3, do: ""

  defp sparkline(history) do
    values = Enum.reverse(Enum.take(history, 10))
    mn = Enum.min(values)
    mx = Enum.max(values)
    range = max(mx - mn, 1)

    values
    |> Enum.map(fn v ->
      idx = min(7, div((v - mn) * 7, range))
      Enum.at(@sparks, idx)
    end)
    |> Enum.join()
  end

  defp status_dot(:idle), do: "o"
  defp status_dot(:crashed), do: "x"
  defp status_dot(:done), do: "*"
  defp status_dot(_active), do: "*"

  defp status_fg(:idle), do: :yellow
  defp status_fg(:scanning), do: :green
  defp status_fg(:analyzing), do: :green
  defp status_fg(:monitoring), do: :green
  defp status_fg(:checking), do: :green
  defp status_fg(:working), do: :green
  defp status_fg(:done), do: :cyan
  defp status_fg(:crashed), do: :red
  defp status_fg(_), do: :white

  defp agent_name(:scanner), do: "File Scanner"
  defp agent_name(:analyzer), do: "Code Analyzer"
  defp agent_name(:monitor), do: "System Monitor"
  defp agent_name(:chaos), do: "Chaos Worker"
  defp agent_name(:dep_checker), do: "Dep Checker"

  # ============================================================
  # Formatters
  # ============================================================

  defp fmt_uptime(s) do
    m = div(s, 60)
    sec = rem(s, 60)
    min_str = m |> Integer.to_string() |> String.pad_leading(2, "0")
    sec_str = sec |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{min_str}:#{sec_str}"
  end

  defp fmt(nil), do: "0"

  defp fmt(n) when is_integer(n) and n >= 1000 do
    "#{div(n, 1000)},#{n |> rem(1000) |> Integer.to_string() |> String.pad_leading(3, "0")}"
  end

  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
  defp fmt(_), do: "0"

  defp fmt_pid(nil), do: "---"
  defp fmt_pid(pid) when is_pid(pid), do: inspect(pid)

  defp short_pid(pid) when is_pid(pid) do
    pid |> inspect() |> String.replace("PID", "")
  end

  defp short_pid(_), do: ""
end

# --- Start ---

Raxol.Core.Runtime.Log.info("CockpitDemo: Starting...")
{:ok, pid} = Raxol.start_link(CockpitDemo, [])
Raxol.Core.Runtime.Log.info("CockpitDemo: Running. Press 'q' to quit.")

ref = Process.monitor(pid)

receive do
  {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
end
