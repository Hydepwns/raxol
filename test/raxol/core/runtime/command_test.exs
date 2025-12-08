defmodule Raxol.Core.Runtime.CommandTest do
  @moduledoc """
  Tests for the command runtime system, including creation, mapping,
  execution, and error handling.
  """
  use ExUnit.Case, async: false
  alias Raxol.Core.Runtime.Command

  setup do
    temp_dir =
      System.tmp_dir!()
      |> Path.join("raxol_test_#{:os.system_time(:nanosecond)}")

    File.mkdir_p!(temp_dir)
    on_exit(fn -> File.rm_rf!(temp_dir) end)
    {:ok, temp_dir: temp_dir}
  end

  describe "command creation" do
    test ~c"none/0 creates a no-op command" do
      cmd = Command.none()
      assert %Command{type: :none} = cmd
    end

    test ~c"task/1 creates a task command" do
      fun = fn -> :result end
      cmd = Command.task(fun)
      assert %Command{type: :task, data: ^fun} = cmd
    end

    test ~c"batch/1 creates a batch command" do
      commands = [Command.none(), Command.delay(:msg, 100)]
      cmd = Command.batch(commands)
      assert %Command{type: :batch, data: ^commands} = cmd
    end

    test ~c"delay/2 creates a delay command" do
      msg = :delayed_message
      delay_ms = 500
      cmd = Command.delay(msg, delay_ms)
      assert %Command{type: :delay, data: {^msg, ^delay_ms}} = cmd
    end

    test ~c"broadcast/1 creates a broadcast command" do
      msg = :broadcast_message
      cmd = Command.broadcast(msg)
      assert %Command{type: :broadcast, data: ^msg} = cmd
    end

    test ~c"system/2 creates a system command" do
      operation = :file_write
      opts = [path: "test.txt", content: "Hello"]
      cmd = Command.system(operation, opts)
      assert %Command{type: :system, data: {^operation, ^opts}} = cmd
    end
  end

  describe "map/2" do
    test ~c"maps over task command result" do
      cmd = Command.task(fn -> :original end)
      mapper = fn :original -> :mapped end

      mapped_cmd = Command.map(cmd, mapper)
      assert %Command{type: :task} = mapped_cmd

      # Execute the function to verify mapping
      result = mapped_cmd.data.()
      assert result == :mapped
    end

    test ~c"maps over batch command results" do
      commands = [
        Command.delay(:msg1, 100),
        Command.broadcast(:msg2)
      ]

      cmd = Command.batch(commands)

      mapper = fn
        :msg1 -> :mapped1
        :msg2 -> :mapped2
      end

      mapped_cmd = Command.map(cmd, mapper)
      assert %Command{type: :batch} = mapped_cmd

      [delay_cmd, broadcast_cmd] = mapped_cmd.data
      assert delay_cmd.data == {:mapped1, 100}
      assert broadcast_cmd.data == :mapped2
    end

    test ~c"maps over delay command message" do
      cmd = Command.delay(:original, 200)
      mapper = fn :original -> :mapped end

      mapped_cmd = Command.map(cmd, mapper)
      assert %Command{type: :delay, data: {:mapped, 200}} = mapped_cmd
    end

    test ~c"maps over broadcast command message" do
      cmd = Command.broadcast(:original)
      mapper = fn :original -> :mapped end

      mapped_cmd = Command.map(cmd, mapper)
      assert %Command{type: :broadcast, data: :mapped} = mapped_cmd
    end

    test ~c"does nothing for none command" do
      cmd = Command.none()
      mapper = fn _ -> :something_else end

      mapped_cmd = Command.map(cmd, mapper)
      assert mapped_cmd == cmd
    end
  end

  describe "execute/2" do
    setup do
      context = %{pid: self()}
      {:ok, context: context}
    end

    test "executes task command", %{context: context} do
      msg = {:task_completed, :data}
      cmd = Command.task(fn -> msg end)

      Command.execute(cmd, context)
      assert_receive {:command_result, ^msg}, 500
    end

    test "executes batch commands", %{context: context} do
      msg1 = {:result1, :data1}
      msg2 = {:result2, :data2}

      cmds = [
        Command.task(fn -> msg1 end),
        Command.task(fn -> msg2 end)
      ]

      cmd = Command.batch(cmds)
      Command.execute(cmd, context)

      assert_receive {:command_result, ^msg1}, 500
      assert_receive {:command_result, ^msg2}, 500
    end

    test "executes delay command", %{context: context} do
      msg = :delayed_message
      cmd = Command.delay(msg, 50)

      Command.execute(cmd, context)
      refute_receive {:command_result, ^msg}, 10
      assert_receive {:command_result, ^msg}, 200
    end

    test "executes file write system command", %{
      context: context,
      temp_dir: temp_dir
    } do
      file_path = Path.join(temp_dir, "output.txt")
      content = "hello from raxol test"

      cmd = Command.system(:file_write, path: file_path, content: content)

      Command.execute(cmd, context)

      assert_receive {:command_result, {:file_write, :ok}}, 500

      assert File.read!(file_path) == content
    end

    test "executes file read system command", %{
      context: context,
      temp_dir: temp_dir
    } do
      file_path = Path.join(temp_dir, "test_file.txt")
      content = "test content"
      File.write!(file_path, content)

      cmd = Command.system(:file_read, path: file_path)
      Command.execute(cmd, context)

      assert_receive {:command_result, {:file_read, ^content}}, 500
    end
  end
end
