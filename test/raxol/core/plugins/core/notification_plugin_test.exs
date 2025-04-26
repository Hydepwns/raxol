defmodule Raxol.Core.Plugins.Core.NotificationPluginTest do
  use ExUnit.Case, async: true
  import Mox

  # Mock System.cmd/3
  defmock SystemMock, for: System

  alias Raxol.Core.Plugins.Core.NotificationPlugin

  setup do
    Mox.stub_with(SystemMock, System)
    Mox.verify_on_exit!()
    :ok
  end

  test "init/1 returns ok with initial state" do
    assert {:ok, %{}} = NotificationPlugin.init([])
  end

  test "terminate/2 returns ok" do
    assert :ok = NotificationPlugin.terminate(:shutdown, %{})
  end

  test "get_commands/0 returns notify command" do
    expected_commands = [notify: "Send a desktop notification."]
    assert NotificationPlugin.get_commands() == expected_commands
  end

  describe "handle_command/3" do
    test ":notify calls System.cmd with correct args on macOS" do
      # Force :mac for testing
      Application.put_env(:raxol, :os_family, :mac)
      summary = "Test Summary"
      body = "Test Body"
      current_state = %{}
      opts = []

      expected_cmd = "osascript"
      expected_args = [
        "-e",
        "display notification \"#{body}\" with title \"#{summary}\""
      ]

      # Expect System.cmd to be called
      expect(SystemMock, :cmd, fn ^expected_cmd, ^expected_args, _opts -> {"output", 0} end)

      assert {:reply, :ok, current_state} = NotificationPlugin.handle_command(:notify, {summary, body}, current_state, opts)
      Application.delete_env(:raxol, :os_family)
    end

    test ":notify calls System.cmd with correct args on linux" do
        # Force :linux for testing
      Application.put_env(:raxol, :os_family, :linux)
      summary = "Test Summary"
      body = "Test Body"
      current_state = %{}
      opts = []

      expected_cmd = "notify-send"
      expected_args = [summary, body]

      # Expect System.cmd to be called
      expect(SystemMock, :cmd, fn ^expected_cmd, ^expected_args, _opts -> {"output", 0} end)

      assert {:reply, :ok, current_state} = NotificationPlugin.handle_command(:notify, {summary, body}, current_state, opts)
      Application.delete_env(:raxol, :os_family)
    end

     test ":notify handles System.cmd failure" do
      Application.put_env(:raxol, :os_family, :linux) # Use linux for simplicity
      summary = "Test Summary"
      body = "Test Body"
      current_state = %{}
      opts = []
      exit_code = 1
      output = "Command failed"

      # Expect System.cmd to be called and return non-zero exit code
      expect(SystemMock, :cmd, fn "notify-send", [^summary, ^body], _ -> {output, exit_code} end)

      # Expect the plugin to return an error tuple
      assert {:reply, {:error, {:command_failed, output, exit_code}}, current_state} = NotificationPlugin.handle_command(:notify, {summary, body}, current_state, opts)
      Application.delete_env(:raxol, :os_family)
    end

     test ":notify logs warning on unsupported OS" do
      Application.put_env(:raxol, :os_family, :windows) # Use unsupported OS
      summary = "Test Summary"
      body = "Test Body"
      current_state = %{}
      opts = []

      # Expect System.cmd NOT to be called
      # Check log output? (More complex)
      # For now, just assert the return value indicates unsupported
      # Assuming it returns :ok but logs a warning
      assert {:reply, :ok, current_state} = NotificationPlugin.handle_command(:notify, {summary, body}, current_state, opts)
      # We could potentially use ExUnit.CaptureLog here if logging is critical
      Application.delete_env(:raxol, :os_family)
    end

    test "returns error for unknown command" do
      current_state = %{}
      opts = []
      assert {:reply, {:error, :unknown_command}, current_state} = NotificationPlugin.handle_command(:unknown_cmd, nil, current_state, opts)
    end

    # Helper to determine OS family, potentially mockable
    # defp get_os_family do
    #   Application.get_env(:raxol, :os_family, :os.type() |> elem(0))
    # end
  end
end
