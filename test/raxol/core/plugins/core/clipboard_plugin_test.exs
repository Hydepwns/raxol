defmodule Raxol.Core.Plugins.Core.ClipboardPluginTest do
  use ExUnit.Case, async: true
  import Mox

  # Define a behavior for ClipboardAPI
  defmodule ClipboardAPI do
    @callback get() :: String.t()
    @callback put(String.t()) :: :ok
  end

  # Mock ClipboardAPI instead of Clipboard
  defmock ClipboardAPIMock, for: ClipboardAPI

  alias Raxol.Core.Plugins.Core.ClipboardPlugin

  setup do
    # Stub ClipboardAPIMock to behave like Clipboard
    Mox.stub(ClipboardAPIMock, :get, fn -> "default clipboard content" end)
    Mox.stub(ClipboardAPIMock, :put, fn _text -> :ok end)
    Mox.verify_on_exit!()

    # Use a module that can access ClipboardAPIMock
    original_clipboard = ClipboardPlugin.clipboard_module()
    :meck.new(ClipboardPlugin, [:passthrough])
    :meck.expect(ClipboardPlugin, :clipboard_module, fn -> ClipboardAPIMock end)

    on_exit(fn ->
      :meck.unload(ClipboardPlugin)
    end)

    :ok
  end

  test "init/1 returns ok with initial state" do
    assert {:ok, %{}} = ClipboardPlugin.init([])
  end

  test "terminate/2 returns ok" do
    assert :ok = ClipboardPlugin.terminate(:shutdown, %{})
  end

  test "get_commands/0 returns clipboard commands" do
    expected_commands = [
      clipboard_write: "Write text to the system clipboard.",
      clipboard_read: "Read text from the system clipboard."
    ]
    assert ClipboardPlugin.get_commands() == expected_commands
  end

  describe "handle_command/3" do
    test ":clipboard_write calls Clipboard.put/1" do
      test_text = "hello clipboard"
      current_state = %{}
      opts = [] # Assuming opts are not used by this command handler

      # Expect Clipboard.put/1 to be called with the text
      expect(ClipboardAPIMock, :put, fn ^test_text -> :ok end)

      # Call the command handler
      assert {:reply, :ok, current_state} = ClipboardPlugin.handle_command(:clipboard_write, test_text, current_state, opts)
    end

    test ":clipboard_read calls Clipboard.get/0 and returns text" do
      expected_text = "text from clipboard"
      current_state = %{}
      opts = [] # Assuming opts are not used by this command handler

      # Expect Clipboard.get/0 to be called and return the text
      expect(ClipboardAPIMock, :get, fn -> expected_text end)

      # Call the command handler
      assert {:reply, {:ok, expected_text}, current_state} = ClipboardPlugin.handle_command(:clipboard_read, nil, current_state, opts)
    end

    test ":clipboard_read handles Clipboard.get/0 error" do
      error_reason = :clipboard_unavailable
      current_state = %{}
      opts = []

      # Expect Clipboard.get/0 to be called and return an error
      # Assuming the library might raise or return {:error, reason} - let's assume it raises for now
      # Mox can expect raises
      expect(ClipboardAPIMock, :get, fn -> raise error_reason end)

      # Call the command handler and assert it catches the error and returns appropriately
      assert {:reply, {:error, error_reason}, current_state} = ClipboardPlugin.handle_command(:clipboard_read, nil, current_state, opts)
    end

     test "returns error for unknown command" do
      current_state = %{}
      opts = []
      assert {:reply, {:error, :unknown_command}, current_state} = ClipboardPlugin.handle_command(:unknown_cmd, nil, current_state, opts)
    end
  end
end
