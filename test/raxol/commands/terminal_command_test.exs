defmodule Raxol.Commands.TerminalCommandTest do
  @moduledoc """
  Unit tests for terminal commands.
  """

  use ExUnit.Case, async: true

  alias Raxol.Commands.{CreateTerminalCommand, UpdateTerminalCommand}

  describe "CreateTerminalCommand" do
    test "creates valid command with required parameters" do
      attrs = %{
        user_id: "test_user_123",
        width: 80,
        height: 24
      }

      {:ok, command} = CreateTerminalCommand.new(attrs)

      assert command.user_id == "test_user_123"
      assert command.width == 80
      assert command.height == 24
      assert is_binary(command.terminal_id)
      assert is_binary(command.command_id)
      assert is_integer(command.timestamp)
      assert command.working_directory == System.user_home!()
    end

    test "validates dimension constraints" do
      # Width too small
      attrs = %{user_id: "test", width: 10, height: 24}
      assert {:error, _} = CreateTerminalCommand.new(attrs)

      # Width too large
      attrs = %{user_id: "test", width: 400, height: 24}
      assert {:error, _} = CreateTerminalCommand.new(attrs)

      # Height too small
      attrs = %{user_id: "test", width: 80, height: 2}
      assert {:error, _} = CreateTerminalCommand.new(attrs)

      # Height too large
      attrs = %{user_id: "test", width: 80, height: 200}
      assert {:error, _} = CreateTerminalCommand.new(attrs)
    end

    test "requires user_id" do
      attrs = %{width: 80, height: 24}
      assert {:error, _} = CreateTerminalCommand.new(attrs)
    end

    test "accepts optional parameters" do
      attrs = %{
        user_id: "test_user",
        width: 80,
        height: 24,
        title: "My Terminal",
        shell_command: "/bin/zsh",
        theme: "dark"
      }

      {:ok, command} = CreateTerminalCommand.new(attrs)

      assert command.title == "My Terminal"
      assert command.shell_command == "/bin/zsh"
      assert command.theme == "dark"
    end
  end

  describe "UpdateTerminalCommand" do
    test "creates valid update command" do
      attrs = %{
        terminal_id: "term_123",
        user_id: "test_user",
        expected_version: 1,
        width: 100,
        height: 30
      }

      {:ok, command} = UpdateTerminalCommand.new(attrs)

      assert command.terminal_id == "term_123"
      assert command.user_id == "test_user"
      assert command.expected_version == 1
      assert command.width == 100
      assert command.height == 30
    end

    test "validates dimensions if provided" do
      attrs = %{
        terminal_id: "term_123",
        user_id: "test_user",
        expected_version: 1,
        # Too small
        width: 5
      }

      assert {:error, _} = UpdateTerminalCommand.new(attrs)
    end

    test "allows partial updates" do
      attrs = %{
        terminal_id: "term_123",
        user_id: "test_user",
        expected_version: 1,
        # Only updating title
        title: "New Title"
      }

      {:ok, command} = UpdateTerminalCommand.new(attrs)

      assert command.title == "New Title"
      assert command.width == nil
      assert command.height == nil
    end
  end
end
