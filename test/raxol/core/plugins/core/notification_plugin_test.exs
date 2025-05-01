defmodule Raxol.Core.Plugins.Core.NotificationPluginTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Plugins.Core.NotificationPlugin

  # Setup assigns a default state
  setup do
    # Use :meck for mocking system functions
    # Mock :os.type/0, System.cmd/3, System.find_executable/1
    :meck.new(:os, [:passthrough])
    :meck.new(System, [:passthrough, :cmd, :find_executable, :shell_escape])

    state = %{}

    # Ensure meck is unloaded AFTER the test runs
    on_exit(fn ->
      :meck.unload(System)
      :meck.unload(:os)
    end)

    {:ok, state: state}
  end

  test "get_commands/0 returns notify command", %{state: _state} do
    expected_commands = [{:notify, :handle_command, 1}]
    assert NotificationPlugin.get_commands() == expected_commands
  end

  # --- Linux Tests ---
  test "handle_command :notify calls notify-send on Linux (Success)", %{state: current_state} do
    title = "Linux Test"
    message = "Notification works!"
    escaped_title = System.shell_escape(title)
    escaped_message = System.shell_escape(message)
    input_data = %{title: title, message: message}

    :meck.expect(:os, :type, fn -> {:unix, :linux} end)
    :meck.expect(System, :find_executable, fn ("notify-send") -> "/usr/bin/notify-send" end)
    # Mock System.cmd for notify-send success
    :meck.expect(System, :cmd, fn "/usr/bin/notify-send", [^escaped_title, ^escaped_message], _opts -> {"", 0} end)

    assert {:ok, ^current_state, :notification_sent_linux} =
      NotificationPlugin.handle_command(:notify, [input_data], current_state)
    assert :meck.validate(:os)
    assert :meck.validate(System)
  end

  test "handle_command :notify handles notify-send not found on Linux", %{state: current_state} do
    input_data = %{message: "test"}
    :meck.expect(:os, :type, fn -> {:unix, :linux} end)
    :meck.expect(System, :find_executable, fn ("notify-send") -> nil end)

    assert {:error, {:command_not_found, :notify_send}, ^current_state} =
      NotificationPlugin.handle_command(:notify, [input_data], current_state)
    assert :meck.validate(:os)
    assert :meck.validate(System)
  end

  test "handle_command :notify handles notify-send command failure on Linux", %{state: current_state} do
    input_data = %{message: "test"}
    escaped_message = System.shell_escape("test")
    escaped_title = System.shell_escape("Raxol Notification")

    :meck.expect(:os, :type, fn -> {:unix, :linux} end)
    :meck.expect(System, :find_executable, fn ("notify-send") -> "/bin/notify-send" end)
    :meck.expect(System, :cmd, fn "/bin/notify-send", [^escaped_title, ^escaped_message], _opts -> {"Error output", 1} end)

    assert {:error, {:command_failed, 1, "Error output"}, ^current_state} =
      NotificationPlugin.handle_command(:notify, [input_data], current_state)
    assert :meck.validate(System)
  end

  # --- macOS Tests ---
  test "handle_command :notify calls osascript on macOS (Success)", %{state: current_state} do
    title = "macOS Test"
    message = "It works!"
    escaped_message = System.shell_escape(message)
    escaped_title = System.shell_escape(title)
    expected_script = "display notification #{escaped_message} with title #{escaped_title}"
    input_data = %{title: title, message: message}

    :meck.expect(:os, :type, fn -> {:unix, :darwin} end)
    :meck.expect(System, :find_executable, fn ("osascript") -> "/usr/bin/osascript" end)
    :meck.expect(System, :cmd, fn "/usr/bin/osascript", ["-e", ^expected_script], _opts -> {"", 0} end)

    assert {:ok, ^current_state, :notification_sent_macos} =
      NotificationPlugin.handle_command(:notify, [input_data], current_state)
    assert :meck.validate(System)
  end

  test "handle_command :notify handles osascript not found on macOS", %{state: current_state} do
      input_data = %{message: "test"}
      :meck.expect(:os, :type, fn -> {:unix, :darwin} end)
      :meck.expect(System, :find_executable, fn ("osascript") -> nil end)

      assert {:error, {:command_not_found, :osascript}, ^current_state} =
        NotificationPlugin.handle_command(:notify, [input_data], current_state)
      assert :meck.validate(System)
    end

  # --- Windows Tests ---
  test "handle_command :notify calls PowerShell on Windows (Success)", %{state: current_state} do
    title = "Windows Test"
    message = "Works here too"
    # Escaping is handled internally by System.cmd for args, but script needs raw message
    expected_script = ~s(Import-Module BurntToast; New-BurntToastNotification -Text "#{message}")
    input_data = %{title: title, message: message} # Title is currently ignored for BurntToast command

    :meck.expect(:os, :type, fn -> {:win32, :nt} end)
    :meck.expect(System, :find_executable, fn ("powershell") -> "C:\Windows\System32\...\powershell.exe" end)
    :meck.expect(System, :cmd, fn "C:\Windows\System32\...\powershell.exe", ["-NoProfile", "-Command", ^expected_script], _opts -> {"", 0} end)

    assert {:ok, ^current_state, :notification_sent_windows} =
      NotificationPlugin.handle_command(:notify, [input_data], current_state)
    assert :meck.validate(System)
  end

  test "handle_command :notify handles powershell not found on Windows", %{state: current_state} do
      input_data = %{message: "test"}
      :meck.expect(:os, :type, fn -> {:win32, :nt} end)
      :meck.expect(System, :find_executable, fn ("powershell") -> nil end)

      assert {:error, {:command_not_found, :powershell}, ^current_state} =
        NotificationPlugin.handle_command(:notify, [input_data], current_state)
      assert :meck.validate(System)
  end

  # --- Generic Tests ---
  test "handle_command :notify handles unsupported OS", %{state: current_state} do
    input_data = %{message: "test"}
    unsupported_os = {:unix, :solaris}

    :meck.expect(:os, :type, fn -> unsupported_os end)

    assert {:ok, ^current_state, :notification_skipped_unsupported_os} =
      NotificationPlugin.handle_command(:notify, [input_data], current_state)
    assert :meck.validate(:os)
  end

  test "handle_command :notify handles command execution exception", %{state: current_state} do
    input_data = %{message: "boom"}
    error = RuntimeError.exception("Command failed unexpectedly")

    :meck.expect(:os, :type, fn -> {:unix, :linux} end)
    :meck.expect(System, :find_executable, fn ("notify-send") -> "/bin/notify-send" end)
    # Mock System.cmd to raise an exception
    :meck.expect(System, :cmd, fn _cmd, _args, _opts -> raise error end)

    assert {:error, {:command_exception, "Elixir.RuntimeError", "Command failed unexpectedly"}, ^current_state} =
      NotificationPlugin.handle_command(:notify, [input_data], current_state)
    assert :meck.validate(System)
  end

  test "handle_command returns error for unknown command", %{state: current_state} do
    assert {:error, {:unhandled_notification_command, :unknown}, ^current_state} =
      NotificationPlugin.handle_command(:unknown, [], current_state)
  end

  test "handle_command :notify returns error for invalid input type", %{state: current_state} do
    assert {:error, {:unhandled_notification_command, :notify}, ^current_state} =
      NotificationPlugin.handle_command(:notify, ["not a map"], current_state)
  end

end
