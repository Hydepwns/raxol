# Clock
#
# A real-time clock demonstrating time-based subscriptions.
#
# Usage:
#   mix run examples/scripts/clock.exs

defmodule ClockExample do
  use Raxol.Core.Runtime.Application

  require Raxol.Core.Runtime.Log

  @impl true
  def init(_context) do
    %{time: DateTime.utc_now()}
  end

  @impl true
  def update(message, model) do
    case message do
      :tick ->
        {%{model | time: DateTime.utc_now()}, []}

      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [command(:quit)]}

      %Raxol.Core.Events.Event{
        type: :key,
        data: %{key: :char, char: "c", ctrl: true}
      } ->
        {model, [command(:quit)]}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    time_str = Calendar.strftime(model.time, "%H:%M:%S")
    date_str = Calendar.strftime(model.time, "%Y-%m-%d")

    column style: %{padding: 2, gap: 1, align_items: :center} do
      [
        box title: "Clock",
            style: %{
              border: :single,
              padding: 1,
              width: 30,
              justify_content: :center
            } do
          column style: %{gap: 1, align_items: :center} do
            [
              text(time_str, style: [:bold]),
              text(date_str)
            ]
          end
        end,
        text("Press 'q' to quit.")
      ]
    end
  end

  @impl true
  def subscribe(_model) do
    [subscribe_interval(1000, :tick)]
  end
end

Raxol.Core.Runtime.Log.info("ClockExample: Starting...")
{:ok, pid} = Raxol.start_link(ClockExample, [])
ref = Process.monitor(pid)

receive do
  {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
end
