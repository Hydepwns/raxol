defmodule Raxol.Agent.CommandTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Command

  describe "async/1" do
    test "creates an async command" do
      cmd = Command.async(fn _sender -> :ok end)
      assert %Command{type: :async} = cmd
    end

    test "sender callback delivers multiple messages" do
      cmd =
        Command.async(fn sender ->
          sender.(:first)
          sender.(:second)
          sender.(:third)
        end)

      context = %{pid: self(), runtime_pid: self()}
      Command.execute(cmd, context)

      assert_receive {:command_result, :first}, 1000
      assert_receive {:command_result, :second}, 1000
      assert_receive {:command_result, :third}, 1000
    end

    test "async command handles exceptions" do
      cmd =
        Command.async(fn _sender ->
          raise "test explosion"
        end)

      context = %{pid: self(), runtime_pid: self()}
      Command.execute(cmd, context)

      assert_receive {:command_result, {:async_error, msg}}, 1000
      assert msg =~ "test explosion"
    end
  end

  describe "shell/2" do
    test "creates a shell command" do
      cmd = Command.shell("echo hello")
      assert %Command{type: :shell} = cmd
    end

    test "collects shell output" do
      cmd = Command.shell("echo hello")

      context = %{pid: self(), runtime_pid: self()}
      Command.execute(cmd, context)

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert result.exit_status == 0
      assert String.trim(result.output) == "hello"
    end

    test "shell command returns exit status" do
      cmd = Command.shell("exit 42")

      context = %{pid: self(), runtime_pid: self()}
      Command.execute(cmd, context)

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert result.exit_status == 42
    end

    test "shell command timeout" do
      cmd = Command.shell("sleep 10", timeout: 100)

      context = %{pid: self(), runtime_pid: self()}
      Command.execute(cmd, context)

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert result.exit_status == :timeout
    end
  end

  describe "send_agent/2" do
    test "creates a send_agent command" do
      cmd = Command.send_agent(:target, :hello)
      assert %Command{type: :send_agent} = cmd
    end

    test "send_agent reports not_found for missing target" do
      # Start the registry if not already running
      start_supervised!({Registry, keys: :unique, name: Raxol.Agent.Registry})

      cmd = Command.send_agent(:nonexistent_target, :hello)

      context = %{pid: self(), runtime_pid: self(), agent_id: :sender}
      Command.execute(cmd, context)

      assert_receive {:command_result,
                      {:send_agent_error, :not_found, :nonexistent_target}},
                     1000
    end
  end

  describe "map/2 for async" do
    test "maps over async sender messages" do
      cmd =
        Command.async(fn sender -> sender.(:raw) end)
        |> Command.map(fn :raw -> :mapped end)

      context = %{pid: self(), runtime_pid: self()}
      Command.execute(cmd, context)

      assert_receive {:command_result, :mapped}, 1000
    end
  end
end
