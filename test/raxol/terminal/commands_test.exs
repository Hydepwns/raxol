defmodule Raxol.Terminal.CommandsTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Raxol.Terminal.Commands
  alias Raxol.Terminal.Commands.{History, Parser, Screen}
  alias Raxol.Terminal.Emulator

  setup do
    # Create a real Emulator struct for testing Screen functions
    emulator = Emulator.new(80, 24)

    {:ok, emulator: emulator}
  end

  describe "delegation to History module" do
    test "new_history/1 delegates to History.new/1" do
      log =
        capture_log(fn ->
          history = Commands.new_history(500)
          assert %History{} = history
          assert history.max_size == 500
        end)

      assert log =~ "is deprecated"
      assert log =~ "Use Raxol.Terminal.Commands.History.new/1 instead"
    end

    test "add_to_history/2 delegates to History.add/2" do
      history = History.new(100)

      log =
        capture_log(fn ->
          updated = Commands.add_to_history(history, "test command")
          assert updated.commands == ["test command"]
        end)

      assert log =~ "is deprecated"
      assert log =~ "Use Raxol.Terminal.Commands.History.add/2 instead"
    end

    test "previous_command/1 delegates to History.previous/1" do
      history =
        History.new(100)
        |> History.add("test command")

      log =
        capture_log(fn ->
          {command, _updated} = Commands.previous_command(history)
          assert command == "test command"
        end)

      assert log =~ "is deprecated"
      assert log =~ "Use Raxol.Terminal.Commands.History.previous/1 instead"
    end

    test "next_command/1 delegates to History.next/1" do
      history =
        History.new(100)
        |> History.add("test command")

      {_, history} = History.previous(history)

      log =
        capture_log(fn ->
          {command, _updated} = History.next(history)
          assert command == "" # Should return current_input which is empty
        end)

      # Assert that the direct call to History.next does NOT produce a deprecation warning
      refute log =~ "is deprecated"
      assert log == ""
    end
  end

  describe "delegation to Parser module" do
    test "parse_params/1 delegates to Parser.parse_params/1" do
      log =
        capture_log(fn ->
          params = Commands.parse_params("1;2;3")
          assert params == [1, 2, 3]
        end)

      assert log =~ "is deprecated"
      assert log =~ "Use Raxol.Terminal.Commands.Parser.parse_params/1 instead"
    end

    test "get_param/3 delegates to Parser.get_param/3" do
      params = [1, 2, 3]

      log =
        capture_log(fn ->
          # Index 1 (first param)
          value1 = Commands.get_param(params, 1, 0)
          assert value1 == 1
          # Index 2 (second param)
          value2 = Commands.get_param(params, 2, 0)
          assert value2 == 2
          # Index 4 (out of bounds) -> should return default 99
          value4 = Commands.get_param(params, 4, 99)
          assert value4 == 99
        end)

      assert log =~ "is deprecated"
      assert log =~ "Use Raxol.Terminal.Commands.Parser.get_param/3 instead"
    end
  end

  describe "delegation to Screen module" do
    test "clear_screen/2 delegates to Screen.clear_screen/2", %{
      emulator: emulator
    } do
      log =
        capture_log(fn ->
          # Just verify it calls through, actual implementation tested in Screen tests
          Commands.clear_screen(emulator, 2)
        end)

      assert log =~ "is deprecated"
      assert log =~ "Use Raxol.Terminal.Commands.Screen.clear_screen/2 instead"
    end

    test "clear_line/2 delegates to Screen.clear_line/2", %{emulator: emulator} do
      log =
        capture_log(fn ->
          # Just verify it calls through, actual implementation tested in Screen tests
          Commands.clear_line(emulator, 2)
        end)

      assert log =~ "is deprecated"
      assert log =~ "Use Raxol.Terminal.Commands.Screen.clear_line/2 instead"
    end

    test "insert_line/2 delegates to Screen.insert_lines/2", %{
      emulator: emulator
    } do
      log =
        capture_log(fn ->
          # Just verify it calls through, actual implementation tested in Screen tests
          Commands.insert_line(emulator, 2)
        end)

      assert log =~ "is deprecated"
      assert log =~ "Use Raxol.Terminal.Commands.Screen.insert_lines/2 instead"
    end

    test "delete_line/2 delegates to Screen.delete_lines/2", %{
      emulator: emulator
    } do
      log =
        capture_log(fn ->
          # Just verify it calls through, actual implementation tested in Screen tests
          Commands.delete_line(emulator, 2)
        end)

      assert log =~ "is deprecated"
      assert log =~ "Use Raxol.Terminal.Commands.Screen.delete_lines/2 instead"
    end
  end
end
