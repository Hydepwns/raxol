defmodule Raxol.Terminal.CommandHistoryTest do
  use ExUnit.Case
  alias Raxol.Terminal.Commands.History

  describe "new/1" do
    test "creates a new command history with specified max size" do
      history = History.new(1000)
      assert history.max_size == 1000
      assert history.commands == []
      assert history.current_index == -1
      assert history.current_input == ""
    end

    test "raises error for invalid max size" do
      assert_raise FunctionClauseError, fn ->
        History.new(0)
      end

      assert_raise FunctionClauseError, fn ->
        History.new(-1)
      end
    end
  end

  describe "add/2" do
    test "adds a command to empty history" do
      history = History.new(1000)
      history = History.add(history, "ls -la")
      assert history.commands == ["ls -la"]
      assert history.current_index == -1
      assert history.current_input == ""
    end

    test "adds multiple commands in correct order" do
      history = History.new(1000)
      history = History.add(history, "ls -la")
      history = History.add(history, "cd /tmp")
      assert history.commands == ["cd /tmp", "ls -la"]
    end

    test "respects max size limit" do
      history = History.new(2)
      history = History.add(history, "cmd1")
      history = History.add(history, "cmd2")
      history = History.add(history, "cmd3")
      assert history.commands == ["cmd3", "cmd2"]
    end
  end

  describe "previous/1" do
    test "returns nil for empty history" do
      history = History.new(1000)
      assert {nil, ^history} = History.previous(history)
    end

    test "navigates through command history" do
      history = History.new(1000)
      history = History.add(history, "cmd1")
      history = History.add(history, "cmd2")
      history = History.add(history, "cmd3")

      {cmd, history} = History.previous(history)
      assert cmd == "cmd3"
      assert history.current_index == 0

      {cmd, history} = History.previous(history)
      assert cmd == "cmd2"
      assert history.current_index == 1

      {cmd, history} = History.previous(history)
      assert cmd == "cmd1"
      assert history.current_index == 2

      assert {nil, ^history} = History.previous(history)
    end
  end

  describe "next/1" do
    test "returns nil when at the end of history" do
      history = History.new(1000)
      assert {nil, ^history} = History.next(history)
    end

    test "navigates back through command history" do
      history = History.new(1000)
      history = History.add(history, "cmd1")
      history = History.add(history, "cmd2")
      history = History.add(history, "cmd3")

      {_, history} = History.previous(history)
      {_, history} = History.previous(history)
      {_, history} = History.previous(history)

      {cmd, history} = History.next(history)
      assert cmd == "cmd2"
      assert history.current_index == 1

      {cmd, history} = History.next(history)
      assert cmd == "cmd3"
      assert history.current_index == 0

      {cmd, history} = History.next(history)
      assert cmd == ""
      assert history.current_index == -1

      assert {nil, ^history} = History.next(history)
    end
  end

  describe "save_input/2" do
    test "saves current input state" do
      history = History.new(1000)
      history = History.save_input(history, "partial command")
      assert history.current_input == "partial command"
    end

    test "preserves other history state" do
      history = History.new(1000)
      history = History.add(history, "cmd1")
      history = History.save_input(history, "partial command")
      assert history.commands == ["cmd1"]
      assert history.current_index == -1
    end
  end

  describe "clear/1" do
    test "clears all commands and resets state" do
      history = History.new(1000)
      history = History.add(history, "cmd1")
      history = History.add(history, "cmd2")
      history = History.save_input(history, "partial command")
      history = History.clear(history)

      assert history.commands == []
      assert history.current_index == -1
      assert history.current_input == ""
    end
  end

  describe "list/1" do
    test "returns all commands in correct order" do
      history = History.new(1000)
      history = History.add(history, "cmd1")
      history = History.add(history, "cmd2")
      history = History.add(history, "cmd3")

      assert History.list(history) == ["cmd3", "cmd2", "cmd1"]
    end

    test "returns empty list for new history" do
      history = History.new(1000)
      assert History.list(history) == []
    end
  end
end
