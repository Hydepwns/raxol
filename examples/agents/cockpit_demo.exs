# Agent Cockpit Demo
#
# Multi-pane dashboard showing supervised agents working in real time.
# Demonstrates: OTP supervision, crash recovery, inter-agent coordination.
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

  def update({:command_result, :scan_next}, model) do
    scan_next(model)
  end

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
      [_ | _] -> {new_model, [Command.delay(:scan_next, 400)]}
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

  def update({:command_result, :analyze_next}, model) do
    analyze_next(model)
  end

  def update({:command_result, {:shell_result, %{output: out}}}, model) do
    has_docs = String.trim(out) != "0"

    new_model = %{
      model
      | results: [{Path.basename(model.current), has_docs} | model.results]
    }

    case new_model.remaining do
      [_ | _] -> {new_model, [Command.delay(:analyze_next, 500)]}
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
    %{checks: 0, stats: %{}, status: :idle}
  end

  def update({:agent_message, _from, :start}, model) do
    do_check(%{model | status: :monitoring})
  end

  def update({:command_result, :tick}, model) do
    do_check(model)
  end

  def update(_msg, model), do: {model, []}

  defp do_check(model) do
    stats = %{
      processes: :erlang.system_info(:process_count),
      memory_mb: div(:erlang.memory(:total), 1_048_576),
      schedulers: :erlang.system_info(:schedulers_online)
    }

    {%{model | checks: model.checks + 1, stats: stats},
     [Command.delay(:tick, 800)]}
  end
end

defmodule CockpitDemo.ChaosWorker do
  @moduledoc false
  use Raxol.Agent

  def init(_ctx) do
    %{tasks_done: 0, status: :idle}
  end

  def update({:agent_message, _from, :start}, model) do
    {%{model | status: :working}, [Command.shell("echo ok")]}
  end

  def update({:command_result, :next_task}, model) do
    {model, [Command.shell("echo task_#{model.tasks_done + 1}")]}
  end

  def update({:command_result, {:shell_result, _}}, model) do
    done = model.tasks_done + 1
    {%{model | tasks_done: done}, [Command.delay(:next_task, 600)]}
  end

  def update(_msg, model), do: {model, []}
end

# --- Dashboard ---

defmodule CockpitDemo do
  @moduledoc false
  alias Raxol.Agent.Session

  @pw 34
  @pi 30
  @fw 70
  @gap "  "
  @crash_tick 40
  @end_tick 70

  def run do
    ensure_infra()
    start_agents()
    Process.sleep(500)
    kick_off()
    IO.write("\e[?25l\e[2J")

    state = %{
      tick: 0,
      t0: ms(),
      crashes: 0,
      events: [event_entry(0, "All agents started. Scanning codebase...")],
      restarted: false,
      scanner: nil,
      analyzer: nil,
      monitor: nil,
      chaos: nil
    }

    try do
      loop(state)
    after
      IO.write("\e[?25h\n")
    end
  end

  defp loop(state) do
    state =
      state
      |> poll_agents()
      |> handle_chaos()
      |> track_completions()

    render(state)
    Process.sleep(200)

    if state.tick > @end_tick do
      IO.puts("")

      IO.puts(
        "\e[1mDemo complete.\e[0m 4 agents supervised, crash recovered, work continued."
      )

      IO.puts("No other TUI framework does this.\n")
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

  defp start_agents do
    agents = [
      {CockpitDemo.FileScanner, :scanner},
      {CockpitDemo.CodeAnalyzer, :analyzer},
      {CockpitDemo.SystemMonitor, :monitor},
      {CockpitDemo.ChaosWorker, :chaos}
    ]

    Enum.each(agents, fn {mod, id} ->
      DynamicSupervisor.start_child(
        Raxol.DynamicSupervisor,
        {Session, app_module: mod, id: id}
      )
    end)
  end

  defp kick_off do
    Enum.each([:scanner, :analyzer, :monitor, :chaos], fn id ->
      Session.send_message(id, :start)
    end)
  end

  # -- Polling --

  defp poll_agents(state) do
    %{
      state
      | scanner: safe_model(:scanner),
        analyzer: safe_model(:analyzer),
        monitor: safe_model(:monitor),
        chaos: safe_model(:chaos)
    }
  end

  defp safe_model(id) do
    case Session.get_model(id) do
      {:ok, model} -> model
      _ -> nil
    end
  end

  # -- Crash / Recovery --

  defp handle_chaos(state) do
    cond do
      state.tick == @crash_tick ->
        kill_agent(:chaos)

        %{state | crashes: state.crashes + 1}
        |> add_event(
          "\e[1;31m!! Chaos agent CRASHED\e[0m -- supervisor restarting..."
        )

      state.tick == @crash_tick + 10 and not state.restarted ->
        Session.send_message(:chaos, :start)

        %{state | restarted: true}
        |> add_event("\e[1;32m>> Chaos agent recovered\e[0m -- resuming work")

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

  # -- Event tracking --

  defp track_completions(state) do
    state
    |> maybe_track(
      :scanner,
      "Scanner complete: #{fmt(state.scanner && state.scanner.total_lines)} lines counted"
    )
    |> maybe_track(:analyzer, fn ->
      docs = Enum.count(state.analyzer.results, fn {_, d} -> d end)
      total = length(state.analyzer.results)
      "Analyzer complete: #{docs}/#{total} files have @moduledoc"
    end)
  end

  defp maybe_track(state, key, msg_or_fn) do
    m = Map.get(state, key)
    logged_key = :"#{key}_logged"

    if m && m.status == :done && not Map.get(state, logged_key, false) do
      msg = if is_function(msg_or_fn), do: msg_or_fn.(), else: msg_or_fn
      add_event(state, msg) |> Map.put(logged_key, true)
    else
      state
    end
  end

  defp add_event(state, msg) do
    elapsed = div(ms() - state.t0, 1000)
    ts = elapsed |> Integer.to_string() |> String.pad_leading(2, "0")
    entry = "\e[90m[#{ts}s]\e[0m #{msg}"
    %{state | events: Enum.take([entry | state.events], 6)}
  end

  defp event_entry(elapsed, msg) do
    ts = elapsed |> Integer.to_string() |> String.pad_leading(2, "0")
    "\e[90m[#{ts}s]\e[0m #{msg}"
  end

  # -- Rendering --

  defp render(state) do
    IO.write("\e[H")

    uptime = div(ms() - state.t0, 1000)
    min = uptime |> div(60) |> Integer.to_string() |> String.pad_leading(2, "0")
    sec = uptime |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")

    # Header
    IO.puts(hline("="))

    IO.puts(
      full_line(
        "  \e[1;36mRAXOL AGENT COCKPIT\e[0m",
        "uptime \e[1m#{min}:#{sec}\e[0m  "
      )
    )

    IO.puts(hline("="))
    IO.puts("")

    # Row 1
    print_panels(scanner_panel(state), analyzer_panel(state))
    IO.puts("")

    # Row 2
    print_panels(monitor_panel(state), chaos_panel(state))
    IO.puts("")

    # Event log
    IO.puts(hline("-", " Event Log "))
    events = state.events |> Enum.take(5) |> Enum.reverse()
    padded = events ++ List.duplicate("", max(0, 5 - length(events)))
    Enum.each(padded, fn e -> IO.puts(log_line(e)) end)
    IO.puts(hline("-"))
  end

  # -- Panel builders --

  defp scanner_panel(state) do
    m = state.scanner

    if m do
      scanned = length(m.scanned)
      total = scanned + length(m.remaining)
      current = if m.current, do: Path.basename(m.current), else: "--"
      bar = progress_bar(scanned, total, 16)

      panel("File Scanner", m.status, [
        "Progress: #{bar} #{scanned}/#{total}",
        "Lines:    #{fmt(m.total_lines)}",
        "Current:  #{current}"
      ])
    else
      panel("File Scanner", :idle, ["", "  Initializing...", ""])
    end
  end

  defp analyzer_panel(state) do
    m = state.analyzer

    if m do
      checked = length(m.results)
      total = checked + length(m.remaining)
      docs = Enum.count(m.results, fn {_, d} -> d end)
      current = if m.current, do: Path.basename(m.current), else: "--"
      bar = progress_bar(checked, total, 16)

      panel("Code Analyzer", m.status, [
        "Progress: #{bar} #{checked}/#{total}",
        "Documented: #{docs}/#{checked}",
        "Current:  #{current}"
      ])
    else
      panel("Code Analyzer", :idle, ["", "  Initializing...", ""])
    end
  end

  defp monitor_panel(state) do
    m = state.monitor

    if m && map_size(m.stats) > 0 do
      s = m.stats

      panel("System Monitor", :monitoring, [
        "Processes:  #{s.processes}",
        "Memory:     #{s.memory_mb} MB",
        "Schedulers: #{s.schedulers}"
      ])
    else
      panel("System Monitor", :idle, ["", "  Initializing...", ""])
    end
  end

  defp chaos_panel(state) do
    m = state.chaos
    crashed = state.tick >= @crash_tick and state.tick < @crash_tick + 10

    if crashed do
      panel("Chaos Worker", :crashed, [
        "\e[1;31mPROCESS KILLED\e[0m",
        "Crashes:  #{state.crashes}",
        "Recovery: \e[33msupervisor restart\e[0m"
      ])
    else
      if m do
        status_text =
          cond do
            m.status == :working -> "working"
            state.crashes > 0 -> "\e[32mrecovered\e[0m"
            true -> "#{m.status}"
          end

        panel("Chaos Worker", m.status, [
          "Tasks:    #{m.tasks_done}",
          "Crashes:  #{state.crashes}",
          "Status:   #{status_text}"
        ])
      else
        panel("Chaos Worker", :idle, ["", "  Initializing...", ""])
      end
    end
  end

  # -- Panel primitives --

  defp panel(title, status, lines) do
    color = status_color(status)
    dot = "#{color}*\e[0m"
    {dot, title, lines}
  end

  defp print_panels({d1, t1, lines1}, {d2, t2, lines2}) do
    IO.puts(ptop(d1, t1) <> @gap <> ptop(d2, t2))

    p1 = pad_lines(lines1, 3)
    p2 = pad_lines(lines2, 3)

    Enum.zip(p1, p2)
    |> Enum.each(fn {l, r} ->
      IO.puts(pbody(l) <> @gap <> pbody(r))
    end)

    IO.puts(pbot() <> @gap <> pbot())
  end

  defp pad_lines(lines, n) do
    taken = Enum.take(lines, n)
    taken ++ List.duplicate("", max(0, n - length(taken)))
  end

  defp ptop(dot, title) do
    inner = " #{dot} \e[1m#{title}\e[0m "
    vlen = visible_len(inner)
    dashes = max(0, @pw - 2 - vlen)

    "+-#{String.duplicate("-", vlen)}#{String.duplicate("-", dashes)}+"
    |> String.replace(~r/^./, "┌")
    |> String.replace(~r/.$/, "┐")
    |> then(fn _border ->
      # Replace the content area with the actual styled title
      "┌─#{inner}#{String.duplicate("─", dashes)}┐"
    end)
  end

  defp pbody(content) do
    "│ #{pad_vis(content, @pi)} │"
  end

  defp pbot do
    "└#{String.duplicate("─", @pw - 2)}┘"
  end

  # -- Full-width lines --

  defp hline(char, label \\ "") do
    label_len = String.length(label)

    String.duplicate(char, @fw)
    |> then(fn line ->
      if label_len > 0 do
        pre = String.duplicate(char, 2)
        post_len = max(0, @fw - 2 - label_len)
        pre <> label <> String.duplicate(char, post_len)
      else
        line
      end
    end)
  end

  defp full_line(left, right) do
    lv = visible_len(left)
    rv = visible_len(right)
    pad = max(1, @fw - lv - rv)
    "#{left}#{String.duplicate(" ", pad)}#{right}"
  end

  defp log_line(content) do
    "  #{pad_vis(content, @fw - 4)}  "
  end

  # -- Utilities --

  defp status_color(:idle), do: "\e[33m"
  defp status_color(:scanning), do: "\e[32m"
  defp status_color(:analyzing), do: "\e[32m"
  defp status_color(:monitoring), do: "\e[32m"
  defp status_color(:working), do: "\e[32m"
  defp status_color(:done), do: "\e[36m"
  defp status_color(:crashed), do: "\e[31m"
  defp status_color(_), do: "\e[0m"

  defp progress_bar(current, total, width) when total > 0 do
    filled = div(current * width, total)
    empty = width - filled

    "\e[32m#{String.duplicate("#", filled)}\e[90m#{String.duplicate(".", empty)}\e[0m"
  end

  defp progress_bar(_, _, width), do: String.duplicate(".", width)

  defp visible_len(str) do
    str |> String.replace(~r/\e\[[0-9;]*m/, "") |> String.length()
  end

  defp pad_vis(str, width) do
    pad = max(0, width - visible_len(str))
    str <> String.duplicate(" ", pad)
  end

  defp fmt(nil), do: "0"

  defp fmt(n) when n >= 1000 do
    "#{div(n, 1000)},#{n |> rem(1000) |> Integer.to_string() |> String.pad_leading(3, "0")}"
  end

  defp fmt(n), do: Integer.to_string(n)

  defp ms, do: System.monotonic_time(:millisecond)
end

CockpitDemo.run()
