# This is an example of how to create subscriptions. The example app below
# subscribes to two different time intervals ("big ticks" and "little ticks") by
# returning a batch subscription in the `subscribe/1` callback.
#
# Run this example with:
#
#   mix run examples/subscriptions.exs

defmodule SubscriptionsExample do
  # Use the correct Application behaviour
  use Raxol.Core.Runtime.Application
  # Import the View DSL
  import Raxol.View.Elements

  # Alias for subscriptions
  alias Raxol.Core.Runtime.Events.Subscription
  require Logger

  @impl true
  def init(_context) do
    Logger.debug("SubscriptionsExample: init/1")
    # Return the correct tuple with a map model
    {:ok, %{little_ticks: 0, big_ticks: 0}}
  end

  @impl true
  def update(message, model) do
    Logger.debug("SubscriptionsExample: update/2 received message: \#{inspect(message)}")
    case message do
      :little_tick ->
        # Return the correct :ok tuple
        new_model = %{model | little_ticks: model.little_ticks + 1}
        {:ok, new_model, []}

      :big_tick ->
        new_model = %{model | big_ticks: model.big_ticks + 1}
        {:ok, new_model, []}

      _ ->
        {:ok, model, []}
    end
  end

  # Renamed from subscribe/1
  @impl true
  def subscriptions(_model) do
    Logger.debug("SubscriptionsExample: subscriptions/1")
    # Assuming Subscription API is correct
    Subscription.batch([
      Subscription.interval(1000, :big_tick),  # Send :big_tick every 1000ms
      Subscription.interval(100, :little_tick) # Send :little_tick every 100ms
    ])
  end

  # Renamed from render/1 to view/1
  @impl true
  def view(%{little_ticks: little_ticks, big_ticks: big_ticks} = model) do
    Logger.debug("SubscriptionsExample: view/1")
    # Use the Raxol.View.Elements DSL
    view do
      box title: "Subscriptions Example", style: [[:padding, 1], [:border, :single]] do
        column style: %{gap: 1} do
          text(content: "Little ticks: \#{little_ticks}")
          text(content: "Big ticks:    \#{big_ticks}")
          text(content: "(Press Ctrl+C to exit)", style: %{margin_top: 1})
        end
      end
    end
  end
end

Logger.info("SubscriptionsExample: Starting Raxol...")
# Use the standard startup mechanism
{:ok, _pid} = Raxol.start_link(SubscriptionsExample, [])
Logger.info("SubscriptionsExample: Raxol started. Running...")

# For CI/test/demo: sleep for 2 seconds, then exit. Adjust as needed.
Process.sleep(2000)
