defmodule Raxol.Core.Plugins.Core.ClipboardPluginTest do
  # Mox is async-friendly
  use ExUnit.Case, async: true

  alias Raxol.Core.Plugins.Core.ClipboardPlugin
  # Remove alias Raxol.System.Clipboard as we'll use the mock's behaviour
  # alias Raxol.System.Clipboard

  # Define the Mox mock
  Mox.defmock(ClipboardMock, for: Raxol.System.Clipboard.Behaviour)

  # Setup assigns a default state and opts
  setup do
    # Initialize state with the ClipboardMock
    # The ClipboardPlugin.init/1 function takes opts, so we pass it there.
    {:ok, plugin_state} = ClipboardPlugin.init(clipboard_impl: ClipboardMock)
    # Return the plugin's state
    {:ok, state: plugin_state}
  end

  test "terminate/2 returns ok", %{state: state} do
    assert :ok = ClipboardPlugin.terminate(:shutdown, state)
    # No mocking needed for terminate
  end

  test "get_commands/0 returns clipboard commands", %{state: _state} do
    expected_commands = [
      # Updated arity based on previous fixes to how CommandHelper calls handle_command/2
      {:clipboard_write, :handle_command, 1},
      {:clipboard_read, :handle_command, 1}
    ]

    assert ClipboardPlugin.get_commands() == expected_commands
    # No mocking needed for get_commands
  end

  test "handle_command/2 :clipboard_write calls Raxol.System.Clipboard.copy/1",
       %{state: current_state} do
    test_text = "Hello Raxol"

    # Use Mox.expect
    Mox.expect(ClipboardMock, :copy, fn ^test_text ->
      :ok
    end)

    # Call the command handler. Args for write is [test_text]
    assert {:ok, ^current_state, {:ok, :clipboard_write_ok}} =
             ClipboardPlugin.handle_command([test_text], current_state)

    # Verify expectations for this test
    Mox.verify!(ClipboardMock)
  end

  test "handle_command/2 :clipboard_read calls Raxol.System.Clipboard.paste/0 and returns text",
       %{state: current_state} do
    expected_text = "Pasted Text"

    Mox.expect(ClipboardMock, :paste, fn ->
      {:ok, expected_text}
    end)

    # Call the command handler. Args for read is [nil]
    assert {:ok, ^current_state, {:ok, ^expected_text}} =
             ClipboardPlugin.handle_command([nil], current_state)

    Mox.verify!(ClipboardMock)
  end

  test "handle_command/2 :clipboard_read handles Raxol.System.Clipboard.paste/0 error",
       %{state: current_state} do
    error_reason = {:paste_command_failed, "some error"}

    Mox.expect(ClipboardMock, :paste, fn ->
      {:error, error_reason}
    end)

    # Call the command handler. Args for read is [nil]
    assert {:error, {:clipboard_read_failed, ^error_reason}, ^current_state} =
             ClipboardPlugin.handle_command([nil], current_state)

    Mox.verify!(ClipboardMock)
  end

  test "handle_command/2 returns error for unknown command args", %{
    state: current_state
  } do
    # No mocking needed for this path. Call with an unexpected arg structure for the catch-all handle_command/2
    assert {:error, {:unexpected_command_args, [:unknown_cmd_arg]},
            ^current_state} =
             ClipboardPlugin.handle_command([:unknown_cmd_arg], current_state)
  end
end
