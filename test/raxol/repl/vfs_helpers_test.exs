defmodule Raxol.REPL.VfsHelpersTest do
  use ExUnit.Case, async: true

  alias Raxol.Commands.FileSystem
  alias Raxol.REPL.{Evaluator, VfsHelpers}

  describe "ls/2" do
    test "prints directory entries" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/docs")
      {:ok, fs} = FileSystem.create_file(fs, "/hello.txt", "hi")

      output = capture_io(fn -> VfsHelpers.ls(fs) end)
      assert output =~ "docs/"
      assert output =~ "hello.txt"
    end

    test "returns fs unchanged" do
      fs = FileSystem.new()
      returned = capture_and_return(fn -> VfsHelpers.ls(fs) end)
      assert returned == fs
    end

    test "prints error for missing path" do
      fs = FileSystem.new()
      output = capture_io(fn -> VfsHelpers.ls(fs, "/nope") end)
      assert output =~ "ls:"
      assert output =~ "not found"
    end
  end

  describe "cd/2" do
    test "changes directory and prints new cwd" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/docs")

      {output, new_fs} = capture_io_and_return(fn -> VfsHelpers.cd(fs, "/docs") end)
      assert output =~ "/docs"
      assert FileSystem.pwd(new_fs) == "/docs"
    end

    test "returns original fs on error" do
      fs = FileSystem.new()
      returned = capture_and_return(fn -> VfsHelpers.cd(fs, "/nope") end)
      assert FileSystem.pwd(returned) == "/"
    end
  end

  describe "pwd/1" do
    test "prints current directory" do
      fs = FileSystem.new()
      output = capture_io(fn -> VfsHelpers.pwd(fs) end)
      assert output =~ "/"
    end
  end

  describe "cat/2" do
    test "prints file contents" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.create_file(fs, "/hello.txt", "Hello, world!")

      output = capture_io(fn -> VfsHelpers.cat(fs, "/hello.txt") end)
      assert output =~ "Hello, world!"
    end

    test "prints error for missing file" do
      fs = FileSystem.new()
      output = capture_io(fn -> VfsHelpers.cat(fs, "/nope.txt") end)
      assert output =~ "cat:"
    end
  end

  describe "mkdir/2" do
    test "creates directory and prints confirmation" do
      fs = FileSystem.new()
      {output, new_fs} = capture_io_and_return(fn -> VfsHelpers.mkdir(fs, "/docs") end)
      assert output =~ "mkdir: created /docs"
      assert FileSystem.exists?(new_fs, "/docs")
    end

    test "prints error for duplicate" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/docs")
      output = capture_io(fn -> VfsHelpers.mkdir(fs, "/docs") end)
      assert output =~ "mkdir:"
      assert output =~ "already exists"
    end
  end

  describe "touch/3" do
    test "creates file with content" do
      fs = FileSystem.new()

      {output, new_fs} =
        capture_io_and_return(fn -> VfsHelpers.touch(fs, "/readme.txt", "Hello") end)

      assert output =~ "touch: created /readme.txt"
      {:ok, content} = FileSystem.cat(new_fs, "/readme.txt")
      assert content == "Hello"
    end

    test "creates empty file by default" do
      fs = FileSystem.new()
      {_output, new_fs} = capture_io_and_return(fn -> VfsHelpers.touch(fs, "/empty.txt") end)
      {:ok, content} = FileSystem.cat(new_fs, "/empty.txt")
      assert content == ""
    end
  end

  describe "rm/2" do
    test "removes file and prints confirmation" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.create_file(fs, "/tmp.txt", "x")

      {output, new_fs} = capture_io_and_return(fn -> VfsHelpers.rm(fs, "/tmp.txt") end)
      assert output =~ "rm: removed /tmp.txt"
      refute FileSystem.exists?(new_fs, "/tmp.txt")
    end

    test "prints error for non-empty directory" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/docs")
      {:ok, fs} = FileSystem.create_file(fs, "/docs/f.txt", "x")

      output = capture_io(fn -> VfsHelpers.rm(fs, "/docs") end)
      assert output =~ "rm:"
    end
  end

  describe "tree/3" do
    test "prints tree structure" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/docs")
      {:ok, fs} = FileSystem.create_file(fs, "/docs/readme.txt", "hi")

      output = capture_io(fn -> VfsHelpers.tree(fs) end)
      assert output =~ "/"
      assert output =~ "docs/"
      assert output =~ "readme.txt"
    end
  end

  describe "stat/2" do
    test "prints node metadata" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.create_file(fs, "/hello.txt", "Hello!")

      output = capture_io(fn -> VfsHelpers.stat(fs, "/hello.txt") end)
      assert output =~ "path: /hello.txt"
      assert output =~ "type: file"
      assert output =~ "size: 6"
    end
  end

  describe "evaluator integration" do
    test "with_vfs seeds vfs binding" do
      eval = Evaluator.new() |> Evaluator.with_vfs()
      assert Keyword.has_key?(Evaluator.bindings(eval), :vfs)
    end

    test "vfs helpers are importable via prelude" do
      eval = Evaluator.new() |> Evaluator.with_vfs()
      {:ok, result, _eval} = Evaluator.eval(eval, "vfs = mkdir(vfs, \"/docs\")")
      assert %Raxol.Commands.FileSystem{} = result.value
    end

    test "vfs state persists across evals" do
      eval = Evaluator.new() |> Evaluator.with_vfs()
      {:ok, _result, eval} = Evaluator.eval(eval, "vfs = mkdir(vfs, \"/src\")")
      {:ok, _result, eval} = Evaluator.eval(eval, "vfs = touch(vfs, \"/src/main.ex\", \"defmodule Main do\\nend\")")
      {:ok, result, _eval} = Evaluator.eval(eval, "cat(vfs, \"/src/main.ex\")")
      assert result.output =~ "defmodule Main do"
    end

    test "prelude does not appear in history" do
      eval = Evaluator.new() |> Evaluator.with_vfs()
      {:ok, _result, eval} = Evaluator.eval(eval, "1 + 1")
      [{code, _result}] = Evaluator.history(eval)
      assert code == "1 + 1"
      refute code =~ "import"
    end
  end

  # -- Helpers --

  defp capture_io(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end

  defp capture_and_return(fun) do
    {result, _output} = ExUnit.CaptureIO.with_io(fun)
    result
  end

  defp capture_io_and_return(fun) do
    {result, output} = ExUnit.CaptureIO.with_io(fun)
    {output, result}
  end
end
