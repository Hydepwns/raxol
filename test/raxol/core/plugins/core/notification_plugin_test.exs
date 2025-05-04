defmodule Raxol.Core.Plugins.Core.NotificationPluginTest do
  use ExUnit.Case, async: false

  # Import Mox for defining mocks and expectations
  import Mox

  # Define the mock based on the System.Interaction behaviour
  Mox.defmock(SystemInteractionMock, for: Raxol.System.Interaction)

  alias Raxol.Core.Plugins.Core.NotificationPlugin

  # --- Helper Setup ---
  # Ensure mocks are verified on exit
  setup :verify_on_exit!

  # Setup state and stub the interaction module for the plugin
  setup do
    # Configure the application environment for tests to use the mock
    # This ensures init/1 would get the mock if called by the plugin manager
    Application.put_env(:raxol, :system_interaction_module, SystemInteractionMock)

    # Since we call handle_command directly, put the mock in the test context state
    initial_state = %{interaction_module: SystemInteractionMock}

    {:ok, state: initial_state}
  after
    # Reset the application environment after the test
    Application.delete_env(:raxol, :system_interaction_module)
  end

  # --- Tests (Now Enabled) ---

  @tag :notification
  test "get_commands/0 returns notify command" do
    # Check the command signature defined by the plugin
    assert [{:notify, :handle_command, 1}] = NotificationPlugin.get_commands()
  end

  @tag :notification
  test "handle_command :notify calls notify-send on Linux (Success)", %{state: current_state} do
    title = "Linux Test"
    message = "This is a Linux notification!"
    input_data = %{title: title, message: message}

    # Expectations on the mock module
    expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
    expect(SystemInteractionMock, :find_executable, fn "notify-send" -> "/usr/bin/notify-send" end)
    expect(SystemInteractionMock, :system_cmd, fn "/usr/bin/notify-send",
                                                 [^title, ^message],
                                                 opts ->
                                               # Ensure options are passed correctly
                                               assert opts == [stderr_to_stdout: true]
                                               # Simulate successful command execution
                                               {"", 0}
                                           end)

    # Assert the expected successful result
    assert {:ok, current_state, :notification_sent_linux} =
             NotificationPlugin.handle_command(:notify, [input_data], current_state)
  end

  @tag :notification
  test "handle_command :notify handles notify-send not found on Linux", %{state: current_state} do
    input_data = %{message: "test"}

    expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
    expect(SystemInteractionMock, :find_executable, fn "notify-send" -> nil end)

    # Assert the command_not_found error
    assert {:error, {:command_not_found, :notify_send}, current_state} =
             NotificationPlugin.handle_command(:notify, [input_data], current_state)
  end

  @tag :notification
  test "handle_command :notify handles notify-send command failure on Linux", %{
    state: current_state
  } do
    title = "Linux Error Test"
    message = "This Linux notification failed."
    input_data = %{title: title, message: message}

    expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
    expect(SystemInteractionMock, :find_executable, fn "notify-send" -> "/bin/notify-send" end)
    expect(SystemInteractionMock, :system_cmd, fn "/bin/notify-send",
                                                 [^title, ^message],
                                                 opts ->
                                               assert opts == [stderr_to_stdout: true]
                                               # Simulate failed command execution
                                               {"Error output", 1}
                                           end)

    # Assert the command_failed error
    assert {:error, {:command_failed, 1, "Error output"}, current_state} =
             NotificationPlugin.handle_command(:notify, [input_data], current_state)
  end

  @tag :notification
  test "handle_command :notify calls osascript on macOS (Success)", %{state: current_state} do
    title = "macOS Test"
    message = "This is a macOS notification!"
    expected_script = ~s(display notification \"#{message}\" with title \"#{title}\")
    input_data = %{title: title, message: message}

    expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :darwin} end)
    expect(SystemInteractionMock, :find_executable, fn "osascript" -> "/usr/bin/osascript" end)
    expect(SystemInteractionMock, :system_cmd, fn "/usr/bin/osascript",
                                                 ["-e", ^expected_script],
                                                 opts ->
                                               assert opts == [stderr_to_stdout: true]
                                               {"", 0}
                                           end)

    # Assert successful macOS notification
    assert {:ok, current_state, :notification_sent_macos} =
             NotificationPlugin.handle_command(:notify, [input_data], current_state)
  end

  @tag :notification
  test "handle_command :notify handles osascript not found on macOS", %{state: current_state} do
    input_data = %{message: "test"}

    expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :darwin} end)
    expect(SystemInteractionMock, :find_executable, fn "osascript" -> nil end)

    # Assert command_not_found error for osascript
    assert {:error, {:command_not_found, :osascript}, current_state} =
             NotificationPlugin.handle_command(:notify, [input_data], current_state)
  end

  @tag :notification
  test "handle_command :notify calls PowerShell on Windows (Success)", %{state: current_state} do
    title = "Windows Test"
    message = "This is a Windows notification!"
    input_data = %{title: title, message: message}
    # Note: Updated script to not require title
    expected_script = ~s(Import-Module BurntToast; New-BurntToastNotification -Text "#{message}")

    expect(SystemInteractionMock, :get_os_type, fn -> {:win32, :nt} end)
    expect(SystemInteractionMock, :find_executable, fn "powershell" ->
             "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
           end)
    expect(SystemInteractionMock, :system_cmd, fn "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                                                 ["-NoProfile", "-Command", ^expected_script],
                                                 opts ->
                                               assert opts == [stderr_to_stdout: true]
                                               {"", 0}
                                           end)

    # Assert successful Windows notification
    assert {:ok, current_state, :notification_sent_windows} =
             NotificationPlugin.handle_command(:notify, [input_data], current_state)
  end

  @tag :notification
  test "handle_command :notify handles powershell not found on Windows", %{state: current_state} do
    input_data = %{message: "test"}

    expect(SystemInteractionMock, :get_os_type, fn -> {:win32, :nt} end)
    expect(SystemInteractionMock, :find_executable, fn "powershell" -> nil end)

    # Assert command_not_found error for powershell
    assert {:error, {:command_not_found, :powershell}, current_state} =
             NotificationPlugin.handle_command(:notify, [input_data], current_state)
  end

  @tag :notification
  test "handle_command :notify handles unsupported OS", %{state: current_state} do
    input_data = %{message: "test"}
    unsupported_os = {:unix, :solaris}

    expect(SystemInteractionMock, :get_os_type, fn -> unsupported_os end)

    # Assert skipped notification for unsupported OS
    assert {:ok, current_state, :notification_skipped_unsupported_os} =
             NotificationPlugin.handle_command(:notify, [input_data], current_state)
  end

  @tag :notification
  test "handle_command :notify handles command execution exception", %{state: current_state} do
    input_data = %{message: "test"}
    error = RuntimeError.exception("Command failed unexpectedly")
    title = "Raxol Notification" # Default title when none provided

    expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
    expect(SystemInteractionMock, :find_executable, fn "notify-send" -> "/bin/notify-send" end)
    expect(SystemInteractionMock, :system_cmd, fn "/bin/notify-send", [^title, "test"], _opts ->
             # Simulate an exception during command execution
             raise error
           end)

    # Assert the command_exception error
    # Use the short exception name returned by inspect(e.__struct__)
    assert {:error, {:command_exception, "RuntimeError", "Command failed unexpectedly"},
            current_state} =
             NotificationPlugin.handle_command(:notify, [input_data], current_state)
  end

  @tag :notification
  test "handle_command returns error for unknown command", %{state: current_state} do
    # Test calling the plugin with a command it doesn't handle
    assert {:error, {:unhandled_notification_command, :unknown}, current_state} ==
             NotificationPlugin.handle_command(:unknown, [], current_state)
  end

  @tag :notification
  test "handle_command :notify returns error for invalid input type", %{state: current_state} do
    # Test calling the :notify command with incorrect argument type
    assert {:error, {:unhandled_notification_command, :notify}, current_state} ==
             NotificationPlugin.handle_command(:notify, ["not_a_map"], current_state)
  end
end
