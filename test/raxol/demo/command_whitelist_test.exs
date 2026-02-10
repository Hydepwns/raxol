defmodule Raxol.Demo.CommandWhitelistTest do
  use ExUnit.Case, async: true

  alias Raxol.Demo.CommandWhitelist

  describe "execute/1" do
    test "help command returns available commands" do
      assert {:ok, output} = CommandWhitelist.execute("help")
      assert output =~ "Available Commands"
      assert output =~ "demo colors"
      assert output =~ "demo components"
    end

    test "demo colors returns color palette" do
      assert {:ok, output} = CommandWhitelist.execute("demo colors")
      assert output =~ "ANSI Color Palette"
    end

    test "demo components returns component gallery" do
      assert {:ok, output} = CommandWhitelist.execute("demo components")
      assert output =~ "UI Component Gallery"
    end

    test "demo animation returns animation showcase" do
      assert {:ok, output} = CommandWhitelist.execute("demo animation")
      assert output =~ "Animation Capabilities"
    end

    test "demo emulation returns terminal emulation info" do
      assert {:ok, output} = CommandWhitelist.execute("demo emulation")
      assert output =~ "Terminal Emulation"
      assert output =~ "VT100"
    end

    test "demo without subcommand returns usage error" do
      assert {:error, message} = CommandWhitelist.execute("demo")
      assert message =~ "Usage: demo"
    end

    test "demo with unknown subcommand returns error" do
      assert {:error, message} = CommandWhitelist.execute("demo unknown")
      assert message =~ "Unknown demo"
    end

    test "theme command with valid name returns theme sequence" do
      assert {:ok, output} = CommandWhitelist.execute("theme dracula")
      assert output =~ "Theme set to Dracula"
    end

    test "theme command with invalid name returns error" do
      assert {:error, message} = CommandWhitelist.execute("theme invalid")
      assert message =~ "Unknown theme"
    end

    test "theme command without name returns usage error" do
      assert {:error, message} = CommandWhitelist.execute("theme")
      assert message =~ "Usage: theme"
    end

    test "clear command returns clear screen sequence" do
      assert {:ok, "\e[2J\e[H"} = CommandWhitelist.execute("clear")
    end

    test "exit command returns exit tuple" do
      assert {:exit, message} = CommandWhitelist.execute("exit")
      assert message =~ "Goodbye"
    end

    test "unknown command returns error" do
      assert {:error, message} = CommandWhitelist.execute("unknown")
      assert message =~ "Unknown command"
      assert message =~ "help"
    end

    test "empty input returns empty output" do
      assert {:ok, ""} = CommandWhitelist.execute("")
      assert {:ok, ""} = CommandWhitelist.execute("   ")
    end

    test "commands are case insensitive" do
      assert {:ok, _} = CommandWhitelist.execute("HELP")
      assert {:ok, _} = CommandWhitelist.execute("Help")
      assert {:ok, _} = CommandWhitelist.execute("DEMO colors")
    end

    test "rejects oversized input" do
      large_input = String.duplicate("a", 1025)
      assert {:error, message} = CommandWhitelist.execute(large_input)
      assert message =~ "Input too large"
    end

    test "shell injection attempts are rejected" do
      assert {:error, _} = CommandWhitelist.execute("; cat /etc/passwd")
      assert {:error, _} = CommandWhitelist.execute("demo; rm -rf /")
      assert {:error, _} = CommandWhitelist.execute("$(whoami)")
      assert {:error, _} = CommandWhitelist.execute("`id`")
      assert {:error, _} = CommandWhitelist.execute("| ls")
    end
  end

  describe "available_commands/0" do
    test "returns list of command tuples" do
      commands = CommandWhitelist.available_commands()

      assert is_list(commands)
      assert length(commands) > 0

      Enum.each(commands, fn {name, description} ->
        assert is_binary(name)
        assert is_binary(description)
      end)
    end

    test "includes core commands" do
      commands = CommandWhitelist.available_commands() |> Map.new()

      assert Map.has_key?(commands, "help")
      assert Map.has_key?(commands, "clear")
      assert Map.has_key?(commands, "exit")
    end
  end
end
