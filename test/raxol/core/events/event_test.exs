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
      event = Event.mouse_event(nil, nil, {10, 20})
      assert %Event{type: :mouse} = event
      assert %{
        button: nil,
        state: nil,
        position: {10, 20},
        modifiers: []
      } = event.data
    end

    test "creates a mouse event with all parameters" do
      event = Event.mouse_event(:left, :pressed, {10, 20}, [:shift])
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
        Event.mouse_event(:invalid, :pressed, {0, 0})
      end
    end

    test "validates mouse state" do
      assert_raise FunctionClauseError, fn ->
        Event.mouse_event(:left, :invalid, {0, 0})
      end
    end

    test "validates position is a 2-tuple" do
      assert_raise FunctionClauseError, fn ->
        Event.mouse_event(:left, :pressed, :not_a_tuple)
      end

      assert_raise FunctionClauseError, fn ->
        Event.mouse_event(:left, :pressed, {0, 0, 0})
      end
    end
  end

  describe "window_event/3" do
    test "creates a window event with defaults" do
      event = Event.window_event(:focus)
      assert %Event{type: :window} = event
      assert %{
        action: :focus,
        width: nil,
        height: nil
      } = event.data
    end

    test "creates a resize event with dimensions" do
      event = Event.window_event(:resize, 80, 24)
      assert %Event{type: :window} = event
      assert %{
        action: :resize,
        width: 80,
        height: 24
      } = event.data
    end

    test "validates window action" do
      assert_raise FunctionClauseError, fn ->
        Event.window_event(:invalid)
      end
    end

    test "validates width and height are integers or nil" do
      assert_raise FunctionClauseError, fn ->
        Event.window_event(:resize, :not_integer, 24)
      end

      assert_raise FunctionClauseError, fn ->
        Event.window_event(:resize, 80, :not_integer)
      end
    end
  end

  describe "system_event/1" do
    test "creates a system event" do
      event = Event.system_event(:shutdown)
      assert %Event{type: :system} = event
      assert %{action: :shutdown} = event.data
    end

    test "validates system action" do
      assert_raise FunctionClauseError, fn ->
        Event.system_event(:invalid)
      end
    end
  end

  describe "custom_event/2" do
    test "creates a custom event" do
      event = Event.custom_event(:"app.custom", %{value: 123})
      assert %Event{type: :"app.custom"} = event
      assert %{value: 123} = event.data
    end

    test "validates type is an atom" do
      assert_raise FunctionClauseError, fn ->
        Event.custom_event("not_atom", :data)
      end
    end
  end
end 