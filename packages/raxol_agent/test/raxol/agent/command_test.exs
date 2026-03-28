defmodule Raxol.Agent.CommandTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Command

  describe "async/1" do
    test "creates an async command struct" do
      cmd = Command.async(fn _sender -> :ok end)
      assert %Command{type: :async} = cmd
      assert is_function(cmd.data, 1)
    end

    test "sender callback delivers messages to caller" do
      cmd =
        Command.async(fn sender ->
          sender.(:first)
          sender.(:second)
          sender.(:third)
        end)

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, :first}, 1000
      assert_receive {:command_result, :second}, 1000
      assert_receive {:command_result, :third}, 1000
    end

    test "sender can send structured data" do
      cmd =
        Command.async(fn sender ->
          sender.({:progress, 25})
          sender.({:progress, 50})
          sender.({:done, %{result: "success", items: 42}})
        end)

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, {:progress, 25}}, 1000
      assert_receive {:command_result, {:progress, 50}}, 1000
      assert_receive {:command_result, {:done, %{result: "success", items: 42}}}, 1000
    end

    test "exceptions are caught and reported" do
      cmd =
        Command.async(fn _sender ->
          raise "test explosion"
        end)

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, {:async_error, msg}}, 1000
      assert msg =~ "test explosion"
    end

    test "exception after partial sends still reports error" do
      cmd =
        Command.async(fn sender ->
          sender.(:partial)
          raise "mid-stream failure"
        end)

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, :partial}, 1000
      assert_receive {:command_result, {:async_error, msg}}, 1000
      assert msg =~ "mid-stream failure"
    end
  end

  describe "shell/2" do
    test "creates a shell command struct" do
      cmd = Command.shell("echo hello")
      assert %Command{type: :shell} = cmd
      assert {command, _opts} = cmd.data
      assert command == "echo hello"
    end

    @tag :unix_only
    test "executes command and collects stdout" do
      cmd = Command.shell("echo hello_world")

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert result.exit_status == 0
      assert String.trim(result.output) == "hello_world"
    end

    @tag :unix_only
    test "captures multiline output" do
      cmd = Command.shell("printf 'line1\nline2\nline3'")

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert result.exit_status == 0
      lines = String.split(result.output, "\n", trim: true)
      assert lines == ["line1", "line2", "line3"]
    end

    @tag :unix_only
    test "reports non-zero exit status" do
      cmd = Command.shell("exit 42")

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert result.exit_status == 42
    end

    @tag :unix_only
    test "reports stderr (merged with stdout)" do
      cmd = Command.shell("echo error_msg >&2")

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert String.contains?(result.output, "error_msg")
    end

    @tag :unix_only
    test "respects timeout option" do
      cmd = Command.shell("sleep 10", timeout: 200)

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert result.exit_status == :timeout
    end

    @tag :unix_only
    test "respects cd option" do
      cmd = Command.shell("pwd", cd: "/tmp")

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert result.exit_status == 0
      assert String.trim(result.output) =~ ~r{^(/private)?/tmp$}
    end

    @tag :unix_only
    test "respects env option" do
      cmd = Command.shell("echo $MY_TEST_VAR", env: [{"MY_TEST_VAR", "agent_test_value"}])

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, {:shell_result, result}}, 5000
      assert String.trim(result.output) == "agent_test_value"
    end
  end

  describe "send_agent/2" do
    test "creates a send_agent command struct" do
      cmd = Command.send_agent(:target, :hello)
      assert %Command{type: :send_agent} = cmd
      assert cmd.data == {:target, :hello}
    end

    test "reports not_found for missing target" do
      # Registry started by application.ex in test mode
      cmd = Command.send_agent(:nonexistent_target, :hello)

      Command.execute(cmd, %{pid: self(), runtime_pid: self(), agent_id: :sender})

      assert_receive {:command_result, {:send_agent_error, :not_found, :nonexistent_target}},
                     1000
    end
  end

  describe "map/2" do
    test "maps over async sender messages" do
      cmd =
        Command.async(fn sender -> sender.(:raw) end)
        |> Command.map(fn :raw -> :mapped end)

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, :mapped}, 1000
    end

    test "map composes with multiple transforms" do
      cmd =
        Command.async(fn sender -> sender.(1) end)
        |> Command.map(fn n -> n * 2 end)
        |> Command.map(fn n -> n + 10 end)

      Command.execute(cmd, %{pid: self(), runtime_pid: self()})

      assert_receive {:command_result, 12}, 1000
    end

    test "pass-through for shell and send_agent" do
      shell_cmd = Command.shell("echo hi") |> Command.map(fn x -> x end)
      assert %Command{type: :shell} = shell_cmd

      agent_cmd = Command.send_agent(:t, :m) |> Command.map(fn x -> x end)
      assert %Command{type: :send_agent} = agent_cmd
    end
  end
end
