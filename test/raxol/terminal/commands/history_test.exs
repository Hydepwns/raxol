defmodule Raxol.Terminal.Commands.HistoryTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Commands.History

  describe "new/1" do
    test "creates a new history with specified max size" do
      history = History.new(1000)
      assert %History{} = history
      assert history.max_size == 1000
      assert history.commands == []
      assert history.current_index == -1
      assert history.current_input == ""
    end

    test "raises error when max_size is not positive" do
      assert_raise FunctionClauseError, fn ->
        History.new(0)
      end

      assert_raise FunctionClauseError, fn ->
        History.new(-10)
      end
    end
  end

  describe "add/2" do
    test "adds command to empty history" do
      history = History.new(10)
      history = History.add(history, "test command")

      assert history.commands == ["test command"]
      assert history.current_index == -1
      assert history.current_input == ""
    end

    test "adds command to existing history" do
      history =
        History.new(10)
        |> History.add("first command")
        |> History.add("second command")

      assert history.commands == ["second command", "first command"]
    end

    test "respects max_size limit" do
      history = History.new(3)

      history =
        Enum.reduce(
          ["cmd1", "cmd2", "cmd3", "cmd4", "cmd5"],
          history,
          fn cmd, acc -> History.add(acc, cmd) end
        )

      assert length(history.commands) == 3
      assert history.commands == ["cmd5", "cmd4", "cmd3"]
    end
  end

  describe "previous/1" do
    test "returns nil for empty history" do
      history = History.new(10)
      assert {nil, ^history} = History.previous(history)
    end

    test "returns previous command and updates index" do
      history =
        History.new(10)
        |> History.add("first command")
        |> History.add("second command")

      {command, history} = History.previous(history)
      assert command == "second command"
      assert history.current_index == 0

      {command, history} = History.previous(history)
      assert command == "first command"
      assert history.current_index == 1

      # No more commands
      {command, history} = History.previous(history)
      assert command == nil
      assert history.current_index == 1
    end
  end

  describe "next/1" do
    test "returns nil for empty history" do
      history = History.new(10)
      assert {nil, ^history} = History.next(history)
    end

    test "returns next command after previous calls" do
      history =
        History.new(10)
        |> History.add("first command")
        |> History.add("second command")

      # First go back in history
      {_, history} = History.previous(history)
      {_, history} = History.previous(history)

      # Now go forward
      {command, history} = History.next(history)
      assert command == "second command"
      assert history.current_index == 0

      {command, history} = History.next(history)
      assert command == history.current_input
      assert history.current_index == -1

      # No more commands
      {command, history} = History.next(history)
      assert command == nil
      assert history.current_index == -1
    end

    test "returns saved input when at start position" do
      history =
        History.new(10)
        |> History.add("command")
        |> History.save_input("partial input")

      # Go back in history
      {_, history} = History.previous(history)

      # Now go forward
      {command, history} = History.next(history)
      assert command == "partial input"
      assert history.current_index == -1
    end
  end

  describe "save_input/2" do
    test "saves current input" do
      history = History.new(10)
      history = History.save_input(history, "partial command")

      assert history.current_input == "partial command"
    end
  end

  describe "clear/1" do
    test "clears all commands" do
      history =
        History.new(10)
        |> History.add("command 1")
        |> History.add("command 2")
        |> History.save_input("partial command")

      history = History.clear(history)

      assert history.commands == []
      assert history.current_index == -1
      assert history.current_input == ""
    end
  end

  describe "list/1" do
    test "returns empty list for empty history" do
      history = History.new(10)
      assert History.list(history) == []
    end

    test "returns list of commands in order" do
      history =
        History.new(10)
        |> History.add("first command")
        |> History.add("second command")
        |> History.add("third command")

      assert History.list(history) == [
               "third command",
               "second command",
               "first command"
             ]
    end
  end
end
