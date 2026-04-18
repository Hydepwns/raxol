defmodule Raxol.Speech.InputAdapterTest do
  use ExUnit.Case, async: true

  alias Raxol.Speech.InputAdapter

  describe "translate/1" do
    test "maps 'quit' to q key event" do
      event = InputAdapter.translate("quit")
      assert event.type == :key
      assert event.data.char == "q"
    end

    test "maps 'exit' to q key event" do
      event = InputAdapter.translate("exit")
      assert event.type == :key
      assert event.data.char == "q"
    end

    test "maps arrow words to arrow key events" do
      for {word, expected} <- [{"up", :up}, {"down", :down}, {"left", :left}, {"right", :right}] do
        event = InputAdapter.translate(word)
        assert event.type == :key
        assert event.data.key == expected, "expected #{word} -> #{expected}"
      end
    end

    test "maps 'enter' to enter key event" do
      event = InputAdapter.translate("enter")
      assert event.type == :key
      assert event.data.key == :enter
    end

    test "maps 'tab' to tab key event" do
      event = InputAdapter.translate("tab")
      assert event.type == :key
      assert event.data.key == :tab
    end

    test "maps 'space' to space char event" do
      event = InputAdapter.translate("space")
      assert event.type == :key
      assert event.data.char == " "
    end

    test "maps 'scroll down' to j key" do
      event = InputAdapter.translate("scroll down")
      assert event.type == :key
      assert event.data.char == "j"
    end

    test "maps 'scroll up' to k key" do
      event = InputAdapter.translate("scroll up")
      assert event.type == :key
      assert event.data.char == "k"
    end

    test "is case-insensitive" do
      event = InputAdapter.translate("QUIT")
      assert event.type == :key
      assert event.data.char == "q"
    end

    test "trims whitespace" do
      event = InputAdapter.translate("  up  ")
      assert event.type == :key
      assert event.data.key == :up
    end

    test "unknown text becomes paste event" do
      event = InputAdapter.translate("hello world")
      assert event.type == :paste
      assert event.data.text == "hello world"
    end

    test "single unknown word becomes paste event" do
      event = InputAdapter.translate("foobar")
      assert event.type == :paste
      assert event.data.text == "foobar"
    end

    test "empty string returns nil" do
      assert InputAdapter.translate("") == nil
      assert InputAdapter.translate("   ") == nil
    end

    test "nil returns nil" do
      assert InputAdapter.translate(nil) == nil
    end
  end

  describe "translate/2 with custom commands" do
    test "merges custom commands with defaults" do
      event =
        InputAdapter.translate("deploy",
          commands: %{"deploy" => {:key, %{key: :char, char: "d"}}}
        )

      assert event.type == :key
      assert event.data.char == "d"
    end

    test "custom commands override defaults" do
      event = InputAdapter.translate("quit", commands: %{"quit" => {:key, %{key: :escape}}})
      assert event.type == :key
      assert event.data.key == :escape
    end

    test "defaults still work with custom commands" do
      event =
        InputAdapter.translate("up", commands: %{"deploy" => {:key, %{key: :char, char: "d"}}})

      assert event.type == :key
      assert event.data.key == :up
    end
  end

  describe "default_commands/0" do
    test "returns a map of command strings to event tuples" do
      commands = InputAdapter.default_commands()
      assert is_map(commands)
      assert map_size(commands) > 10
      assert {:key, %{key: :up}} = commands["up"]
    end
  end
end
