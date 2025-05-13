defmodule Raxol.Plugins.NotificationPluginTest do
  use ExUnit.Case, async: false
  import Mox

  alias Raxol.Core.Plugins.Core.NotificationPlugin

  # Define the mock using Mox.defmock
  Mox.defmock(SystemInteractionMock, for: Raxol.System.Interaction)

  # Setup Mox before each test
  setup :verify_on_exit!

  describe "init" do
    test "initializes with default configuration" do
      # Mock Application.get_env if needed, otherwise use default
      assert {:ok, state} = NotificationPlugin.init(%{})
      # Default
      assert state.interaction_module == Raxol.System.InteractionImpl
      assert state.name == "notification"
      assert state.enabled == true
      assert state.notifications == []
    end

    test "respects interaction module from config" do
      # Temporarily set app env for this test
      Application.put_env(
        :raxol,
        :system_interaction_module,
        SystemInteractionMock
      )

      assert {:ok, state} = NotificationPlugin.init(%{})
      assert state.interaction_module == SystemInteractionMock
      # Cleanup
      Application.delete_env(:raxol, :system_interaction_module)
    end
  end

  describe "get_commands" do
    test "get_commands/0 returns notify command" do
      # Expect arity 2 for handle_command(args, state) as registered
      assert [{:notify, :handle_command, 2}] = NotificationPlugin.get_commands()
    end
  end

  describe "handle_command" do
    setup do
      # Set up mocks for SystemInteractionMock
      Mox.stub(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)

      Mox.stub(SystemInteractionMock, :find_executable, fn _ ->
        "/usr/bin/mock-executable"
      end)

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
      level = "Test Level"
      message = "This is a test notification!"
      args = [level, message]

      %{current_state: state, args: args, level: level, message: message}
    end

    test "calls notify-send on Linux (Success)", %{
      current_state: state,
      args: args,
      level: level,
      message: message
    } do
      # Mock OS and command execution
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)

      Mox.expect(SystemInteractionMock, :find_executable, fn "notify-send" ->
        "/usr/bin/notify-send"
      end)

      Mox.expect(SystemInteractionMock, :system_cmd, fn "/usr/bin/notify-send",
                                                        [^level, ^message],
                                                        _ ->
        {"", 0}
      end)

      # Call handle_command/2 (args, state)
      assert {:ok, _, :notification_sent_linux} =
               NotificationPlugin.handle_command(args, state)
    end

    test "handles notify-send not found on Linux", %{
      current_state: state,
      args: args
    } do
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)

      Mox.expect(SystemInteractionMock, :find_executable, fn "notify-send" ->
        nil
      end)

      # Call handle_command/2
      assert {:error, {:command_not_found, :notify_send}, _} =
               NotificationPlugin.handle_command(args, state)
    end

    test "handles notify-send command failure on Linux", %{
      current_state: state,
      args: args,
      level: level,
      message: message
    } do
      Mox.expect(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)

      Mox.expect(SystemInteractionMock, :find_executable, fn "notify-send" ->
        "/usr/bin/notify-send"
      end)

      Mox.expect(SystemInteractionMock, :system_cmd, fn "/usr/bin/notify-send",
                                                        [^level, ^message],
                                                        _ ->
        {"Error output", 1}
      end)

      # Call handle_command/2
      assert {:error, {:command_failed, 1, "Error output"}, _} =
               NotificationPlugin.handle_command(args, state)
    end

    test "handles unsupported OS", %{current_state: state, args: args} do
      # Mock an unsupported OS
      Mox.expect(SystemInteractionMock, :get_os_type, fn ->
        {:amiga, :workbench}
      end)

      # Call handle_command/2
      assert {:ok, _, :notification_skipped_unsupported_os} =
               NotificationPlugin.handle_command(args, state)
    end
  end
end
