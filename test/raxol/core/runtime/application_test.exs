defmodule Raxol.Core.Runtime.ApplicationTest do
  use ExUnit.Case, async: true

  # Test implementation of Application behavior
  defmodule TestApp do
    use Raxol.Core.Runtime.Application
    require Raxol.View.Elements
    # Import for cleaner syntax
    import Raxol.View.Elements

    @impl true
    def init(_context), do: %{count: 0}

    @impl true
    def update(message, state) do
      new_state =
        case message do
          :increment -> Map.update!(state, :count, &(&1 + 1))
          :decrement -> Map.update!(state, :count, &(&1 - 1))
          _ -> state
        end

      {new_state, []}
    end

    @impl true
    def view(state) do
      panel title: "Counter" do
        row do
          Raxol.View.Components.button(label: "-", on_click: :decrement)
          text("Count: #{state.count}")
          Raxol.View.Components.button(label: "+", on_click: :increment)
        end
      end
    end

    @impl true
    def handle_event(
          %Raxol.Core.Events.Event{
            type: :window,
            data: %{action: :resize, width: _w, height: _h}
          },
          state
        ) do
      # For testing purposes, just return the state unchanged
      {state, []}
    end

    def update({:add, amount}, model) do
      {%{model | count: model.count + amount},
       [{:command, :operation_complete}]}
    end

    def subscribe(model) do
      interval = if model.count > 10, do: 100, else: 1000

      [
        subscribe_interval(interval, :tick),
        subscribe_to_events([:key_press, :mouse_click])
      ]
    end
  end

  # Test implementation with minimal overrides
  defmodule MinimalTestApp do
    use Raxol.Core.Runtime.Application

    # Only override init
    def init(_) do
      %{minimal: true}
    end

    # Override view to ensure correct call to text/1
    @impl true
    def view(_state) do
      Raxol.Core.Renderer.View.text("Default view")
    end
  end

  describe "behavior implementation" do
    test "init/1 sets up initial state" do
      result = TestApp.init(%{})
      assert result == %{count: 0, initialized: true}
    end

    test "update/2 modifies state based on message" do
      model = %{count: 5, initialized: true}

      # Test increment
      {new_model, commands} = TestApp.update(:increment, model)
      assert new_model.count == 6
      assert commands == []

      # Test decrement
      {new_model, commands} = TestApp.update(:decrement, model)
      assert new_model.count == 4
      assert commands == []

      # Test command generation
      {new_model, commands} = TestApp.update({:add, 10}, model)
      assert new_model.count == 15
      assert commands == [{:command, :operation_complete}]
    end

    test "view/1 renders the current state" do
      model = %{count: 42, initialized: true}
      result = TestApp.view(model)

      # Test that view generates correct structure
      # Check that result is a struct
      assert is_struct(result)

      # Convert to string and check content
      string_result = inspect(result)
      assert string_result =~ "Count: 42"
      assert string_result =~ "panel"
      assert string_result =~ "button"
    end

    test "subscribe/1 creates subscriptions based on state" do
      # State with low count
      model = %{count: 5, initialized: true}
      subscriptions = TestApp.subscribe(model)

      assert length(subscriptions) == 2
      # Check interval subscription
      [interval_sub, events_sub] = subscriptions
      assert interval_sub.data.interval == 1000
      assert interval_sub.data.message == :tick

      # State with high count
      model = %{count: 15, initialized: true}
      subscriptions = TestApp.subscribe(model)

      [interval_sub, _] = subscriptions
      assert interval_sub.data.interval == 100
    end
  end

  describe "default implementations" do
    test "minimal app has functioning defaults" do
      # Init
      model = MinimalTestApp.init(%{})
      assert model == %{minimal: true}

      # Update returns unchanged state with no commands
      {new_model, commands} = MinimalTestApp.update(:any_message, model)
      assert new_model == model
      assert commands == []

      # View returns a default view
      view = MinimalTestApp.view(model)
      assert is_struct(view)
      string_view = inspect(view)
      assert string_view =~ "Default view"

      # Subscribe returns empty list
      assert MinimalTestApp.subscribe(model) == []
    end
  end

  describe "helper functions" do
    test "command/1 creates a command" do
      cmd = TestApp.command(:test_command)
      assert is_struct(cmd)
      assert cmd.type == :test_command
    end

    test "batch/1 creates a batch command" do
      cmd1 = TestApp.command(:cmd1)
      cmd2 = TestApp.command(:cmd2)

      batch = TestApp.batch([cmd1, cmd2])
      assert is_struct(batch)
      assert batch.type == :batch
      assert length(batch.data) == 2
    end

    test "subscribe_to_events/1 creates event subscription" do
      events = [:event1, :event2]
      subscription = TestApp.subscribe_to_events(events)

      assert is_struct(subscription)
      assert subscription.type == :events
      assert subscription.data == events
    end

    test "subscribe_interval/2 creates interval subscription" do
      subscription = TestApp.subscribe_interval(500, :tick)

      assert is_struct(subscription)
      assert subscription.type == :interval
      assert subscription.data.interval == 500
      assert subscription.data.message == :tick
    end
  end
end
