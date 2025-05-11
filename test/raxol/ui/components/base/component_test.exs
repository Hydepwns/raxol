defmodule Raxol.UI.Components.Base.ComponentTest do
  use ExUnit.Case, async: true
  import Raxol.ComponentTestHelpers

  # Test component that implements all lifecycle hooks
  defmodule TestComponent do
    @behaviour Raxol.UI.Components.Base.Component

    def init(props) do
      Map.merge(%{
        counter: 0,
        mounted: false,
        unmounted: false,
        events: [],
        render_count: 0
      }, props)
    end

    def mount(state) do
      new_state = %{state | mounted: true}
      {new_state, [{:command, :mounted}]}
    end

    def update(:increment, state) do
      %{state | counter: state.counter + 1}
    end

    def update(:decrement, state) do
      %{state | counter: state.counter - 1}
    end

    def render(state, context) do
      new_state = %{state | render_count: state.render_count + 1}
      {new_state, %{
        type: :test_component,
        id: state.id,
        counter: state.counter,
        theme: context.theme
      }}
    end

    def handle_event(%{type: :test_event, value: value}, state) do
      new_state = %{state | events: [value | state.events]}
      {new_state, [{:command, :event_handled}]}
    end

    def handle_event(_event, state) do
      {state, []}
    end

    def unmount(state) do
      %{state | unmounted: true}
    end
  end

  describe "Component Lifecycle" do
    test "complete lifecycle flow" do
      component = create_test_component(TestComponent)

      {final_component, events} = simulate_lifecycle(component, fn mounted ->
        # Verify mounted state
        assert mounted.state.mounted
        assert_receive {:commands, [{:command, :mounted}]}

        # Update state
        updated = simulate_event_sequence(mounted, [
          %{type: :test_event, value: "test1"},
          %{type: :test_event, value: "test2"}
        ])

        # Verify updates
        assert updated.state.counter == 0
        assert updated.state.events == ["test2", "test1"]

        updated
      end)

      # Verify final state
      assert final_component.state.unmounted
      assert length(events) > 0
    end

    test "mount with initial props" do
      component = create_test_component(TestComponent, %{counter: 5})
      assert component.state.counter == 5
    end

    test "unmount cleanup" do
      component = create_test_component(TestComponent)
      {final, _} = simulate_lifecycle(component, &(&1))
      assert final.state.unmounted
    end
  end

  describe "State Management" do
    test "state updates through events" do
      component = create_test_component(TestComponent)

      updated = simulate_event_sequence(component, [
        %{type: :test_event, value: "test1"},
        %{type: :test_event, value: "test2"}
      ])

      assert updated.state.events == ["test2", "test1"]
    end

    test "state updates through commands" do
      component = create_test_component(TestComponent)

      {updated, commands} = Unit.simulate_event(component, %{type: :test_event, value: "test"})

      assert updated.state.events == ["test"]
      assert commands == [{:command, :event_handled}]
    end
  end

  describe "Rendering" do
    test "renders with different contexts" do
      component = create_test_component(TestComponent)

      contexts = [
        %{theme: %{mode: :light}},
        %{theme: %{mode: :dark}},
        %{theme: %{mode: :high_contrast}}
      ]

      rendered = validate_rendering(component, contexts)

      assert length(rendered) == 3
      assert Enum.all?(rendered, &(&1.type == :test_component))
    end

    test "render count tracking" do
      component = create_test_component(TestComponent)

      {final, _} = simulate_lifecycle(component, fn mounted ->
        # Render multiple times
        contexts = [%{theme: %{}}, %{theme: %{}}, %{theme: %{}}]
        validate_rendering(mounted, contexts)
        mounted
      end)

      assert final.state.render_count > 0
    end
  end

  describe "Event Handling" do
    test "handles known events" do
      component = create_test_component(TestComponent)

      {updated, commands} = Unit.simulate_event(component, %{type: :test_event, value: "test"})

      assert updated.state.events == ["test"]
      assert commands == [{:command, :event_handled}]
    end

    test "ignores unknown events" do
      component = create_test_component(TestComponent)

      {updated, commands} = Unit.simulate_event(component, %{type: :unknown_event})

      assert updated.state == component.state
      assert commands == []
    end

    test "event sequence handling" do
      component = create_test_component(TestComponent)

      events = [
        %{type: :test_event, value: "test1"},
        %{type: :test_event, value: "test2"},
        %{type: :unknown_event}
      ]

      updated = simulate_event_sequence(component, events)

      assert updated.state.events == ["test2", "test1"]
    end
  end

  describe "Performance" do
    test "handles rapid event sequences" do
      component = create_test_component(TestComponent)

      # Create a workload of 100 events
      workload = fn comp ->
        events = Enum.map(1..100, &%{type: :test_event, value: "test#{&1}"})
        simulate_event_sequence(comp, events)
      end

      metrics = measure_performance(component, workload)

      assert metrics.iterations == 100
      assert metrics.average_time < 100 # Less than 100ms per iteration
    end
  end

  describe "Accessibility" do
    test "renders with accessibility context" do
      component = create_test_component(TestComponent)

      result = validate_accessibility(component)

      assert result.passed
      assert result.checks[:has_contrast_ratio]
      assert result.checks[:has_aria_labels]
      assert result.checks[:has_keyboard_navigation]
    end
  end

  describe "Error Handling" do
    test "handles invalid events gracefully" do
      component = create_test_component(TestComponent)

      {updated, commands} = Unit.simulate_event(component, %{type: :invalid_event, data: nil})

      assert updated.state == component.state
      assert commands == []
    end

    test "handles missing optional callbacks" do
      # Create a component without mount/unmount
      defmodule MinimalComponent do
        @behaviour Raxol.UI.Components.Base.Component

        def init(props), do: props
        def render(state, _context), do: {state, %{type: :minimal}}
        def handle_event(_event, state), do: {state, []}
      end

      component = create_test_component(MinimalComponent)
      {final, _} = simulate_lifecycle(component, &(&1))

      assert final.state == component.state
    end
  end
end
