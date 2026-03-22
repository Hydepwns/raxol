# Raxol Demo
#
# A multi-panel dashboard showcasing Raxol's key features:
# live-updating stats, multiple border styles, text styling,
# flexbox layout, progress bars, and keyboard navigation.
#
# Usage:
#   mix run examples/demo.exs

defmodule RaxolDemo do
  use Raxol.Core.Runtime.Application

  require Raxol.Core.Runtime.Log

  @panels [:system, :activity]

  @impl true
  def init(_context) do
    %{
      tick_count: 0,
      active_panel: :system,
      log_entries: [
        {now(), "Raxol runtime initialized"},
        {now(), "TEA lifecycle started"},
        {now(), "Render engine ready"}
      ],
      start_time: System.monotonic_time(:second)
    }
  end

  @impl true
  def update(message, model) do
    case message do
      :tick ->
        uptime = System.monotonic_time(:second) - model.start_time
        entry = tick_log_entry(model.tick_count)

        log =
          [{now(), entry} | model.log_entries]
          |> Enum.take(12)

        {%{model | tick_count: model.tick_count + 1, log_entries: log},
         if(rem(uptime, 10) == 0 and uptime > 0,
           do: [],
           else: []
         )}

      :next_panel ->
        {%{model | active_panel: next_panel(model.active_panel)}, []}

      :prev_panel ->
        {%{model | active_panel: prev_panel(model.active_panel)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :tab}} ->
        {%{model | active_panel: next_panel(model.active_panel)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "l"}} ->
        {%{model | active_panel: next_panel(model.active_panel)}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "h"}} ->
        {%{model | active_panel: prev_panel(model.active_panel)}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    column style: %{padding: 0, gap: 0} do
      [
        # -- Header --
        box style: %{border: :double, width: :fill, padding: 0} do
          row style: %{gap: 1, justify_content: :space_between} do
            [
              text("  RAXOL DEMO  ", style: [:bold]),
              text(clock_string(), style: [:dim])
            ]
          end
        end,

        # -- Main content: two panels side by side --
        row style: %{gap: 1} do
          [
            # Left panel: System info
            system_panel(model),
            # Right panel: Activity log
            activity_panel(model)
          ]
        end,

        # -- Divider --
        divider(char: "="),

        # -- Key hints --
        box style: %{border: :rounded, width: :fill, padding: 0} do
          column style: %{gap: 0} do
            [
              row style: %{gap: 2} do
                [
                  text("[Tab/h/l]", style: [:bold]),
                  text("Switch panel"),
                  text("  "),
                  text("[q/Ctrl+C]", style: [:bold]),
                  text("Quit")
                ]
              end,
              spacer(size: 1),
              text("-- More Raxol demos --", style: [:underline]),
              text("  SSH serving:         mix run examples/ssh/ssh_counter.exs", style: [:dim]),
              text("  Hot reload:          iex -S mix run examples/dev/hot_reload_demo.exs",
                style: [:dim]
              ),
              text("  Process isolation:   mix run examples/components/process_component_demo.exs",
                style: [:dim]
              )
            ]
          end
        end
      ]
    end
  end

  @impl true
  def subscribe(_model) do
    [subscribe_interval(1000, :tick)]
  end

  # -- Panel builders --

  defp system_panel(model) do
    active = model.active_panel == :system
    border = if active, do: :double, else: :single

    mem = memory_stats()
    uptime = System.monotonic_time(:second) - model.start_time
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    mem_pct = round(mem.used_mb / mem.total_mb * 100)

    box style: %{border: border, width: 40, padding: 1} do
      column style: %{gap: 0} do
        [
          text(panel_title("System Info", active), style: [:bold]),
          divider(),
          text("Elixir:      #{System.version()}"),
          text("OTP:         #{:erlang.system_info(:otp_release)}"),
          text("Uptime:      #{format_uptime(uptime)}"),
          spacer(size: 1),
          text("Processes:   #{process_count} / #{process_limit}"),
          text("Reductions:  #{format_number(:erlang.statistics(:reductions) |> elem(0))}"),
          text("Tick:        ##{model.tick_count}"),
          spacer(size: 1),
          text("Memory", style: [:bold, :underline]),
          text("  Total:     #{mem.total_mb} MB"),
          text("  Used:      #{mem.used_mb} MB"),
          text("  Atoms:     #{mem.atom_mb} MB"),
          text("  Binaries:  #{mem.binary_mb} MB"),
          spacer(size: 1),
          row style: %{gap: 1} do
            [
              text("Mem:"),
              progress(value: mem_pct, max: 100),
              text("#{mem_pct}%", style: [:bold])
            ]
          end
        ]
      end
    end
  end

  defp activity_panel(model) do
    active = model.active_panel == :activity
    border = if active, do: :double, else: :single

    entries =
      model.log_entries
      |> Enum.map(fn {time, msg} ->
        text("#{time}  #{msg}", style: [:dim])
      end)

    box style: %{border: border, width: 44, padding: 1} do
      column style: %{gap: 0} do
        [
          text(panel_title("Activity Log", active), style: [:bold]),
          divider()
          | entries
        ]
      end
    end
  end

  # -- Helpers --

  defp panel_title(title, true), do: ">> #{title} <<"
  defp panel_title(title, false), do: "   #{title}   "

  defp next_panel(current) do
    idx = Enum.find_index(@panels, &(&1 == current))
    Enum.at(@panels, rem(idx + 1, length(@panels)))
  end

  defp prev_panel(current) do
    idx = Enum.find_index(@panels, &(&1 == current))
    Enum.at(@panels, rem(idx - 1 + length(@panels), length(@panels)))
  end

  defp now do
    Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
  end

  defp clock_string do
    Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_uptime(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m #{secs}s"
      minutes > 0 -> "#{minutes}m #{secs}s"
      true -> "#{secs}s"
    end
  end

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: "#{n}"

  defp memory_stats do
    mem = :erlang.memory()
    %{
      total_mb: Float.round(mem[:total] / 1_048_576, 1),
      used_mb: Float.round((mem[:total] - mem[:binary] - mem[:atom]) / 1_048_576, 1),
      atom_mb: Float.round(mem[:atom] / 1_048_576, 1),
      binary_mb: Float.round(mem[:binary] / 1_048_576, 1)
    }
  end

  defp tick_log_entry(count) do
    messages = [
      "Memory stats refreshed",
      "Process tree scanned",
      "Render frame #{count} complete",
      "Scheduler utilization: #{70 + :rand.uniform(25)}%",
      "GC minor collection ran",
      "IO throughput: #{:rand.uniform(500) + 100} KB/s",
      "ETS tables checked: #{:ets.all() |> length()}",
      "Reduction count sampled",
      "Port status verified",
      "Node uptime checkpoint"
    ]

    Enum.at(messages, rem(count, length(messages)))
  end
end

Raxol.Core.Runtime.Log.info("RaxolDemo: Starting...")
{:ok, pid} = Raxol.start_link(RaxolDemo, [])
Raxol.Core.Runtime.Log.info("RaxolDemo: Running. Press 'q' to quit.")

ref = Process.monitor(pid)

receive do
  {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
end
