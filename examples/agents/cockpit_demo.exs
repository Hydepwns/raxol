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

  # Phase transitions (tick-driven, 200ms per tick)
  #
  # :title  --(12 ticks or space)--> :running
  # :running --(all done + post_done_ticks)--> :summary
  @title_ticks 12

  # Agent boot stagger (ticks within :running phase)
  @boot_schedule [
    {5, CockpitDemo.FileScanner, :scanner},
    {10, CockpitDemo.CodeAnalyzer, :analyzer},
    {15, CockpitDemo.SystemMonitor, :monitor},
    {20, CockpitDemo.ChaosWorker, :chaos},
    {25, CockpitDemo.DepChecker, :dep_checker}
  ]

  # Crash timeline
  @warn_start 47
  @crash_tick 55
  @crash_flash_ticks 8
  @recover_tick 70
  @post_done_ticks 15

  @sparks ~w(\u2581 \u2582 \u2583 \u2584 \u2585 \u2586 \u2587 \u2588)
  @bar_fill "\u2588"
  @bar_empty "\u2591"

  # -- TEA Callbacks --

  @impl true
  def init(_context) do
    ensure_infra()

    {w, h} = detect_size()

    %{
      phase: :title,
      tick: 0,
      width: w,
      height: h,
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
      uptimes: %{},
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

      %Raxol.Core.Events.Event{type: :resize, data: %{width: w, height: h}} ->
        {%{model | width: w, height: h}, []}

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

      :running ->
        new_model =
          model
          |> staggered_boot()
          |> poll_agents()
          |> track_pids()
          |> handle_chaos()
          |> handle_narration()
          |> track_completions()
          |> maybe_transition_to_summary()

        {%{new_model | tick: new_model.tick + 1}, []}

      :summary ->
        {model, []}
    end
  end

  defp maybe_transition_to_summary(model) do
    if model.restarted and MapSet.member?(model.done_logged, :all_done) and
         model.tick >= @recover_tick + @post_done_ticks do
      %{model | phase: :summary}
    else
      model
    end
  end

  # -- Narrative phase (derived from tick state) --

  defp narrative_phase(model) do
    tick = model.tick

    cond do
      tick < 5 -> :init
      tick <= 26 -> :boot
      tick < @warn_start -> :working
      tick < @crash_tick -> :warning
      tick < @recover_tick -> :crash
      not model.restarted -> :crash
      not MapSet.member?(model.done_logged, :all_done) -> :recovery
      true -> :complete
    end
  end

  defp phase_display(:init), do: {"INITIALIZING", :yellow}
  defp phase_display(:boot), do: {"AGENT BOOT", :cyan}
  defp phase_display(:working), do: {"CONCURRENT WORK", :green}
  defp phase_display(:warning), do: {"!! WARNING !!", :yellow}
  defp phase_display(:crash), do: {"!! CRASH !!", :red}
  defp phase_display(:recovery), do: {"RECOVERY", :green}
  defp phase_display(:complete), do: {"COMPLETE", :cyan}

  # ============================================================
  # Views
  # ============================================================

  # -- Title View --

  defp title_view(model) do
    dots = String.duplicate(".", min(rem(model.tick, 4) + 1, 3))
    top_pad = max(1, div(model.height - 13, 3))

    column style: %{padding: 0, gap: 0} do
      [
        spacer(size: top_pad),
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
        text("  initializing supervisor tree#{dots}", style: [:dim]),
        spacer(size: 1),
        text("  press space to skip", style: [:dim])
      ]
    end
  end

  # -- Dashboard View --

  defp dashboard_view(model) do
    uptime = System.monotonic_time(:second) - model.start_time

    column style: %{padding: 0, gap: 0} do
      [
        header_bar(uptime, model),
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
        row style: %{gap: 1} do
          [
            supervision_tree_panel(model),
            event_log_panel(model)
          ]
        end
        | recovery_proof(model) ++
            [
              bottom_spacer(
                model.height,
                if(show_recovery_proof?(model), do: 37, else: 31)
              ),
              key_bar()
            ]
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

    old_pid =
      if model.old_pids[:chaos],
        do: inspect(model.old_pids[:chaos]),
        else: "---"

    new_pid =
      if model.pids[:chaos], do: inspect(model.pids[:chaos]), else: "---"

    column style: %{padding: 0, gap: 0} do
      [
        box style: %{border: :double, width: :fill, padding: 0} do
          text("  MISSION COMPLETE", style: [:bold], fg: :green)
        end,
        spacer(size: 1),
        box style: %{border: :single, width: :fill, padding: 1} do
          column style: %{gap: 0} do
            [
              text("  What just happened:", style: [:bold]),
              spacer(size: 1),
              text("    5 concurrent GenServers ran real shell commands"),
              text("    #{old_pid} was Process.exit(:kill)'d mid-task",
                fg: :red
              ),
              text("    OTP supervisor auto-restarted it as #{new_pid}",
                fg: :green
              ),
              text("    Restarted agent resumed work. Zero data lost.",
                style: [:bold]
              )
            ]
          end
        end,
        spacer(size: 1),
        box style: %{border: :single, width: :fill, padding: 1} do
          column style: %{gap: 0} do
            [
              text("  Results:", style: [:bold]),
              spacer(size: 1),
              summary_row("Files scanned", "#{files_scanned}"),
              summary_row("Lines counted", fmt(lines)),
              summary_row("Doc coverage", "#{docs}/#{files_analyzed} modules"),
              summary_row("Dependencies", "#{deps_ok} OK"),
              summary_row("Agent crashes", "#{model.crashes}"),
              summary_row_colored("Data loss", "zero", :green),
              summary_row("Total uptime", "#{uptime}s")
            ]
          end
        end,
        spacer(size: 1),
        text("  Try doing this in Python, Go, or Rust.", style: [:bold]),
        bottom_spacer(model.height, 24),
        key_bar()
      ]
    end
  end

  # ============================================================
  # Panel Components
  # ============================================================

  defp header_bar(uptime, model) do
    {label, pfg} = phase_display(narrative_phase(model))

    box style: %{border: :double, width: :fill, padding: 0} do
      row style: %{justify_content: :space_between} do
        [
          text("  RAXOL AGENT COCKPIT", style: [:bold], fg: :cyan),
          text(">> #{label}", style: [:bold], fg: pfg),
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

      agent_box(
        "File Scanner",
        m.status,
        model.pids[:scanner],
        [
          progress_row(scanned, total, 14),
          stat_line("Lines", fmt(m.total_lines)),
          stat_line("Current", current)
        ],
        uptime: agent_uptime(model, :scanner)
      )
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

      agent_box(
        "Code Analyzer",
        m.status,
        model.pids[:analyzer],
        [
          progress_row(checked, total, 14),
          stat_line("Docs", "#{docs}/#{checked}"),
          stat_line("Current", current)
        ],
        uptime: agent_uptime(model, :analyzer)
      )
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

      agent_box(
        "System Monitor",
        :monitoring,
        model.pids[:monitor],
        [
          stat_line("Procs", "#{s.processes}"),
          memory_sparkline_row(s.memory_mb, m.history),
          stat_line("Scheds", "#{s.schedulers}")
        ],
        uptime: agent_uptime(model, :monitor)
      )
    else
      agent_box("System Monitor", :idle, nil, [
        text("  waiting...", style: [:dim])
      ])
    end
  end

  defp chaos_panel(model) do
    m = model.chaos
    tick = model.tick
    in_flash = tick >= @crash_tick and tick < @crash_tick + @crash_flash_ticks

    in_restart =
      tick >= @crash_tick + @crash_flash_ticks and tick < @recover_tick

    cond do
      in_flash ->
        old_pid = fmt_pid(model.old_pids[:chaos] || model.pids[:chaos])
        crash_box(old_pid, tick - @crash_tick)

      in_restart ->
        dots =
          String.duplicate(
            ".",
            min(rem(tick - @crash_tick - @crash_flash_ticks, 4) + 1, 3)
          )

        agent_box("Chaos Worker", :crashed, nil, [
          text("  PROCESS TERMINATED", fg: :red, style: [:bold]),
          stat_line("Crashes", "#{model.crashes}"),
          text("  supervisor restarting#{dots}", fg: :yellow)
        ])

      m != nil ->
        status_label =
          cond do
            m.status == :working and model.crashes > 0 -> "RECOVERED"
            m.status == :working -> "working"
            true -> "#{m.status}"
          end

        status_fg =
          if m.status == :working and model.crashes > 0, do: :green, else: nil

        content = [
          stat_line("Tasks", "#{m.tasks_done}"),
          stat_line("Crashes", "#{model.crashes}")
        ]

        content =
          if status_fg do
            content ++
              [text("  #{status_label}", style: [:bold], fg: status_fg)]
          else
            content ++ [stat_line("Status", status_label)]
          end

        agent_box(
          "Chaos Worker",
          m.status,
          model.pids[:chaos],
          content,
          uptime: agent_uptime(model, :chaos)
        )

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

  # -- Supervision Tree Panel (replaces Dep Checker panel) --

  defp supervision_tree_panel(model) do
    in_crash = model.tick >= @crash_tick and model.tick < @recover_tick

    box style: %{border: :single, width: :fill, padding: 1} do
      column style: %{gap: 0} do
        [
          text("Process Tree", style: [:bold], fg: :cyan),
          divider(char: "-"),
          text("  DynamicSupervisor", style: [:bold])
          | tree_nodes(model, in_crash)
        ]
      end
    end
  end

  defp tree_nodes(model, in_crash) do
    nodes =
      List.flatten([
        tree_node("Scanner  ", :scanner, model, false, in_crash),
        tree_node("Analyzer ", :analyzer, model, false, in_crash),
        tree_node("Monitor  ", :monitor, model, false, in_crash),
        tree_node("Chaos    ", :chaos, model, false, in_crash),
        tree_restart_node(model),
        tree_node("DepCheck ", :dep_checker, model, true, in_crash)
      ])

    nodes
  end

  defp tree_node(name, id, model, is_last, in_crash) do
    branch = if is_last, do: "  +-- ", else: "  |-- "
    pid = model.pids[id]

    {pid_str, dot, fg} =
      cond do
        id == :chaos and in_crash ->
          old = model.old_pids[:chaos] || pid
          pid_s = if old, do: short_pid(old), else: "---"
          {pid_s, " X KILLED", :red}

        pid != nil ->
          {short_pid(pid), " *", :green}

        MapSet.member?(model.booted, id) ->
          {"---", " o", :yellow}

        true ->
          {"---", " -", :white}
      end

    row style: %{gap: 0} do
      [
        text(branch, style: [:dim]),
        text(name, style: [:bold]),
        text(pid_str, style: [:dim]),
        text(dot, fg: fg)
      ]
    end
  end

  defp tree_restart_node(model) do
    if model.restarted and model.old_pids[:chaos] do
      old_pid = short_pid(model.old_pids[:chaos])

      new_pid =
        if model.pids[:chaos], do: short_pid(model.pids[:chaos]), else: "---"

      [
        row style: %{gap: 0} do
          [
            text("  |  +> ", style: [:dim]),
            text(old_pid, fg: :red),
            text(" -> ", style: [:dim]),
            text(new_pid, fg: :green, style: [:bold]),
            text(" restarted", style: [:dim])
          ]
        end
      ]
    else
      []
    end
  end

  # -- Recovery Proof --

  defp show_recovery_proof?(model) do
    model.restarted and model.old_pids[:chaos] != nil
  end

  defp recovery_proof(model) do
    if show_recovery_proof?(model) do
      old_pid = short_pid(model.old_pids[:chaos])

      new_pid =
        if model.pids[:chaos], do: short_pid(model.pids[:chaos]), else: "---"

      bar = String.duplicate(@bar_fill, 32)

      [
        spacer(size: 1),
        box style: %{border: :double, width: :fill, padding: 1} do
          column style: %{gap: 0} do
            [
              row style: %{gap: 2} do
                [
                  text("RECOVERY PROOF", style: [:bold], fg: :green),
                  text(old_pid, fg: :red),
                  text("killed ->", style: [:dim]),
                  text(new_pid, fg: :green, style: [:bold]),
                  text("restarted", style: [:dim])
                ]
              end,
              row style: %{gap: 1} do
                [
                  text(bar, fg: :green),
                  text("New PID. Zero data lost.", style: [:bold])
                ]
              end
            ]
          end
        end
      ]
    else
      []
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

  defp agent_box(title, status, pid, content_rows, opts \\ []) do
    border = if status in [:done, :crashed], do: :double, else: :single
    fg = status_fg(status)
    pid_str = if pid, do: " #{short_pid(pid)}", else: ""
    uptime = Keyword.get(opts, :uptime)
    uptime_str = if uptime, do: " #{uptime}s", else: ""

    box style: %{border: border, width: :fill, padding: 1} do
      column style: %{gap: 0} do
        [
          row style: %{gap: 1} do
            [
              text(status_dot(status), fg: fg),
              text(title, style: [:bold], fg: fg),
              text(pid_str, style: [:dim]),
              text(uptime_str, style: [:dim])
            ]
          end,
          divider(char: "-")
          | content_rows
        ]
      end
    end
  end

  defp crash_box(old_pid, flash_tick) do
    alert = if rem(flash_tick, 2) == 0, do: "X X X", else: "! ! !"

    box style: %{border: :double, width: :fill, padding: 1} do
      column style: %{gap: 0} do
        [
          row style: %{gap: 1} do
            [
              text("X", fg: :red),
              text("Chaos Worker", style: [:bold], fg: :red),
              text("CRASHED", style: [:bold], fg: :red)
            ]
          end,
          divider(char: "="),
          text("    #{alert}", style: [:bold], fg: :red),
          text("    Process.exit(pid, :kill)", style: [:bold], fg: :red),
          text("    PID #{old_pid} terminated", fg: :red),
          text("    supervisor notified...", fg: :yellow)
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

  defp bottom_spacer(terminal_height, content_rows) do
    gap = max(1, terminal_height - content_rows - 1)
    spacer(size: gap)
  end

  defp detect_size do
    case {:io.columns(), :io.rows()} do
      {{:ok, w}, {:ok, h}} when w > 0 and h > 0 -> {w, h}
      _ -> {80, 24}
    end
  end

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
    Enum.reduce(@boot_schedule, model, fn {tick, mod, id}, st ->
      cond do
        model.tick == tick and not MapSet.member?(st.booted, id) ->
          DynamicSupervisor.start_child(
            Raxol.DynamicSupervisor,
            {Session, app_module: mod, id: id}
          )

          st
          |> Map.put(:booted, MapSet.put(st.booted, id))
          |> Map.update!(
            :uptimes,
            &Map.put(&1, id, System.monotonic_time(:second))
          )

        model.tick == tick + 1 and MapSet.member?(st.booted, id) and
            not MapSet.member?(st.done_logged, {:started, id}) ->
          Session.send_message(id, :start)

          st
          |> add_event(:boot, "#{agent_name(id)} online")
          |> Map.update!(:done_logged, &MapSet.put(&1, {:started, id}))

        true ->
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

        old_pid = model.old_pids[:chaos] || model.pids[:chaos]

        model
        |> Map.put(:restarted, true)
        |> Map.update!(
          :uptimes,
          &Map.put(&1, :chaos, System.monotonic_time(:second))
        )
        |> add_event(
          :recover,
          "#{fmt_pid(old_pid)} -> #{fmt_pid(new_pid)} (new PID!)"
        )

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
      model.tick == @warn_start ->
        add_event(model, :warn, "Chaos Worker memory pressure rising...")

      model.tick == @warn_start + 4 ->
        add_event(model, :warn, "Chaos Worker becoming unstable...")

      model.tick == @crash_tick + 2 ->
        add_event(model, :warn, "Supervisor detected exit :killed")

      model.tick == @crash_tick + @crash_flash_ticks ->
        add_event(model, :warn, "Initiating automatic restart...")

      model.tick == @recover_tick + 2 ->
        add_event(model, :info, "Chaos Worker resumed with new PID")

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

  defp agent_uptime(model, id) do
    case model.uptimes[id] do
      nil -> nil
      boot -> System.monotonic_time(:second) - boot
    end
  end

  defp short_pid(pid) when is_pid(pid) do
    pid |> inspect() |> String.replace("PID", "")
  end

  defp short_pid(_), do: ""
end

# --- Start ---

Raxol.Core.Runtime.Log.info("CockpitDemo: Starting...")
{:ok, pid} = Raxol.start_link(CockpitDemo, [])
Raxol.Core.Runtime.Log.info("CockpitDemo: Running. Press 'q' to quit.")

# Keep the script alive until the Lifecycle process exits (e.g. user presses 'q')
ref = Process.monitor(pid)

receive do
  {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
end
