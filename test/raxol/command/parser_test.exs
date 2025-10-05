defmodule Raxol.Command.ParserTest do
  use ExUnit.Case, async: true
  alias Raxol.Command.Parser

  describe "new/0" do
    test "creates empty parser" do
      parser = Parser.new()

      assert parser.commands == %{}
      assert parser.aliases == %{}
      assert parser.history == []
      assert parser.input == ""
      assert parser.cursor_pos == 0
    end
  end

  describe "register_command/3" do
    test "registers command handler" do
      handler = fn _args -> {:ok, "result"} end
      parser = Parser.new() |> Parser.register_command("test", handler)

      assert Map.has_key?(parser.commands, "test")
    end

    test "allows multiple commands" do
      parser =
        Parser.new()
        |> Parser.register_command("cmd1", fn _ -> {:ok, "1"} end)
        |> Parser.register_command("cmd2", fn _ -> {:ok, "2"} end)

      assert map_size(parser.commands) == 2
    end
  end

  describe "register_alias/3" do
    test "registers command alias" do
      parser =
        Parser.new()
        |> Parser.register_command("list", fn _ -> {:ok, "list"} end)
        |> Parser.register_alias("ls", "list")

      assert parser.aliases["ls"] == "list"
    end
  end

  describe "parse_and_execute/2" do
    setup do
      parser =
        Parser.new()
        |> Parser.register_command("echo", fn args ->
          {:ok, Enum.join(args, " ")}
        end)
        |> Parser.register_command("add", fn args ->
          sum = args |> Enum.map(&String.to_integer/1) |> Enum.sum()
          {:ok, sum}
        end)
        |> Parser.register_command("error", fn _args ->
          {:error, "test error"}
        end)

      {:ok, parser: parser}
    end

    test "executes simple command", %{parser: parser} do
      {:ok, result, _parser} = Parser.parse_and_execute(parser, "echo hello")
      assert result == "hello"
    end

    test "executes command with multiple args", %{parser: parser} do
      {:ok, result, _parser} = Parser.parse_and_execute(parser, "echo hello world")
      assert result == "hello world"
    end

    test "executes command with quoted strings", %{parser: parser} do
      {:ok, result, _parser} = Parser.parse_and_execute(parser, ~s(echo "hello world" test))
      assert result == "hello world test"
    end

    test "handles numeric arguments", %{parser: parser} do
      {:ok, result, _parser} = Parser.parse_and_execute(parser, "add 10 20 30")
      assert result == 60
    end

    test "returns error for unknown command", %{parser: parser} do
      {:error, reason, _parser} = Parser.parse_and_execute(parser, "unknown")
      assert reason =~ "Unknown command"
    end

    test "returns error from command handler", %{parser: parser} do
      {:error, reason, _parser} = Parser.parse_and_execute(parser, "error")
      assert reason == "test error"
    end

    test "adds command to history on success", %{parser: parser} do
      {:ok, _result, new_parser} = Parser.parse_and_execute(parser, "echo test")
      assert List.first(new_parser.history) == "echo test"
    end

    test "does not add duplicate consecutive commands", %{parser: parser} do
      {:ok, _result, parser} = Parser.parse_and_execute(parser, "echo test")
      {:ok, _result, parser} = Parser.parse_and_execute(parser, "echo test")

      assert length(parser.history) == 1
    end
  end

  describe "command aliases" do
    test "resolves alias to command" do
      parser =
        Parser.new()
        |> Parser.register_command("list", fn _ -> {:ok, "listed"} end)
        |> Parser.register_alias("ls", "list")

      {:ok, result, _parser} = Parser.parse_and_execute(parser, "ls")
      assert result == "listed"
    end

    test "works with aliased command and args" do
      parser =
        Parser.new()
        |> Parser.register_command("echo", fn args -> {:ok, Enum.join(args, " ")} end)
        |> Parser.register_alias("e", "echo")

      {:ok, result, _parser} = Parser.parse_and_execute(parser, "e hello world")
      assert result == "hello world"
    end
  end

  describe "interactive input" do
    test "handle_key adds character", %{} do
      parser = Parser.new()
      parser = Parser.handle_key(parser, "h")
      parser = Parser.handle_key(parser, "i")

      assert parser.input == "hi"
      assert parser.cursor_pos == 2
    end

    test "handle_key Backspace removes character" do
      parser = Parser.new()
      parser = Parser.handle_key(parser, "h")
      parser = Parser.handle_key(parser, "i")
      parser = Parser.handle_key(parser, "Backspace")

      assert parser.input == "h"
      assert parser.cursor_pos == 1
    end

    test "handle_key ArrowLeft moves cursor" do
      parser = Parser.new()
      parser = Parser.handle_key(parser, "h")
      parser = Parser.handle_key(parser, "i")
      parser = Parser.handle_key(parser, "ArrowLeft")

      assert parser.cursor_pos == 1
    end

    test "handle_key ArrowRight moves cursor" do
      parser = %{Parser.new() | input: "hi", cursor_pos: 0}
      parser = Parser.handle_key(parser, "ArrowRight")

      assert parser.cursor_pos == 1
    end
  end

  describe "tab completion" do
    setup do
      parser =
        Parser.new()
        |> Parser.register_command("echo", fn _ -> {:ok, ""} end)
        |> Parser.register_command("edit", fn _ -> {:ok, ""} end)
        |> Parser.register_command("exit", fn _ -> {:ok, ""} end)

      {:ok, parser: parser}
    end

    test "completes unique prefix", %{parser: parser} do
      parser = %{parser | input: "exi"}
      parser = Parser.handle_key(parser, "Tab")

      assert parser.input == "exit"
    end

    test "shows candidates for ambiguous prefix", %{parser: parser} do
      parser = %{parser | input: "e"}
      parser = Parser.handle_key(parser, "Tab")

      assert length(parser.completion_candidates) == 3
    end

    test "cycles through candidates on repeated tab", %{parser: parser} do
      parser = %{parser | input: "e"}
      parser = Parser.handle_key(parser, "Tab")
      parser = Parser.handle_key(parser, "Tab")

      assert parser.input in ["echo", "edit", "exit"]
    end

    test "clears candidates when typing", %{parser: parser} do
      parser = %{parser | input: "e"}
      parser = Parser.handle_key(parser, "Tab")
      parser = Parser.handle_key(parser, "x")

      assert parser.completion_candidates == []
    end
  end

  describe "history navigation" do
    setup do
      parser =
        Parser.new()
        |> Parser.register_command("echo", fn args -> {:ok, Enum.join(args, " ")} end)

      {:ok, _result, parser} = Parser.parse_and_execute(parser, "echo first")
      {:ok, _result, parser} = Parser.parse_and_execute(parser, "echo second")
      {:ok, _result, parser} = Parser.parse_and_execute(parser, "echo third")

      {:ok, parser: parser}
    end

    test "ArrowUp navigates to previous command", %{parser: parser} do
      parser = Parser.handle_key(parser, "ArrowUp")
      assert parser.input == "echo third"
    end

    test "ArrowUp multiple times navigates history", %{parser: parser} do
      parser = Parser.handle_key(parser, "ArrowUp")
      parser = Parser.handle_key(parser, "ArrowUp")

      assert parser.input == "echo second"
    end

    test "ArrowDown navigates forward in history", %{parser: parser} do
      parser = Parser.handle_key(parser, "ArrowUp")
      parser = Parser.handle_key(parser, "ArrowUp")
      parser = Parser.handle_key(parser, "ArrowDown")

      assert parser.input == "echo third"
    end

    test "ArrowDown at current clears input", %{parser: parser} do
      parser = Parser.handle_key(parser, "ArrowUp")
      parser = Parser.handle_key(parser, "ArrowDown")

      assert parser.input == ""
    end
  end

  describe "history search (Ctrl+R)" do
    setup do
      parser =
        Parser.new()
        |> Parser.register_command("echo", fn args -> {:ok, Enum.join(args, " ")} end)

      {:ok, _result, parser} = Parser.parse_and_execute(parser, "echo hello")
      {:ok, _result, parser} = Parser.parse_and_execute(parser, "echo world")

      {:ok, parser: parser}
    end

    test "Ctrl+R enters search mode" do
      parser = Parser.new()
      parser = Parser.handle_key(parser, "Ctrl+R")

      assert parser.search_mode == true
    end

    test "typing in search mode updates query" do
      parser = Parser.new()
      parser = Parser.handle_key(parser, "Ctrl+R")
      parser = Parser.handle_key(parser, "h")
      parser = Parser.handle_key(parser, "e")

      assert parser.search_query == "he"
    end

    test "Enter exits search and sets input", %{parser: parser} do
      parser = Parser.handle_key(parser, "Ctrl+R")
      parser = Parser.handle_key(parser, "w")
      parser = Parser.handle_key(parser, "o")
      parser = Parser.handle_key(parser, "r")
      parser = Parser.handle_key(parser, "Enter")

      assert parser.search_mode == false
      assert parser.input == "echo world"
    end

    test "Escape exits search mode" do
      parser = Parser.new()
      parser = Parser.handle_key(parser, "Ctrl+R")
      parser = Parser.handle_key(parser, "Escape")

      assert parser.search_mode == false
    end
  end

  describe "accessor functions" do
    test "get_input returns current input" do
      parser = %{Parser.new() | input: "test"}
      assert Parser.get_input(parser) == "test"
    end

    test "get_cursor_pos returns cursor position" do
      parser = %{Parser.new() | cursor_pos: 5}
      assert Parser.get_cursor_pos(parser) == 5
    end

    test "get_completions returns completion candidates" do
      parser = %{Parser.new() | completion_candidates: ["cmd1", "cmd2"]}
      assert Parser.get_completions(parser) == ["cmd1", "cmd2"]
    end

    test "get_history returns command history" do
      parser = %{Parser.new() | history: ["cmd1", "cmd2"]}
      assert Parser.get_history(parser) == ["cmd1", "cmd2"]
    end
  end
end
