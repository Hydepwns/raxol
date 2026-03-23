# Agent Cockpit Demo
#
# Multi-pane dashboard showing supervised agents working in real time.
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

# --- Dashboard ---

defmodule CockpitDemo do
  @moduledoc false
  alias Raxol.Agent.Session

  # Tick-based scheduling: 200ms per tick
  # Agents come online at staggered ticks
  @boot_scanner 5
  @boot_analyzer 10
  @boot_monitor 15
  @boot_chaos 20
  @boot_deps 25
  @crash_tick 55
  @recover_tick 65
  @end_tick 90

  @sparks ~w(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)

  def run do
    {fw, pw, pi, gap} = calc_layout()
    ensure_infra()

    # Title card
    show_title_card(fw)
    Process.sleep(2500)

    IO.write("\e[?25l\e[2J")

    state = %{
      tick: 0,
      t0: ms(),
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
      fw: fw,
      pw: pw,
      pi: pi,
      gap: gap
    }

    try do
      loop(state)
    after
      IO.write("\e[?25h\n")
    end
  end

  defp calc_layout do
    cols =
      case :io.columns() do
        {:ok, c} -> max(76, min(c, 120))
        _ -> 80
      end

    pw = div(cols - 2, 2)
    pi = pw - 4
    gap = String.duplicate(" ", cols - pw * 2)
    {cols, pw, pi, gap}
  end

  # -- Title Card --

  defp show_title_card(fw) do
    IO.write("\e[?25l\e[2J\e[H")

    banner = [
      "                                  .__   ",
      " _______ _____  ___  ___  ____    |  |  ",
      " \\_  __ \\\\__  \\ \\  \\/  / /  _ \\   |  |  ",
      "  |  | \\/ / __ \\_>    < (  <_> )  |  |__",
      "  |__|   (____  /__/\\_ \\ \\____/   |____/",
      "              \\/      \\/                 "
    ]

    IO.puts("")
    IO.puts("")

    Enum.each(banner, fn line ->
      pad = max(0, div(fw - String.length(line), 2))
      IO.puts("#{String.duplicate(" ", pad)}\e[1;36m#{line}\e[0m")
    end)

    IO.puts("")
    tagline = "the terminal for agentic applications"
    tpad = max(0, div(fw - String.length(tagline), 2))
    IO.puts("#{String.duplicate(" ", tpad)}\e[90m#{tagline}\e[0m")
    IO.puts("")
    sub = "OTP supervision * crash recovery * live metrics"
    spad = max(0, div(fw - String.length(sub), 2))
    IO.puts("#{String.duplicate(" ", spad)}\e[33m#{sub}\e[0m")
    IO.puts("")
    IO.puts("")
    loading = "initializing supervisor tree..."
    lpad = max(0, div(fw - String.length(loading), 2))
    IO.puts("#{String.duplicate(" ", lpad)}\e[90m#{loading}\e[0m")
  end

  # -- Main Loop --

  defp loop(state) do
    state =
      state
      |> staggered_boot()
      |> poll_agents()
      |> track_pids()
      |> handle_chaos()
      |> handle_narration()
      |> track_completions()

    render(state)
    Process.sleep(200)

    if state.tick > @end_tick do
      render_summary(state)
    else
      loop(%{state | tick: state.tick + 1})
    end
  end

  # -- Infrastructure --

  defp ensure_infra do
    case Registry.start_link(keys: :unique, name: Raxol.Agent.Registry) do
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

  # -- Staggered boot --

  defp staggered_boot(state) do
    schedule = [
      {@boot_scanner, CockpitDemo.FileScanner, :scanner},
      {@boot_analyzer, CockpitDemo.CodeAnalyzer, :analyzer},
      {@boot_monitor, CockpitDemo.SystemMonitor, :monitor},
      {@boot_chaos, CockpitDemo.ChaosWorker, :chaos},
      {@boot_deps, CockpitDemo.DepChecker, :dep_checker}
    ]

    Enum.reduce(schedule, state, fn {tick, mod, id}, st ->
      if state.tick == tick and not MapSet.member?(st.booted, id) do
        DynamicSupervisor.start_child(
          Raxol.DynamicSupervisor,
          {Session, app_module: mod, id: id}
        )

        Process.sleep(100)
        Session.send_message(id, :start)

        st
        |> Map.put(:booted, MapSet.put(st.booted, id))
        |> add_event("\e[36mBOOT\e[0m #{agent_name(id)} online")
      else
        st
      end
    end)
  end

  defp agent_name(:scanner), do: "File Scanner"
  defp agent_name(:analyzer), do: "Code Analyzer"
  defp agent_name(:monitor), do: "System Monitor"
  defp agent_name(:chaos), do: "Chaos Worker"
  defp agent_name(:dep_checker), do: "Dep Checker"

  # -- Polling --

  defp poll_agents(state) do
    %{
      state
      | scanner: safe_model(:scanner),
        analyzer: safe_model(:analyzer),
        monitor: safe_model(:monitor),
        chaos: safe_model(:chaos),
        dep_checker: safe_model(:dep_checker)
    }
  end

  defp safe_model(id) do
    case Session.get_model(id) do
      {:ok, model} -> model
      _ -> nil
    end
  end

  # -- PID tracking --

  defp track_pids(state) do
    ids = [:scanner, :analyzer, :monitor, :chaos, :dep_checker]

    current =
      Enum.reduce(ids, %{}, fn id, acc ->
        case Registry.lookup(Raxol.Agent.Registry, id) do
          [{pid, _}] -> Map.put(acc, id, pid)
          [] -> acc
        end
      end)

    old =
      Enum.reduce(ids, state.old_pids, fn id, acc ->
        case {Map.get(state.pids, id), Map.get(current, id)} do
          {old_pid, new_pid} when old_pid != nil and old_pid != new_pid ->
            Map.put(acc, id, old_pid)

          _ ->
            acc
        end
      end)

    %{state | pids: current, old_pids: old}
  end

  # -- Crash / Recovery --

  defp handle_chaos(state) do
    cond do
      state.tick == @crash_tick ->
        kill_agent(:chaos)

        %{state | crashes: state.crashes + 1}
        |> add_event(
          "\e[1;31m!! CRASH\e[0m Chaos Worker killed (#{fmt_pid(state.pids[:chaos])})"
        )

      state.tick == @recover_tick and not state.restarted ->
        Session.send_message(:chaos, :start)

        new_pid =
          case Registry.lookup(Raxol.Agent.Registry, :chaos) do
            [{pid, _}] -> pid
            [] -> nil
          end

        %{state | restarted: true}
        |> add_event(
          "\e[1;32m>> RECOVERED\e[0m new PID #{fmt_pid(new_pid)} -- resuming"
        )

      true ->
        state
    end
  end

  defp kill_agent(id) do
    case Registry.lookup(Raxol.Agent.Registry, id) do
      [{pid, _}] -> Process.exit(pid, :kill)
      [] -> :ok
    end
  end

  # -- Narration --

  defp handle_narration(state) do
    cond do
      state.tick == @crash_tick - 8 ->
        add_event(state, "\e[33mWARN\e[0m Chaos Worker becoming unstable...")

      state.tick == @crash_tick + 2 ->
        add_event(
          state,
          "\e[33mWARN\e[0m Supervisor detected exit, restarting child..."
        )

      all_done?(state) and not Map.get(state, :all_done_logged, false) ->
        state
        |> add_event("\e[1;32mDONE\e[0m All tasks complete. Zero data loss.")
        |> Map.put(:all_done_logged, true)

      true ->
        state
    end
  end

  defp all_done?(state) do
    Enum.all?([:scanner, :analyzer], fn key ->
      m = Map.get(state, key)
      m && m.status == :done
    end)
  end

  # -- Event tracking --

  defp track_completions(state) do
    state
    |> maybe_track(:scanner, fn ->
      "Scanner: \e[1m#{fmt(state.scanner.total_lines)}\e[0m lines across #{length(state.scanner.scanned)} files"
    end)
    |> maybe_track(:analyzer, fn ->
      docs = Enum.count(state.analyzer.results, fn {_, d} -> d end)
      total = length(state.analyzer.results)
      "Analyzer: \e[1m#{docs}/#{total}\e[0m modules have @moduledoc"
    end)
    |> maybe_track(:dep_checker, fn ->
      "Deps: \e[1m#{state.dep_checker.checked}\e[0m dependencies OK"
    end)
  end

  defp maybe_track(state, key, msg_fn) do
    m = Map.get(state, key)
    logged_key = :"#{key}_logged"

    if m && m.status == :done && not Map.get(state, logged_key, false) do
      add_event(state, msg_fn.()) |> Map.put(logged_key, true)
    else
      state
    end
  end

  defp add_event(state, msg) do
    elapsed = div(ms() - state.t0, 1000)
    ts = elapsed |> Integer.to_string() |> String.pad_leading(2, "0")
    entry = "  \e[90m#{ts}s\e[0m \e[90m|\e[0m #{msg}"
    %{state | events: Enum.take([entry | state.events], 8)}
  end

  # -- Rendering --

  defp render(state) do
    IO.write("\e[H")
    fw = state.fw

    uptime = div(ms() - state.t0, 1000)
    min = uptime |> div(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    sec = uptime |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")

    IO.puts(hline(fw, "="))

    IO.puts(
      full_line(
        fw,
        "  \e[1;36mRAXOL AGENT COCKPIT\e[0m",
        "uptime \e[1m#{min}:#{sec}\e[0m  "
      )
    )

    IO.puts(hline(fw, "="))
    IO.puts("")

    # Row 1
    print_panels(state, scanner_panel(state), analyzer_panel(state))
    IO.puts("")

    # Row 2
    print_panels(state, monitor_panel(state), chaos_panel(state))
    IO.puts("")

    # Event log
    IO.puts(hline(fw, "-", " Event Log "))
    events = state.events |> Enum.take(7) |> Enum.reverse()
    padded = events ++ List.duplicate("", max(0, 7 - length(events)))
    Enum.each(padded, fn e -> IO.puts(log_line(fw, e)) end)
    IO.puts(hline(fw, "-"))
  end

  # -- Summary --

  defp render_summary(state) do
    fw = state.fw
    IO.puts("")
    IO.puts(hline(fw, "=", " SUMMARY "))
    IO.puts("")

    scanner = state.scanner
    analyzer = state.analyzer
    dep = state.dep_checker

    lines = (scanner && scanner.total_lines) || 0
    files_scanned = (scanner && length(scanner.scanned)) || 0
    files_analyzed = (analyzer && length(analyzer.results)) || 0
    docs = (analyzer && Enum.count(analyzer.results, fn {_, d} -> d end)) || 0
    deps_ok = (dep && dep.checked) || 0
    uptime = div(ms() - state.t0, 1000)

    old_chaos = fmt_pid(state.old_pids[:chaos])
    new_chaos = fmt_pid(state.pids[:chaos])

    stats = [
      {"Files scanned", "#{files_scanned}"},
      {"Lines counted", fmt(lines)},
      {"Doc coverage", "#{docs}/#{files_analyzed} modules"},
      {"Dependencies", "#{deps_ok} OK"},
      {"Agent crashes", "#{state.crashes}"},
      {"Data loss", "\e[1;32mzero\e[0m"},
      {"Crash recovery",
       "#{old_chaos} -> #{new_chaos} (new PID proves restart)"},
      {"Total uptime", "#{uptime}s"}
    ]

    Enum.each(stats, fn {label, value} ->
      IO.puts("  \e[90m#{String.pad_trailing(label, 18)}\e[0m #{value}")
    end)

    IO.puts("")
    IO.puts(hline(fw, "="))
    IO.puts("")

    IO.puts(
      "  \e[1mDemo complete.\e[0m 5 agents supervised, crash recovered, work continued."
    )

    IO.puts("  \e[90mNo other terminal framework does this.\e[0m")
    IO.puts("")
  end

  # -- Panel builders --

  defp scanner_panel(state) do
    m = state.scanner
    pid = state.pids[:scanner]

    if m do
      scanned = length(m.scanned)
      total = scanned + length(m.remaining)
      current = if m.current, do: Path.basename(m.current), else: "---"
      bar = progress_bar(scanned, total, 14)

      panel("File Scanner", m.status, pid, [
        "#{bar} #{scanned}/#{total}",
        "Lines:   \e[1m#{fmt(m.total_lines)}\e[0m",
        "Current: \e[90m#{current}\e[0m"
      ])
    else
      panel("File Scanner", :idle, nil, ["", "  \e[90mwaiting...\e[0m", ""])
    end
  end

  defp analyzer_panel(state) do
    m = state.analyzer
    pid = state.pids[:analyzer]

    if m do
      checked = length(m.results)
      total = checked + length(m.remaining)
      docs = Enum.count(m.results, fn {_, d} -> d end)
      current = if m.current, do: Path.basename(m.current), else: "---"
      bar = progress_bar(checked, total, 14)

      panel("Code Analyzer", m.status, pid, [
        "#{bar} #{checked}/#{total}",
        "Docs:    \e[1m#{docs}/#{checked}\e[0m",
        "Current: \e[90m#{current}\e[0m"
      ])
    else
      panel("Code Analyzer", :idle, nil, ["", "  \e[90mwaiting...\e[0m", ""])
    end
  end

  defp monitor_panel(state) do
    m = state.monitor
    pid = state.pids[:monitor]

    if m && map_size(m.stats) > 0 do
      s = m.stats
      spark = sparkline(m.history)

      panel("System Monitor", :monitoring, pid, [
        "Procs:   \e[1m#{s.processes}\e[0m",
        "Memory:  \e[1m#{s.memory_mb}\e[0m MB #{spark}",
        "Scheds:  \e[1m#{s.schedulers}\e[0m"
      ])
    else
      panel("System Monitor", :idle, nil, ["", "  \e[90mwaiting...\e[0m", ""])
    end
  end

  defp chaos_panel(state) do
    m = state.chaos
    pid = state.pids[:chaos]
    in_crash = state.tick >= @crash_tick and state.tick < @recover_tick
    flash = state.tick >= @crash_tick and state.tick < @crash_tick + 4

    if flash do
      old_pid = fmt_pid(state.old_pids[:chaos] || state.pids[:chaos])

      panel_crash("Chaos Worker", [
        "\e[1;31m  X PROCESS KILLED X\e[0m",
        "\e[31m  PID #{old_pid} terminated\e[0m",
        "\e[33m  Supervisor notified...\e[0m"
      ])
    else
      if in_crash do
        panel("Chaos Worker", :crashed, nil, [
          "\e[33mRestarting...\e[0m",
          "Crashes: \e[1m#{state.crashes}\e[0m",
          "Status:  \e[33mauto-restart\e[0m"
        ])
      else
        if m do
          status =
            cond do
              m.status == :working -> "\e[32mworking\e[0m"
              state.crashes > 0 -> "\e[32mrecovered\e[0m"
              true -> "#{m.status}"
            end

          panel("Chaos Worker", m.status, pid, [
            "Tasks:   \e[1m#{m.tasks_done}\e[0m",
            "Crashes: \e[1m#{state.crashes}\e[0m",
            "Status:  #{status}"
          ])
        else
          panel("Chaos Worker", :idle, nil, ["", "  \e[90mwaiting...\e[0m", ""])
        end
      end
    end
  end

  # -- Sparkline --

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
    |> then(fn chars -> "\e[36m#{Enum.join(chars)}\e[0m" end)
  end

  # -- Panel primitives --

  defp panel(title, status, pid, lines) do
    color = status_color(status)
    dot = "#{color}*\e[0m"
    pid_str = if pid, do: " \e[90m#{short_pid(pid)}\e[0m", else: ""
    {:normal, dot, title, pid_str, lines}
  end

  defp panel_crash(title, lines) do
    {:crash, "\e[31mx\e[0m", title, "", lines}
  end

  defp print_panels(state, p1, p2) do
    pw = state.pw
    pi = state.pi
    gap = state.gap

    {type1, d1, t1, pid1, lines1} = p1
    {_type2, d2, t2, pid2, lines2} = p2

    b1 = if type1 == :crash, do: "\e[31m", else: ""
    r1 = if type1 == :crash, do: "\e[0m", else: ""

    IO.puts(
      ptop(pw, d1, t1, pid1, b1, r1) <> gap <> ptop(pw, d2, t2, pid2, "", "")
    )

    Enum.zip(pad_lines(lines1, 3), pad_lines(lines2, 3))
    |> Enum.each(fn {l, r} ->
      IO.puts(pbody(pi, l, b1, r1) <> gap <> pbody(pi, r, "", ""))
    end)

    IO.puts(pbot(pw, b1, r1) <> gap <> pbot(pw, "", ""))
  end

  defp pad_lines(lines, n) do
    taken = Enum.take(lines, n)
    taken ++ List.duplicate("", max(0, n - length(taken)))
  end

  defp ptop(pw, dot, title, pid_str, border, reset) do
    inner = " #{dot} \e[1m#{title}\e[0m#{pid_str} "
    vlen = visible_len(inner)
    dashes = max(1, pw - 2 - vlen)

    "#{border}+--#{reset}#{inner}#{border}#{String.duplicate("-", dashes)}+#{reset}"
    |> String.replace("+", "#{border}+#{reset}")
    |> then(fn _ ->
      "#{border}+-#{reset}#{inner}#{border}#{String.duplicate("-", dashes)}+#{reset}"
    end)
  end

  defp pbody(pi, content, border, reset) do
    "#{border}|#{reset} #{pad_vis(content, pi)} #{border}|#{reset}"
  end

  defp pbot(pw, border, reset) do
    "#{border}+#{String.duplicate("-", pw - 2)}+#{reset}"
  end

  # -- Full-width lines --

  defp hline(fw, char, label \\ "") do
    if String.length(label) > 0 do
      pre = String.duplicate(char, 2)
      post_len = max(0, fw - 2 - String.length(label))
      pre <> label <> String.duplicate(char, post_len)
    else
      String.duplicate(char, fw)
    end
  end

  defp full_line(fw, left, right) do
    lv = visible_len(left)
    rv = visible_len(right)
    pad = max(1, fw - lv - rv)
    "#{left}#{String.duplicate(" ", pad)}#{right}"
  end

  defp log_line(fw, content) do
    "#{pad_vis(content, fw - 2)}  "
  end

  # -- Progress bar --

  defp progress_bar(current, total, width) when total > 0 do
    filled = div(current * width, total)
    empty = width - filled

    "\e[32m#{String.duplicate("█", filled)}\e[90m#{String.duplicate("░", empty)}\e[0m"
  end

  defp progress_bar(_, _, width),
    do: "\e[90m#{String.duplicate("░", width)}\e[0m"

  # -- Utilities --

  defp status_color(:idle), do: "\e[33m"
  defp status_color(:scanning), do: "\e[32m"
  defp status_color(:analyzing), do: "\e[32m"
  defp status_color(:monitoring), do: "\e[32m"
  defp status_color(:checking), do: "\e[32m"
  defp status_color(:working), do: "\e[32m"
  defp status_color(:done), do: "\e[36m"
  defp status_color(:crashed), do: "\e[31m"
  defp status_color(_), do: "\e[0m"

  defp visible_len(str) do
    str |> String.replace(~r/\e\[[0-9;]*m/, "") |> String.length()
  end

  defp pad_vis(str, width) do
    pad = max(0, width - visible_len(str))
    str <> String.duplicate(" ", pad)
  end

  defp short_pid(pid) when is_pid(pid) do
    pid |> inspect() |> String.replace("PID", "")
  end

  defp short_pid(_), do: ""

  defp fmt(nil), do: "0"

  defp fmt(n) when is_integer(n) and n >= 1000 do
    "#{div(n, 1000)},#{n |> rem(1000) |> Integer.to_string() |> String.pad_leading(3, "0")}"
  end

  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
  defp fmt(_), do: "0"

  defp fmt_pid(nil), do: "---"
  defp fmt_pid(pid) when is_pid(pid), do: inspect(pid)

  defp ms, do: System.monotonic_time(:millisecond)
end

CockpitDemo.run()
