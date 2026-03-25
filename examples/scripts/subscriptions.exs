# Subscriptions
#
# Demonstrates time-based subscriptions with two different tick intervals.
#
# Usage:
#   mix run examples/scripts/subscriptions.exs

defmodule SubscriptionsExample do
  use Raxol.Core.Runtime.Application

  require Raxol.Core.Runtime.Log

  @impl true
  def init(_context) do
    %{little_ticks: 0, big_ticks: 0}
  end

  @impl true
  def update(message, model) do
    case message do
      :little_tick ->
        {%{model | little_ticks: model.little_ticks + 1}, []}

      :big_tick ->
        {%{model | big_ticks: model.big_ticks + 1}, []}

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
    column style: %{padding: 1, gap: 1} do
      [
        box title: "Subscriptions Example",
            style: %{border: :single, padding: 1} do
          column style: %{gap: 1} do
            [
              text("Little ticks (100ms): #{model.little_ticks}"),
              text("Big ticks   (1000ms): #{model.big_ticks}"),
              text("Press 'q' or Ctrl+C to quit.")
            ]
          end
        end
      ]
    end
  end

  @impl true
  def subscribe(_model) do
    [
      subscribe_interval(1000, :big_tick),
      subscribe_interval(100, :little_tick)
    ]
  end
end

Raxol.Core.Runtime.Log.info("SubscriptionsExample: Starting...")
{:ok, pid} = Raxol.start_link(SubscriptionsExample, [])
ref = Process.monitor(pid)

receive do
  {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
end
