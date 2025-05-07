defmodule Raxol.Core.Plugins.Core.NotificationPluginTest do
  use ExUnit.Case, async: false # Use async: false due to Mox
  import Mox # Add this import to make verify_on_exit! available

  alias Raxol.Core.Plugins.Core.NotificationPlugin

  # Define the mock using Mox.defmock
  Mox.defmock(SystemInteractionMock, for: Raxol.System.Interaction)

  # Setup Mox before each test
  setup :verify_on_exit!

  # Remove global skip tag to enable the tests

  describe "init" do
    test "init initializes state correctly" do
      # Mock Application.get_env if needed, otherwise use default
      assert {:ok, state} = NotificationPlugin.init(%{})
      assert state.interaction_module == Raxol.System.InteractionImpl # Default
      assert state.name == "notification"
      assert state.enabled == true
      assert state.notifications == []
    end

    test "init respects interaction module from config" do
      # Temporarily set app env for this test
      Application.put_env(:raxol, :system_interaction_module, SystemInteractionMock)
      assert {:ok, state} = NotificationPlugin.init(%{})
      assert state.interaction_module == SystemInteractionMock
      # Cleanup
      Application.delete_env(:raxol, :system_interaction_module)
    end
  end

  describe "get_commands" do
    @tag :notification
    test "get_commands/0 returns notify command" do
      # Expect arity 2 for handle_command(args, state) as registered
      assert [{:notify, :handle_command, 2}] = NotificationPlugin.get_commands()
    end
  end

  describe "handle_command" do # Renamed describe block for clarity
    # Common setup for notify tests
    setup %{test: test_name} do
      # Set up mocks for SystemInteractionMock
      Mox.stub(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
      Mox.stub(SystemInteractionMock, :find_executable, fn _ -> "/usr/bin/mock-executable" end)
      Mox.stub(SystemInteractionMock, :system_cmd, fn _, _, _ -> {"", 0} end)

      # Basic state needed by the plugin
      state = %{
        interaction_module: SystemInteractionMock,
        name: "notification_test",
        enabled: true,
        config: %{},
        notifications: []
      }

      # Define arguments for the command handler
      level = "Test Level #{test_name}"
      message = "This is a test notification for #{test_name}!"
      args = [level, message] # Keep args list separate

      %{current_state: state, args: args, level: level, message: message}
    end

    test "calls notify-send on Linux (Success)", %{current_state: state, args: args, level: level, message: message} do
      # Mock OS and command execution
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
      Mox.expect(SystemInteractionMock, :find_executable, fn "notify-send" -> "/usr/bin/notify-send" end)
      Mox.expect(SystemInteractionMock, :system_cmd, fn "/usr/bin/notify-send", [^level, ^message], _ -> {"", 0} end)

      # Call handle_command/3 (command, args, state)
      assert {:ok, _, :notification_sent_linux} = NotificationPlugin.handle_command(:notify, args, state)
    end

    test "handles notify-send not found on Linux", %{current_state: state, args: args} do
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
      Mox.expect(SystemInteractionMock, :find_executable, fn "notify-send" -> nil end)

      # Call handle_command/3
      assert {:error, {:command_not_found, :notify_send}, _} = NotificationPlugin.handle_command(:notify, args, state)
    end

    test "handles notify-send command failure on Linux", %{current_state: state, args: args, level: level, message: message} do
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
      Mox.expect(SystemInteractionMock, :find_executable, fn "notify-send" -> "/usr/bin/notify-send" end)
      Mox.expect(SystemInteractionMock, :system_cmd, fn "/usr/bin/notify-send", [^level, ^message], _ -> {"Error output", 1} end)

      # Call handle_command/3
      assert {:error, {:command_failed, 1, "Error output"}, _} = NotificationPlugin.handle_command(:notify, args, state)
    end

    test "calls osascript on macOS (Success)", %{current_state: state, args: args, level: level, message: message} do
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :darwin} end)
      Mox.expect(SystemInteractionMock, :find_executable, fn "osascript" -> "/usr/bin/osascript" end)
      # Expect the correct script based on args
      expected_script = ~s(display notification "#{message}" with title "#{level}")
      Mox.expect(SystemInteractionMock, :system_cmd, fn "/usr/bin/osascript", ["-e", ^expected_script], _ -> {"", 0} end)

      # Call handle_command/3
      assert {:ok, _, :notification_sent_macos} = NotificationPlugin.handle_command(:notify, args, state)
    end

    test "handles osascript not found on macOS", %{current_state: state, args: args} do
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :darwin} end)
      Mox.expect(SystemInteractionMock, :find_executable, fn "osascript" -> nil end)

      # Call handle_command/3
      assert {:error, {:command_not_found, :osascript}, _} = NotificationPlugin.handle_command(:notify, args, state)
    end

    test "calls PowerShell on Windows (Success)", %{current_state: state, args: args, message: message} do # level is unused here
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:win32, :nt} end)
      Mox.expect(SystemInteractionMock, :find_executable, fn "powershell" -> "C:/Windows/System32/powershell.exe" end)
      # Check the script includes the message (title isn't used by BurntToast this way)
      expected_script_fragment = ~s(New-BurntToastNotification -Text "#{message}")
      Mox.expect(SystemInteractionMock, :system_cmd, fn "C:/Windows/System32/powershell.exe", ["-NoProfile", "-Command", script], _ ->
        assert String.contains?(script, expected_script_fragment)
        {"", 0}
      end)

      # Call handle_command/3
      assert {:ok, _, :notification_sent_windows} = NotificationPlugin.handle_command(:notify, args, state)
    end

    test "handles powershell not found on Windows", %{current_state: state, args: args} do
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:win32, :nt} end)
      Mox.expect(SystemInteractionMock, :find_executable, fn "powershell" -> nil end)

      # Call handle_command/3
      assert {:error, {:command_not_found, :powershell}, _} = NotificationPlugin.handle_command(:notify, args, state)
    end

    test "handles unsupported OS", %{current_state: state, args: args} do
      # Mock an unsupported OS
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:amiga, :workbench} end)

      # Call handle_command/3
      assert {:ok, _, :notification_skipped_unsupported_os} = NotificationPlugin.handle_command(:notify, args, state)
    end

    test "handles command execution exception", %{current_state: state, args: args} do
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
      Mox.expect(SystemInteractionMock, :find_executable, fn "notify-send" -> "/usr/bin/notify-send" end)
      # Mock system_cmd to raise an exception
      Mox.expect(SystemInteractionMock, :system_cmd, fn _, _, _ -> raise "Command execution failed!" end)

      # Call handle_command/3
      {:error, {:command_exception, error_message}, _state} = NotificationPlugin.handle_command(:notify, args, state)
      assert String.contains?(error_message, "Command execution failed!")
    end
  end

  # Tests for non-:notify commands or invalid args
  describe "handle_command catch-all" do
    setup %{test: test_name} do
      Mox.stub(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)
      Mox.stub(SystemInteractionMock, :find_executable, fn _ -> "/usr/bin/mock-executable" end)
      Mox.stub(SystemInteractionMock, :system_cmd, fn _, _, _ -> {"", 0} end)

      state = %{ interaction_module: SystemInteractionMock } # Minimal state
      %{current_state: state}
    end

    test "returns error for invalid args structure", %{current_state: state} do
      # Call the handle_command/3 catch-all directly with an unknown command
      unknown_command = :unknown_cmd
      unknown_args = [:some_other_arg]
      assert {:error, {:unhandled_notification_command, ^unknown_command}, _} = NotificationPlugin.handle_command(unknown_command, unknown_args, state)
    end

    test "returns error for invalid arg types for :notify", %{current_state: state} do
      # Call handle_command/3 with invalid args type for :notify command
      # This should hit the clause guard `when is_binary(level) and is_binary(message)`
      # and fall through to the catch-all clause.
      invalid_args_1 = ["level", :not_a_binary]
      assert {:error, {:unhandled_notification_command, :notify}, _} = NotificationPlugin.handle_command(:notify, invalid_args_1, state)

      invalid_args_2 = "not a list"
      assert {:error, {:unhandled_notification_command, :notify}, _} = NotificationPlugin.handle_command(:notify, invalid_args_2, state)
    end
  end

  describe "terminate" do
    test "terminate/2 returns :ok" do
      assert NotificationPlugin.terminate(:shutdown, %{}) == :ok
    end
  end

  describe "enable/disable/filter_event" do
    test "enable returns :ok" do
      assert {:ok, state} = NotificationPlugin.enable(%{enabled: false})
      # Optionally check if state is updated if enable/disable modified it
    end

    test "disable returns :ok" do
      assert {:ok, state} = NotificationPlugin.disable(%{enabled: true})
      # Optionally check state
    end

    test "filter_event returns original event" do
      event = {:input, :key, "a"}
      assert {:ok, ^event, _} = NotificationPlugin.filter_event(event, %{})
    end
  end
end
