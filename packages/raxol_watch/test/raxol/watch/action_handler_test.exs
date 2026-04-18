defmodule Raxol.Watch.ActionHandlerTest do
  use ExUnit.Case, async: true

  alias Raxol.Watch.ActionHandler

  describe "handle_action/1" do
    test "maps 'pause' to space key" do
      event = ActionHandler.handle_action("pause")
      assert event.type == :key
      assert event.data.char == " "
    end

    test "maps 'details' to enter key" do
      event = ActionHandler.handle_action("details")
      assert event.type == :key
      assert event.data.key == :enter
    end

    test "maps 'quit' to q key" do
      event = ActionHandler.handle_action("quit")
      assert event.type == :key
      assert event.data.char == "q"
    end

    test "maps 'next' to tab key" do
      event = ActionHandler.handle_action("next")
      assert event.type == :key
      assert event.data.key == :tab
    end

    test "returns nil for 'dismiss'" do
      assert ActionHandler.handle_action("dismiss") == nil
    end

    test "returns nil for unknown actions" do
      assert ActionHandler.handle_action("unknown_action") == nil
    end
  end

  describe "handle_action/2 with custom map" do
    test "merges custom actions with defaults" do
      event = ActionHandler.handle_action("deploy", action_map: %{
        "deploy" => {:key, %{key: :char, char: "d"}}
      })
      assert event.type == :key
      assert event.data.char == "d"
    end

    test "custom actions override defaults" do
      event = ActionHandler.handle_action("pause", action_map: %{
        "pause" => {:key, %{key: :escape}}
      })
      assert event.type == :key
      assert event.data.key == :escape
    end
  end

  describe "default_action_map/0" do
    test "returns a map" do
      map = ActionHandler.default_action_map()
      assert is_map(map)
      assert map_size(map) > 0
    end
  end
end
