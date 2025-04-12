defmodule Raxol.Terminal.CommandHistoryTest do
  use ExUnit.Case
  alias Raxol.Terminal.CommandHistory

  describe "new/1" do
    test "creates a new command history with specified max size" do
      history = CommandHistory.new(1000)
      assert history.max_size == 1000
      assert history.commands == []
      assert history.current_index == -1
      assert history.current_input == ""
    end

    test "raises error for invalid max size" do
      assert_raise FunctionClauseError, fn ->
        CommandHistory.new(0)
      end

      assert_raise FunctionClauseError, fn ->
        CommandHistory.new(-1)
      end
    end
  end

  describe "add/2" do
    test "adds a command to empty history" do
      history = CommandHistory.new(1000)
      history = CommandHistory.add(history, "ls -la")
      assert history.commands == ["ls -la"]
      assert history.current_index == -1
      assert history.current_input == ""
    end

    test "adds multiple commands in correct order" do
      history = CommandHistory.new(1000)
      history = CommandHistory.add(history, "ls -la")
      history = CommandHistory.add(history, "cd /tmp")
      assert history.commands == ["cd /tmp", "ls -la"]
    end

    test "respects max size limit" do
      history = CommandHistory.new(2)
      history = CommandHistory.add(history, "cmd1")
      history = CommandHistory.add(history, "cmd2")
      history = CommandHistory.add(history, "cmd3")
      assert history.commands == ["cmd3", "cmd2"]
    end
  end

  describe "previous/1" do
    test "returns nil for empty history" do
      history = CommandHistory.new(1000)
      assert {nil, ^history} = CommandHistory.previous(history)
    end

    test "navigates through command history" do
      history = CommandHistory.new(1000)
      history = CommandHistory.add(history, "cmd1")
      history = CommandHistory.add(history, "cmd2")
      history = CommandHistory.add(history, "cmd3")

      {cmd, history} = CommandHistory.previous(history)
      assert cmd == "cmd3"
      assert history.current_index == 0

      {cmd, history} = CommandHistory.previous(history)
      assert cmd == "cmd2"
      assert history.current_index == 1

      {cmd, history} = CommandHistory.previous(history)
      assert cmd == "cmd1"
      assert history.current_index == 2

      assert {nil, ^history} = CommandHistory.previous(history)
    end
  end

  describe "next/1" do
    test "returns nil when at the end of history" do
      history = CommandHistory.new(1000)
      assert {nil, ^history} = CommandHistory.next(history)
    end

    test "navigates back through command history" do
      history = CommandHistory.new(1000)
      history = CommandHistory.add(history, "cmd1")
      history = CommandHistory.add(history, "cmd2")
      history = CommandHistory.add(history, "cmd3")

      {_, history} = CommandHistory.previous(history)
      {_, history} = CommandHistory.previous(history)
      {_, history} = CommandHistory.previous(history)

      {cmd, history} = CommandHistory.next(history)
      assert cmd == "cmd2"
      assert history.current_index == 1

      {cmd, history} = CommandHistory.next(history)
      assert cmd == "cmd3"
      assert history.current_index == 0

      {cmd, history} = CommandHistory.next(history)
      assert cmd == ""
      assert history.current_index == -1

      assert {nil, ^history} = CommandHistory.next(history)
    end
  end

  describe "save_input/2" do
    test "saves current input state" do
      history = CommandHistory.new(1000)
      history = CommandHistory.save_input(history, "partial command")
      assert history.current_input == "partial command"
    end

    test "preserves other history state" do
      history = CommandHistory.new(1000)
      history = CommandHistory.add(history, "cmd1")
      history = CommandHistory.save_input(history, "partial command")
      assert history.commands == ["cmd1"]
      assert history.current_index == -1
    end
  end

  describe "clear/1" do
    test "clears all commands and resets state" do
      history = CommandHistory.new(1000)
      history = CommandHistory.add(history, "cmd1")
      history = CommandHistory.add(history, "cmd2")
      history = CommandHistory.save_input(history, "partial command")
      history = CommandHistory.clear(history)

      assert history.commands == []
      assert history.current_index == -1
      assert history.current_input == ""
    end
  end

  describe "list/1" do
    test "returns all commands in correct order" do
      history = CommandHistory.new(1000)
      history = CommandHistory.add(history, "cmd1")
      history = CommandHistory.add(history, "cmd2")
      history = CommandHistory.add(history, "cmd3")

      assert CommandHistory.list(history) == ["cmd3", "cmd2", "cmd1"]
    end

    test "returns empty list for new history" do
      history = CommandHistory.new(1000)
      assert CommandHistory.list(history) == []
    end
  end
end
