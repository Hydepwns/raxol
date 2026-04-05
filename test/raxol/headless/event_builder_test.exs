defmodule Raxol.Headless.EventBuilderTest do
  use ExUnit.Case, async: false

  alias Raxol.Core.Events.Event
  alias Raxol.Headless.EventBuilder

  describe "key/2 with character strings" do
    test "builds a char key event" do
      event = EventBuilder.key("q")
      assert %Event{type: :key, data: %{key: :char, char: "q"}} = event
    end

    test "builds a space key event" do
      event = EventBuilder.key(" ")
      assert %Event{type: :key, data: %{key: :char, char: " "}} = event
    end

    test "adds ctrl modifier" do
      event = EventBuilder.key("c", ctrl: true)
      assert %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} = event
    end

    test "adds alt modifier" do
      event = EventBuilder.key("x", alt: true)
      assert %Event{type: :key, data: %{key: :char, char: "x", alt: true}} = event
    end

    test "adds multiple modifiers" do
      event = EventBuilder.key("a", ctrl: true, shift: true)
      data = event.data
      assert data.key == :char
      assert data.char == "a"
      assert data.ctrl == true
      assert data.shift == true
    end

    test "omits false modifiers" do
      event = EventBuilder.key("x", ctrl: false)
      refute Map.has_key?(event.data, :ctrl)
    end
  end

  describe "key/2 with atom specials" do
    test "builds a tab key event" do
      event = EventBuilder.key(:tab)
      assert %Event{type: :key, data: %{key: :tab}} = event
    end

    test "builds an enter key event" do
      event = EventBuilder.key(:enter)
      assert %Event{type: :key, data: %{key: :enter}} = event
    end

    test "builds an escape key event" do
      event = EventBuilder.key(:escape)
      assert %Event{type: :key, data: %{key: :escape}} = event
    end

    test "adds modifiers to special keys" do
      event = EventBuilder.key(:tab, shift: true)
      assert %Event{type: :key, data: %{key: :tab, shift: true}} = event
    end
  end

  describe "timestamp" do
    test "events have a timestamp" do
      event = EventBuilder.key("a")
      assert %DateTime{} = event.timestamp
    end
  end
end
