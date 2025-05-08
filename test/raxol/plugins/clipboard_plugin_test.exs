defmodule Raxol.Plugins.ClipboardPluginTest do
  # Can switch back to async with Mox
  use ExUnit.Case, async: true
  import Mox

  # Remove Mox.defmock - it's configured in config/test.exs
  # Mox.defmock(ClipboardMock, for: Raxol.System.Clipboard.Behaviour)

  alias Raxol.Core.Plugins.Core.ClipboardPlugin

  # Keep Behaviour alias for type hints if desired, but Mox expects the mock module
  alias Raxol.System.Clipboard.Behaviour, as: ClipboardBehaviour

  # Get the configured mock module
  @clipboard_mock Application.compile_env!(:raxol, :mocks)[:ClipboardBehaviour]

  # Setup Mox: Define the mock for ClipboardBehaviour
  setup :verify_on_exit!

  describe "init/1" do
    test "initializes with default state" do
      # Init with default implementation - pass empty list, not map
      assert {:ok, %{clipboard_impl: Raxol.System.Clipboard}} =
               ClipboardPlugin.init([])
    end

    test "initializes with custom implementation" do
      # Init with mock implementation - pass keyword list
      assert {:ok, %{clipboard_impl: @clipboard_mock}} =
               ClipboardPlugin.init(clipboard_impl: @clipboard_mock)
    end
  end

  describe "get_commands/0" do
    test "registers clipboard_write and clipboard_read commands" do
      # No mocking needed for get_commands
      expected_commands = [
        {:clipboard_write, :handle_clipboard_command, 2},
        {:clipboard_read, :handle_clipboard_command, 1}
      ]

      assert ClipboardPlugin.get_commands() == expected_commands
    end
  end

  describe "handle_clipboard_command/1 and /2" do
    # Helper to create initial state with the mock injected
    defp initial_state_with_mock do
      %ClipboardPlugin{clipboard_impl: @clipboard_mock}
    end

    test "delegates :clipboard_write command to System.Clipboard.copy/1 successfully" do
      # Use helper to get state with mock
      initial_state = initial_state_with_mock()
      test_content = "hello clipboard"
      command_name = :clipboard_write
      args = [test_content]

      # Mock the behaviour call using Mox with the configured mock
      expect(@clipboard_mock, :copy, fn ^test_content -> :ok end)

      # Call the plugin's registered handler (arity 2 for write)
      assert {:ok, ^initial_state, :clipboard_write_ok} =
               ClipboardPlugin.handle_clipboard_command(args, initial_state)

      # Verification is handled by setup :verify_on_exit!
    end

    test "delegates :clipboard_write command and handles System.Clipboard.copy/1 error" do
      # Use helper to get state with mock
      initial_state = initial_state_with_mock()
      test_content = "error content"
      command_name = :clipboard_write
      args = [test_content]
      error_reason = {:os_error, "cmd failed"}

      # Mock the behaviour call failure using Mox with the configured mock
      expect(@clipboard_mock, :copy, fn ^test_content ->
        {:error, error_reason}
      end)

      # Call the plugin's registered handler (arity 2 for write)
      assert {:error, {:clipboard_write_failed, ^error_reason}, ^initial_state} =
               ClipboardPlugin.handle_clipboard_command(args, initial_state)

      # Verification handled by :verify_on_exit!
    end

    test "delegates :clipboard_read command to System.Clipboard.paste/0 successfully" do
      # Use helper to get state with mock
      initial_state = initial_state_with_mock()
      clipboard_content = "pasted content"
      command_name = :clipboard_read
      args = []

      # Mock the behaviour call using Mox with the configured mock
      expect(@clipboard_mock, :paste, fn -> {:ok, clipboard_content} end)

      # Call the plugin's registered handler (arity 1 for read)
      assert {:ok, ^initial_state, {:clipboard_content, ^clipboard_content}} =
               ClipboardPlugin.handle_clipboard_command(initial_state)

      # Verification handled by :verify_on_exit!
    end

    test "delegates :clipboard_read command and handles System.Clipboard.paste/0 error" do
      # Use helper to get state with mock
      initial_state = initial_state_with_mock()
      command_name = :clipboard_read
      args = []
      error_reason = :command_not_found

      # Mock the behaviour call failure using Mox with the configured mock
      expect(@clipboard_mock, :paste, fn -> {:error, error_reason} end)

      # Call the plugin's command handler with the mock-injected state
      assert {:error, {:clipboard_read_failed, ^error_reason}, ^initial_state} =
               ClipboardPlugin.handle_command(command_name, args, initial_state)

      # Verification handled by :verify_on_exit!
    end

    test "returns error for unhandled command variants" do
      # Use helper to get state with mock (although mock isn't called)
      initial_state = initial_state_with_mock()
      # Test calling write handler (arity 2) with wrong args
      # Wrong args for write
      assert {:error, :unhandled_clipboard_command, ^initial_state} =
               ClipboardPlugin.handle_clipboard_command([], initial_state)

      # Test calling read handler (arity 1) with wrong args (impossible? it takes only state)
      # This test case might be invalid now.
      # Let's just test calling the write handler with wrong arity again
      assert {:error, :unhandled_clipboard_command, ^initial_state} =
               ClipboardPlugin.handle_clipboard_command(
                 ["unexpected"],
                 initial_state
               )
    end
  end

  # Basic check for terminate callback existence
  describe "terminate/2" do
    test "terminate/2 exists and returns :ok" do
      # Use helper for state
      initial_state = initial_state_with_mock()
      assert ClipboardPlugin.terminate(:shutdown, initial_state) == :ok
    end
  end

  # Basic check for optional callbacks existence
  describe "optional callbacks" do
    # Use helper for state in these tests too
    defp initial_state_with_mock do
      %ClipboardPlugin{clipboard_impl: @clipboard_mock}
    end

    test "enable/1 exists" do
      initial_state = initial_state_with_mock()
      assert {:ok, ^initial_state} = ClipboardPlugin.enable(initial_state)
    end

    test "disable/1 exists" do
      initial_state = initial_state_with_mock()
      assert {:ok, ^initial_state} = ClipboardPlugin.disable(initial_state)
    end

    test "filter_event/2 exists" do
      initial_state = initial_state_with_mock()
      event = %{type: :test}

      assert {:ok, ^event, ^initial_state} =
               ClipboardPlugin.filter_event(event, initial_state)
    end
  end
end
