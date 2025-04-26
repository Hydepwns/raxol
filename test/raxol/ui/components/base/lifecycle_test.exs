defmodule Raxol.UI.Components.Base.LifecycleTest do
  use ExUnit.Case, async: true

  # Define a test component that implements the Component behavior
  defmodule TestComponent do
    @behaviour Raxol.UI.Components.Base.Component

    # Track lifecycle events
    def new(opts \\ []) do
      %{
        id:
          Keyword.get(
            opts,
            :id,
            "test-component-#{:erlang.unique_integer([:positive])}"
          ),
        value: Keyword.get(opts, :value, ""),
        lifecycle_events: [],
        render_count: 0,
        handle_event_count: 0
      }
    end

    @impl true
    def render(component, _context) do
      updated = Map.update!(component, :render_count, &(&1 + 1))

      updated =
        Map.update!(updated, :lifecycle_events, &[{:render, :called} | &1])

      %{
        type: :test_component,
        id: updated.id,
        attrs: %{
          value: updated.value
        }
      }
    end

    @impl true
    def handle_event(component, event, _context) do
      updated = Map.update!(component, :handle_event_count, &(&1 + 1))

      updated =
        Map.update!(updated, :lifecycle_events, &[{:handle_event, event} | &1])

      case event do
        %{type: :test, value: value} ->
          {:update, %{updated | value: value}}

        %{type: :no_change} ->
          {:handled, updated}

        _ ->
          :passthrough
      end
    end

    # Extra functions to simulate mount/unmount hooks
    def mount(component) do
      Map.update!(component, :lifecycle_events, &[{:mount, :called} | &1])
    end

    def update(component, props) do
      updated = Map.merge(component, props)
      Map.update!(updated, :lifecycle_events, &[{:update, props} | &1])
    end

    def unmount(component) do
      Map.update!(component, :lifecycle_events, &[{:unmount, :called} | &1])
    end
  end

  describe "component lifecycle" do
    test "mount adds event to lifecycle" do
      component = TestComponent.new()
      mounted = TestComponent.mount(component)

      assert Enum.at(mounted.lifecycle_events, 0) == {:mount, :called}
    end

    test "unmount adds event to lifecycle" do
      component = TestComponent.new()
      unmounted = TestComponent.unmount(component)

      assert Enum.at(unmounted.lifecycle_events, 0) == {:unmount, :called}
    end

    test "render increases render count" do
      component = TestComponent.new()
      context = %{theme: %{}}

      # First render
      TestComponent.render(component, context)

      # Render should be idempotent - verify by rendering multiple times
      rendered =
        component
        |> TestComponent.render(context)
        |> TestComponent.render(context)
        |> TestComponent.render(context)

      assert rendered.render_count == 4
      assert length(rendered.lifecycle_events) == 4
    end

    test "update correctly merges props" do
      component = TestComponent.new(value: "initial")
      updated = TestComponent.update(component, %{value: "updated"})

      assert updated.value == "updated"

      assert Enum.at(updated.lifecycle_events, 0) ==
               {:update, %{value: "updated"}}
    end
  end

  describe "event handling" do
    test "handle_event with update returns updated component" do
      component = TestComponent.new(value: "initial")
      event = %{type: :test, value: "updated"}

      {:update, updated} = TestComponent.handle_event(component, event, %{})

      assert updated.value == "updated"
      assert updated.handle_event_count == 1
      assert Enum.at(updated.lifecycle_events, 0) == {:handle_event, event}
    end

    test "handle_event with handled returns same component" do
      component = TestComponent.new()
      event = %{type: :no_change}

      {:handled, updated} = TestComponent.handle_event(component, event, %{})

      assert updated.handle_event_count == 1
      assert Enum.at(updated.lifecycle_events, 0) == {:handle_event, event}
    end

    test "handle_event with passthrough returns passthrough" do
      component = TestComponent.new()
      event = %{type: :unknown}

      result = TestComponent.handle_event(component, event, %{})

      assert result == :passthrough
    end

    test "multiple event handling updates counters correctly" do
      component = TestComponent.new(value: "initial")

      # Handle a series of events
      {:update, after_first} =
        TestComponent.handle_event(
          component,
          %{type: :test, value: "first"},
          %{}
        )

      {:handled, after_second} =
        TestComponent.handle_event(after_first, %{type: :no_change}, %{})

      {:update, after_third} =
        TestComponent.handle_event(
          after_second,
          %{type: :test, value: "third"},
          %{}
        )

      # Verify the final state
      assert after_third.value == "third"
      assert after_third.handle_event_count == 3
      assert length(after_third.lifecycle_events) == 3
    end
  end

  describe "complete lifecycle flow" do
    test "full component lifecycle" do
      # Create and mount
      component = TestComponent.new(value: "initial", id: "test-123")
      mounted = TestComponent.mount(component)

      # Render
      context = %{theme: %{}}
      rendered = TestComponent.render(mounted, context)

      # Handle events
      {:update, after_event} =
        TestComponent.handle_event(
          rendered,
          %{type: :test, value: "updated"},
          context
        )

      # Render again after update
      re_rendered = TestComponent.render(after_event, context)

      # Update props
      updated = TestComponent.update(re_rendered, %{value: "final"})

      # Unmount
      unmounted = TestComponent.unmount(updated)

      # Verify the full history
      events = Enum.reverse(unmounted.lifecycle_events)

      assert Enum.at(events, 0) == {:mount, :called}
      assert Enum.at(events, 1) == {:render, :called}

      assert Enum.at(events, 2) ==
               {:handle_event, %{type: :test, value: "updated"}}

      assert Enum.at(events, 3) == {:render, :called}
      assert Enum.at(events, 4) == {:update, %{value: "final"}}
      assert Enum.at(events, 5) == {:unmount, :called}

      # Verify final state
      assert unmounted.render_count == 2
      assert unmounted.handle_event_count == 1
      assert unmounted.id == "test-123"
      assert unmounted.value == "final"
    end
  end
end
