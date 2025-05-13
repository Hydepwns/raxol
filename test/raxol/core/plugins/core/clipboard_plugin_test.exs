defmodule Raxol.Core.Plugins.Core.ClipboardPluginTest do
  # Mox is async-friendly
  use ExUnit.Case
  import Mox
  import Raxol.Test.ClipboardHelpers

  alias Raxol.Core.Plugins.Core.ClipboardPlugin
  # Remove alias Raxol.System.Clipboard as we'll use the mock's behaviour
  # alias Raxol.System.Clipboard

  # Setup assigns a default state and opts
  setup do
    # Initialize state with the ClipboardMock
    # The ClipboardPlugin.init/1 function takes opts, so we pass it there.
    {:ok, plugin_state} = ClipboardPlugin.init(clipboard_impl: ClipboardMock)
    # Return the plugin's state
    {:ok, state: plugin_state}
  end

  setup :verify_on_exit!

  # Mox.defmock(SystemInteractionMock, for: Raxol.System.Interaction)

  # Configure Mox for this test module

  test "terminate/2 returns ok", %{state: state} do
    assert :ok = ClipboardPlugin.terminate(:shutdown, state)
    # No mocking needed for terminate
  end

  test "get_commands/0 returns clipboard commands", %{state: _state} do
    expected_commands = [
      {:clipboard_write, :handle_command, 1},
      {:clipboard_read, :handle_command, 0}
    ]

    assert ClipboardPlugin.get_commands() == expected_commands
    # No mocking needed for get_commands
  end

  test "handle_command/3 :clipboard_write calls Raxol.System.Clipboard.copy/1",
       %{state: current_state} do
    test_text = "Hello Raxol"

    # Use Mox.expect
    expect_clipboard_copy(ClipboardMock, test_text, :ok)

    # Call the command handler. Args for write is [test_text]
    assert {:ok, ^current_state, {:ok, :clipboard_write_ok}} =
             ClipboardPlugin.handle_command(
               :clipboard_write,
               [test_text],
               current_state
             )

    # Verify expectations for this test
    Mox.verify!(ClipboardMock)
  end

  test "handle_command/3 :clipboard_read calls Raxol.System.Clipboard.paste/0 and returns text",
       %{state: current_state} do
    expected_text = "Pasted Text"

    expect_clipboard_paste(ClipboardMock, {:ok, expected_text})

    # Call the command handler. Args for read is [nil]
    assert {:ok, ^current_state, {:ok, ^expected_text}} =
             ClipboardPlugin.handle_command(:clipboard_read, [], current_state)

    Mox.verify!(ClipboardMock)
  end

  test "handle_command/3 :clipboard_read handles Raxol.System.Clipboard.paste/0 error",
       %{state: current_state} do
    error_reason = {:paste_command_failed, "some error"}

    expect_clipboard_paste(ClipboardMock, {:error, error_reason})

    # Call the command handler. Args for read is [nil]
    assert {:error, {:clipboard_read_failed, ^error_reason}, ^current_state} =
             ClipboardPlugin.handle_command(:clipboard_read, [], current_state)

    Mox.verify!(ClipboardMock)
  end

  test "handle_command/3 returns error for unknown command args", %{
    state: current_state
  } do
    # No mocking needed for this path. Call with an unexpected arg structure for the catch-all handle_command/2
    assert {:error, {:unknown_plugin_command, :unknown_cmd, [:unknown_cmd_arg]},
            ^current_state} =
             ClipboardPlugin.handle_command(
               :unknown_cmd,
               [:unknown_cmd_arg],
               current_state
             )
  end
end
