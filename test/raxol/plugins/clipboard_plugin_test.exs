defmodule Raxol.Plugins.ClipboardPluginTest do
  use ExUnit.Case, async: true
  import Mox

  alias Raxol.Core.Plugins.Core.ClipboardPlugin

  # Use Mox for mocking the clipboard behaviour
  @clipboard_mock Raxol.Core.ClipboardMock

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
    test "returns clipboard commands" do
      commands = ClipboardPlugin.get_commands()

      assert {:clipboard_write, :handle_clipboard_command, 2} in commands
      assert {:clipboard_read, :handle_clipboard_command, 1} in commands
    end
  end

  describe "handle_command/3" do
    test "delegates :clipboard_write command to clipboard implementation successfully" do
      test_content = "test content"
      initial_state = initial_state_with_mock()
      @clipboard_mock |> expect(:copy, fn ^test_content -> :ok end)

      assert ClipboardPlugin.handle_command(
               :clipboard_write,
               [test_content],
               initial_state
             ) == {:ok, "Content copied to clipboard"}
    end

    test "delegates :clipboard_write command and handles System.Clipboard.copy/1 error" do
      test_content = "error content"
      initial_state = initial_state_with_mock()

      @clipboard_mock
      |> expect(:copy, fn ^test_content ->
        {:error, {:os_error, "cmd failed"}}
      end)

      assert ClipboardPlugin.handle_command(
               :clipboard_write,
               [test_content],
               initial_state
             ) ==
               {:error,
                "Failed to write to clipboard: {:os_error, \"cmd failed\"}"}
    end

    test "delegates :clipboard_read command to System.Clipboard.paste/0 successfully" do
      initial_state = initial_state_with_mock()

      @clipboard_mock
      |> expect(:paste, fn -> {:ok, "mock clipboard content"} end)

      assert ClipboardPlugin.handle_command(:clipboard_read, [], initial_state) ==
               {:ok, "mock clipboard content"}
    end

    test "delegates :clipboard_read command and handles System.Clipboard.paste/0 error" do
      initial_state = initial_state_with_mock()
      @clipboard_mock |> expect(:paste, fn -> {:error, :command_not_found} end)

      assert ClipboardPlugin.handle_command(:clipboard_read, [], initial_state) ==
               {:error, "Failed to read from clipboard: :command_not_found"}
    end
  end

  describe "handle_clipboard_command/1 and /2" do
    test "delegates :clipboard_write command and handles System.Clipboard.copy/1 error" do
      test_content = "error content"
      initial_state = initial_state_with_mock()

      @clipboard_mock
      |> expect(:copy, fn ^test_content ->
        {:error, {:os_error, "cmd failed"}}
      end)

      assert ClipboardPlugin.handle_clipboard_command(
               [test_content],
               initial_state
             ) ==
               {:error,
                "Failed to write to clipboard: {:os_error, \"cmd failed\"}"}
    end

    test "delegates :clipboard_read command to System.Clipboard.paste/0 successfully" do
      initial_state = initial_state_with_mock()

      @clipboard_mock
      |> expect(:paste, fn -> {:ok, "mock clipboard content"} end)

      assert ClipboardPlugin.handle_clipboard_command(initial_state) ==
               {:ok, "mock clipboard content"}
    end

    test "delegates :clipboard_read command and handles System.Clipboard.paste/0 error" do
      initial_state = initial_state_with_mock()
      @clipboard_mock |> expect(:paste, fn -> {:error, :command_not_found} end)

      assert ClipboardPlugin.handle_clipboard_command(initial_state) ==
               {:error, "Failed to read from clipboard: :command_not_found"}
    end
  end

  # Helper to create initial state with the mock injected
  defp initial_state_with_mock do
    %{clipboard_impl: @clipboard_mock}
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
      %{clipboard_impl: @clipboard_mock}
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
