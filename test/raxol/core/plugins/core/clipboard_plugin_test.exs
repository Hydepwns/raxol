defmodule Raxol.Core.Plugins.Core.ClipboardPluginTest do
  @moduledoc """
  Tests for the clipboard plugin, including initialization, termination,
  command handling, and clipboard operations.
  """
  use ExUnit.Case, async: true
  import Mox
  import Raxol.Test.Support.ClipboardHelpers
  import Raxol.Test.ClipboardAssertions

  alias Raxol.Core.Plugins.Core.ClipboardPlugin
  alias Raxol.Terminal.ClipboardMock

  setup :verify_on_exit!

  setup context do
    # Set up the default state with our mock
    # Set up the default state with our mock
    {:ok, state} = ClipboardPlugin.init(clipboard_impl: ClipboardMock)
    %{context | state: state}
  end

  describe "terminate/2" do
    test "returns :ok", %{state: state} do
      assert :ok = ClipboardPlugin.terminate(:normal, state)
    end
  end

  describe "get_commands/0" do
    test "returns the expected clipboard commands" do
      commands = ClipboardPlugin.get_commands()
      assert :clipboard_write in commands
      assert :clipboard_read in commands
    end
  end

  describe "handle_command/3" do
    test "clipboard_write copies content to clipboard", %{state: state} do
      content = "test content"
      expect_clipboard_copy(ClipboardMock, content, :ok)

      assert {:ok, "Content copied to clipboard"} =
               ClipboardPlugin.handle_command(
                 :clipboard_write,
                 [content],
                 state
               )
    end

    test "clipboard_read retrieves content from clipboard", %{state: state} do
      content = "test content"
      expect_clipboard_paste(ClipboardMock, {:ok, content})

      assert {:ok, content} =
               ClipboardPlugin.handle_command(:clipboard_read, [], state)
    end

    test "clipboard_read handles errors", %{state: state} do
      expect_clipboard_paste_error()

      assert {:error, "Failed to read from clipboard: :error"} =
               ClipboardPlugin.handle_command(:clipboard_read, [], state)
    end

    test "handles unknown command arguments", %{state: state} do
      assert {:error, "Invalid arguments for clipboard_write command"} =
               ClipboardPlugin.handle_command(
                 :clipboard_write,
                 ["not", "binary"],
                 state
               )

      assert {:error, "Invalid arguments for clipboard_read command"} =
               ClipboardPlugin.handle_command(:clipboard_read, ["extra"], state)
    end
  end
end
