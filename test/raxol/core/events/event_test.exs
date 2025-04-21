defmodule Raxol.Core.Events.EventTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Events.Event

  describe "new/2" do
    test "creates a new event with type and data" do
      event = Event.new(:test, :data)
      assert %Event{} = event
      assert event.type == :test
      assert event.data == :data
      assert is_integer(event.timestamp)
    end
  end

  describe "key_event/3" do
    test "creates a keyboard event with default modifiers" do
      event = Event.key_event(:enter, :pressed)
      assert %Event{type: :key} = event

      assert %{
               key: :enter,
               state: :pressed,
               modifiers: []
             } = event.data
    end

    test "creates a keyboard event with modifiers" do
      event = Event.key_event("a", :released, [:shift, :ctrl])
      assert %Event{type: :key} = event

      assert %{
               key: "a",
               state: :released,
               modifiers: [:shift, :ctrl]
             } = event.data
    end

    test "validates key state" do
      assert_raise FunctionClauseError, fn ->
        Event.key_event(:enter, :invalid)
      end
    end

    test "validates modifiers is a list" do
      assert_raise FunctionClauseError, fn ->
        Event.key_event(:enter, :pressed, :not_a_list)
      end
    end
  end

  describe "mouse_event/4" do
    test "creates a mouse event with defaults" do
      event = Event.mouse(:left, {10, 20})
      assert %Event{type: :mouse} = event

      assert %{
               button: :left,
               state: :pressed,
               position: {10, 20},
               modifiers: []
             } = event.data
    end

    test "creates a mouse event with all parameters" do
      event = Event.mouse_event(:left, {10, 20}, :pressed, [:shift])
      assert %Event{type: :mouse} = event

      assert %{
               button: :left,
               state: :pressed,
               position: {10, 20},
               modifiers: [:shift]
             } = event.data
    end

    test "validates mouse button" do
      assert_raise FunctionClauseError, fn ->
        Event.mouse_event(:invalid, {0, 0}, :pressed)
      end
    end

    test "validates mouse state" do
      assert_raise FunctionClauseError, fn ->
        Event.mouse_event(:left, {0, 0}, :invalid)
      end
    end

    test "validates position is a 2-tuple" do
      assert_raise FunctionClauseError, fn ->
        Event.mouse_event(:left, :not_a_tuple, :pressed)
      end

      assert_raise FunctionClauseError, fn ->
        Event.mouse_event(:left, {0, 0, 0}, :pressed)
      end
    end
  end

  describe "window_event/3" do
    test "creates a window event with defaults" do
      event = Event.window_event(0, 0, :focus)
      assert %Event{type: :window} = event

      assert %{
               action: :focus,
               width: 0,
               height: 0
             } = event.data
    end

    test "creates a resize event with dimensions" do
      event = Event.window_event(80, 24, :resize)
      assert %Event{type: :window} = event

      assert %{
               action: :resize,
               width: 80,
               height: 24
             } = event.data
    end

    test "validates window action" do
      assert_raise FunctionClauseError, fn ->
        Event.window_event(0, 0, :invalid)
      end
    end

    test "validates width and height are integers or nil" do
      assert_raise FunctionClauseError, fn ->
        Event.window_event(:not_integer, 24, :resize)
      end

      assert_raise FunctionClauseError, fn ->
        Event.window_event(80, :not_integer, :resize)
      end
    end
  end

  describe "custom_event/1" do
    test "creates a system event (as custom)" do
      event = Event.custom_event(:shutdown)
      assert %Event{type: :custom} = event
      assert event.data == :shutdown
    end

    test "creates a custom event with complex data" do
      custom_data = %{type: :"app.custom", value: 123}
      event = Event.custom_event(custom_data)
      assert %Event{type: :custom} = event
      assert event.data == custom_data
    end
  end
end
