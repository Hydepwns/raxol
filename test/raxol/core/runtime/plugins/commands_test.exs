defmodule Raxol.Core.Runtime.Plugins.CommandsTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Plugins.Commands

  # Mock command handler for testing
  defmodule TestCommandHandler do
    def execute(args, context) do
      # Return args and context to verify they were passed correctly
      {:ok, %{args: args, context: context}}
    end

    def execute_error(_args, _context) do
      {:error, "Command execution failed"}
    end

    def execute_crash(_args, _context) do
      raise "Command crashed"
    end
  end

  setup do
    # Start Commands process with clean state for each test
    start_supervised!(Commands)
    :ok
  end

  describe "plugin commands" do
    test "register adds a command to the registry" do
      :ok = Commands.register("test:command", TestCommandHandler, "Test command help")

      commands = Commands.list_commands()
      assert Map.has_key?(commands, "test:command")

      command_info = commands["test:command"]
      assert command_info.handler == TestCommandHandler
      assert command_info.help == "Test command help"
    end

    test "unregister removes a command from the registry" do
      # Register first
      :ok = Commands.register("test:command", TestCommandHandler, "Test command")
      assert Map.has_key?(Commands.list_commands(), "test:command")

      # Then unregister
      :ok = Commands.unregister("test:command")
      refute Map.has_key?(Commands.list_commands(), "test:command")
    end

    test "get_help returns help text for registered command" do
      Commands.register("test:help", TestCommandHandler, "Help text for test command")

      {:ok, help_text} = Commands.get_help("test:help")
      assert help_text == "Help text for test command"
    end

    test "get_help returns error for unknown command" do
      assert {:error, :not_found} = Commands.get_help("unknown:command")
    end

    test "execute calls the command handler with args and context" do
      # Register command
      :ok = Commands.register("test:execute", TestCommandHandler, "Execute test")

      # Execute command
      args = ["arg1", "arg2"]
      context = %{user: "test_user"}

      {:ok, result} = Commands.execute("test:execute", args, context)

      # Verify the args and context were passed correctly
      assert result.args == args
      assert result.context == context
    end

    test "execute returns error for unknown command" do
      assert {:error, :command_not_found} = Commands.execute("unknown:command", [])
    end

    test "execute handles error results from command handler" do
      # Register command that returns an error
      :ok = Commands.register(
        "test:error",
        TestCommandHandler,
        "Error test",
        function: :execute_error
      )

      # Execute should return the error from the handler
      assert {:error, "Command execution failed"} = Commands.execute("test:error", [])
    end

    test "execute safely handles crashes in command handler" do
      # Register command that crashes
      :ok = Commands.register(
        "test:crash",
        TestCommandHandler,
        "Crash test",
        function: :execute_crash
      )

      # Execute should catch the crash and return an error
      assert {:error, message} = Commands.execute("test:crash", [])
      assert String.contains?(message, "Plugin command error")
    end

    test "plugin_command? correctly identifies plugin commands" do
      # Use handle_command as a proxy to test plugin_command?
      assert {:error, :not_plugin_command} = Commands.handle_command("regular_command", [], %{})
      assert {:error, :command_not_found} = Commands.handle_command("plugin:command", [], %{})
    end
  end
end
