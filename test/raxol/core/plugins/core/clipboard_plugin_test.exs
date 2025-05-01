defmodule Raxol.Core.Plugins.Core.ClipboardPluginTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Plugins.Core.ClipboardPlugin
  alias Raxol.System.Clipboard # Alias the module we now need to mock

  # Setup assigns a default state and opts
  setup do
    # Mock Raxol.System.Clipboard functions using :meck
    # Remove :passthrough as we are providing explicit mocks/expectations
    :meck.new(Clipboard, [:copy, :paste])

    state = %{}

    # Ensure meck is unloaded AFTER the test runs
    on_exit(fn -> :meck.unload(Clipboard) end)

    {:ok, state: state}
  end

  # Ensure :meck is unloaded after each test
  # It's often better to put this in setup_all/on_exit for the module
  # if :meck is used across multiple tests in the file.
  # For simplicity here, we'll assume it's okay per test, but
  # a module-level on_exit is generally preferred.
  # on_exit fn -> :meck.unload(Clipboard) end

  test "terminate/2 returns ok", %{state: state} do
    assert :ok = ClipboardPlugin.terminate(:shutdown, state)
    # No mocking needed for terminate
  end

  test "get_commands/0 returns clipboard commands", %{state: _state} do
    expected_commands = [
      {:clipboard_write, :handle_clipboard_command, 2},
      {:clipboard_read, :handle_clipboard_command, 1}
    ]
    assert ClipboardPlugin.get_commands() == expected_commands
    # No mocking needed for get_commands
  end

  test "handle_command/3 :clipboard_write calls Raxol.System.Clipboard.copy/1", %{state: current_state} do
    test_text = "Hello Raxol"

    # Use :meck.expect to mock Raxol.System.Clipboard.copy/1
    :meck.expect(Clipboard, :copy, fn ^test_text ->
      :ok
    end)

    # Call the command handler
    assert {:ok, ^current_state, :clipboard_write_ok} = ClipboardPlugin.handle_command(:clipboard_write, [test_text], current_state)

    # Verify the mock was called
    assert :meck.validate(Clipboard)
  end

  test "handle_command/3 :clipboard_read calls Raxol.System.Clipboard.paste/0 and returns text", %{state: current_state} do
    expected_text = "Pasted Text"

    # Use :meck.expect to mock Raxol.System.Clipboard.paste/0
    :meck.expect(Clipboard, :paste, fn ->
      {:ok, expected_text}
    end)

    # Call the command handler
    assert {:ok, ^current_state, {:clipboard_content, ^expected_text}} = ClipboardPlugin.handle_command(:clipboard_read, [], current_state)

    assert :meck.validate(Clipboard)
  end

  test "handle_command/3 :clipboard_read handles Raxol.System.Clipboard.paste/0 error", %{state: current_state} do
    error_reason = {:paste_command_failed, "some error"}

    # Use :meck.expect to mock Raxol.System.Clipboard.paste/0 error
    :meck.expect(Clipboard, :paste, fn ->
      {:error, error_reason}
    end)

    # Call the command handler
    assert {:error, {:clipboard_read_failed, ^error_reason}, ^current_state} = ClipboardPlugin.handle_command(:clipboard_read, [], current_state)

    assert :meck.validate(Clipboard)
  end

  test "handle_command/3 returns error for unknown command", %{state: current_state} do
    # No mocking needed for this path
    assert {:error, :unhandled_clipboard_command, ^current_state} = ClipboardPlugin.handle_command(:unknown_cmd, [], current_state)
    # Ensure :meck.unload is still called via on_exit even if no validation is needed
  end
end
