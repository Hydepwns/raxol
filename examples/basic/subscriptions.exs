# This is an example of how to create subscriptions. The example app below
# subscribes to two different time intervals ("big ticks" and "little ticks") by
# returning a batch subscription in the `subscribe/1` callback.
#
# Run this example with:
#
#   mix run examples/subscriptions.exs

defmodule Subscriptions do
  @behaviour Raxol.App
  use Raxol.View

  alias Raxol.Core.Runtime.Events.Subscription

  def init(_context), do: {0, 0}

  def update({little_ticks, big_ticks} = model, msg) do
    case msg do
      :little_tick ->
        {little_ticks + 1, big_ticks}

      :big_tick ->
        {little_ticks, big_ticks + 1}

      _ ->
        model
    end
  end

  def subscribe(_model) do
    Subscription.batch([
      Subscription.interval(1000, :big_tick),
      Subscription.interval(100, :little_tick)
    ])
  end

  def render(%{little_ticks: little_ticks, big_ticks: big_ticks}) do
    view do
      panel title: "Subscriptions Example" do
        column do
          text(content: "Little ticks: #{little_ticks}")
          text(content: "Big ticks:    #{big_ticks}")
        end
      end
    end
  end
end

Raxol.run(Subscriptions, interval: 100)
