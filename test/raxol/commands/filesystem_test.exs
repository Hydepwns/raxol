defmodule Raxol.Commands.FileSystemTest do
  use ExUnit.Case, async: true
  alias Raxol.Commands.FileSystem

  describe "new/0" do
    test "creates empty filesystem" do
      fs = FileSystem.new()

      assert fs.cwd == "/"
      assert fs.history == ["/"]
      assert fs.root.type == :directory
      assert fs.root.entries == %{}
    end
  end

  describe "mkdir/2" do
    test "creates directory" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")

      {:ok, entries, _} = FileSystem.ls(fs, "/")
      assert "documents" in entries
    end

    test "creates nested directories" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/a")
      {:ok, fs} = FileSystem.mkdir(fs, "/a/b")

      {:ok, entries, _} = FileSystem.ls(fs, "/a")
      assert "b" in entries
    end

    test "returns error if already exists" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")

      {:error, reason} = FileSystem.mkdir(fs, "/documents")
      assert reason =~ "Already exists"
    end

    test "creates with relative path" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.cd(fs, "/")
      {:ok, fs} = FileSystem.mkdir(fs, "documents")

      {:ok, entries, _} = FileSystem.ls(fs, "/")
      assert "documents" in entries
    end
  end

  describe "create_file/3" do
    test "creates file with content" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.create_file(fs, "/readme.txt", "Hello World")

      {:ok, content, _} = FileSystem.cat(fs, "/readme.txt")
      assert content == "Hello World"
    end

    test "returns error if already exists" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.create_file(fs, "/readme.txt", "content")

      {:error, reason} = FileSystem.create_file(fs, "/readme.txt", "other")
      assert reason =~ "Already exists"
    end

    test "creates file in subdirectory" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/docs")
      {:ok, fs} = FileSystem.create_file(fs, "/docs/readme.txt", "content")

      {:ok, content, _} = FileSystem.cat(fs, "/docs/readme.txt")
      assert content == "content"
    end
  end

  describe "ls/2" do
    setup do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")
      {:ok, fs} = FileSystem.mkdir(fs, "/projects")
      {:ok, fs} = FileSystem.create_file(fs, "/readme.txt", "content")

      {:ok, fs: fs}
    end

    test "lists root directory", %{fs: fs} do
      {:ok, entries, _} = FileSystem.ls(fs, "/")

      assert length(entries) == 3
      assert "documents" in entries
      assert "projects" in entries
      assert "readme.txt" in entries
    end

    test "lists current directory by default", %{fs: fs} do
      {:ok, fs} = FileSystem.cd(fs, "/documents")
      {:ok, entries, _} = FileSystem.ls(fs)

      assert is_list(entries)
    end

    test "sorts entries alphabetically", %{fs: fs} do
      {:ok, entries, _} = FileSystem.ls(fs, "/")

      assert entries == Enum.sort(entries)
    end

    test "returns error for non-directory", %{fs: fs} do
      {:error, reason} = FileSystem.ls(fs, "/readme.txt")
      assert reason =~ "Not a directory"
    end

    test "returns error for non-existent path", %{fs: fs} do
      {:error, _reason} = FileSystem.ls(fs, "/nonexistent")
    end
  end

  describe "cat/2" do
    setup do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.create_file(fs, "/readme.txt", "Hello World")

      {:ok, fs: fs}
    end

    test "reads file content", %{fs: fs} do
      {:ok, content, _} = FileSystem.cat(fs, "/readme.txt")

      assert content == "Hello World"
    end

    test "returns error for directory", %{fs: fs} do
      {:ok, fs} = FileSystem.mkdir(fs, "/docs")

      {:error, reason} = FileSystem.cat(fs, "/docs")
      assert reason =~ "Is a directory"
    end

    test "returns error for non-existent file", %{fs: fs} do
      {:error, _reason} = FileSystem.cat(fs, "/nonexistent.txt")
    end
  end

  describe "cd/2" do
    setup do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")
      {:ok, fs} = FileSystem.mkdir(fs, "/documents/work")

      {:ok, fs: fs}
    end

    test "changes to absolute path", %{fs: fs} do
      {:ok, fs} = FileSystem.cd(fs, "/documents")

      {:ok, cwd, _} = FileSystem.pwd(fs)
      assert cwd == "/documents"
    end

    test "changes to relative path", %{fs: fs} do
      {:ok, fs} = FileSystem.cd(fs, "/documents")
      {:ok, fs} = FileSystem.cd(fs, "work")

      {:ok, cwd, _} = FileSystem.pwd(fs)
      assert cwd == "/documents/work"
    end

    test "navigates to parent with ..", %{fs: fs} do
      {:ok, fs} = FileSystem.cd(fs, "/documents/work")
      {:ok, fs} = FileSystem.cd(fs, "..")

      {:ok, cwd, _} = FileSystem.pwd(fs)
      assert cwd == "/documents"
    end

    test "goes to root with no args" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")
      {:ok, fs} = FileSystem.cd(fs, "/documents")
      {:ok, fs} = FileSystem.cd(fs)

      {:ok, cwd, _} = FileSystem.pwd(fs)
      assert cwd == "/"
    end

    test "goes to previous directory with -", %{fs: fs} do
      {:ok, fs} = FileSystem.cd(fs, "/documents")
      {:ok, fs} = FileSystem.cd(fs, "/")
      {:ok, fs} = FileSystem.cd(fs, "-")

      {:ok, cwd, _} = FileSystem.pwd(fs)
      assert cwd == "/documents"
    end

    test "maintains history", %{fs: fs} do
      {:ok, fs} = FileSystem.cd(fs, "/documents")

      assert length(fs.history) > 1
      assert "/" in fs.history
    end

    test "returns error for non-directory", %{fs: fs} do
      {:ok, fs} = FileSystem.create_file(fs, "/file.txt", "content")

      {:error, reason} = FileSystem.cd(fs, "/file.txt")
      assert reason =~ "Not a directory"
    end

    test "returns error for non-existent path", %{fs: fs} do
      {:error, _reason} = FileSystem.cd(fs, "/nonexistent")
    end
  end

  describe "pwd/1" do
    test "returns current directory" do
      fs = FileSystem.new()
      {:ok, path, _} = FileSystem.pwd(fs)

      assert path == "/"
    end

    test "returns updated directory after cd" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")
      {:ok, fs} = FileSystem.cd(fs, "/documents")

      {:ok, path, _} = FileSystem.pwd(fs)
      assert path == "/documents"
    end
  end

  describe "rm/2" do
    setup do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")
      {:ok, fs} = FileSystem.create_file(fs, "/readme.txt", "content")

      {:ok, fs: fs}
    end

    test "removes file", %{fs: fs} do
      {:ok, fs} = FileSystem.rm(fs, "/readme.txt")

      {:error, _} = FileSystem.cat(fs, "/readme.txt")
    end

    test "removes empty directory", %{fs: fs} do
      {:ok, fs} = FileSystem.rm(fs, "/documents")

      {:error, _} = FileSystem.cd(fs, "/documents")
    end

    test "returns error for non-empty directory", %{fs: fs} do
      {:ok, fs} = FileSystem.create_file(fs, "/documents/file.txt", "content")

      {:error, reason} = FileSystem.rm(fs, "/documents")
      assert reason =~ "not empty"
    end

    test "returns error for root", %{fs: fs} do
      {:error, reason} = FileSystem.rm(fs, "/")
      assert reason =~ "Cannot remove root"
    end

    test "returns error for non-existent path", %{fs: fs} do
      {:error, _reason} = FileSystem.rm(fs, "/nonexistent")
    end
  end

  describe "stat/2" do
    test "returns file metadata" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.create_file(fs, "/file.txt", "content")

      {:ok, meta, _} = FileSystem.stat(fs, "/file.txt")

      assert meta.type == :file
      assert meta.size == 7
      assert %DateTime{} = meta.created
      assert %DateTime{} = meta.modified
    end

    test "returns directory metadata" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")

      {:ok, meta, _} = FileSystem.stat(fs, "/documents")

      assert meta.type == :directory
    end

    test "returns error for non-existent path" do
      fs = FileSystem.new()

      {:error, _reason} = FileSystem.stat(fs, "/nonexistent")
    end
  end

  describe "exists?/2" do
    test "returns true for existing file" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.create_file(fs, "/file.txt", "content")

      assert FileSystem.exists?(fs, "/file.txt") == true
    end

    test "returns true for existing directory" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")

      assert FileSystem.exists?(fs, "/documents") == true
    end

    test "returns false for non-existent path" do
      fs = FileSystem.new()

      assert FileSystem.exists?(fs, "/nonexistent") == false
    end
  end

  describe "tree/3" do
    setup do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")
      {:ok, fs} = FileSystem.mkdir(fs, "/documents/work")
      {:ok, fs} = FileSystem.create_file(fs, "/documents/readme.txt", "content")
      {:ok, fs} = FileSystem.create_file(fs, "/documents/work/notes.txt", "notes")

      {:ok, fs: fs}
    end

    test "returns tree structure", %{fs: fs} do
      {:ok, tree, _} = FileSystem.tree(fs, "/")

      assert is_tuple(tree)
      {_name, type, _children} = tree
      assert type == :directory
    end

    test "respects max depth", %{fs: fs} do
      {:ok, tree1, _} = FileSystem.tree(fs, "/", 1)
      {:ok, tree2, _} = FileSystem.tree(fs, "/", 2)

      # Tree with depth 2 should have more detail
      assert tree1 != tree2
    end
  end

  describe "path resolution" do
    test "resolves absolute paths" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")
      {:ok, fs} = FileSystem.cd(fs, "/documents")

      # Absolute path should work from anywhere
      {:ok, entries, _} = FileSystem.ls(fs, "/")
      assert "documents" in entries
    end

    test "resolves relative paths" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/a")
      {:ok, fs} = FileSystem.mkdir(fs, "/a/b")
      {:ok, fs} = FileSystem.cd(fs, "/a")

      {:ok, entries, _} = FileSystem.ls(fs, "b")
      assert is_list(entries)
    end

    test "resolves .. correctly" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/a")
      {:ok, fs} = FileSystem.mkdir(fs, "/a/b")
      {:ok, fs} = FileSystem.cd(fs, "/a/b")

      {:ok, fs} = FileSystem.cd(fs, "../..")
      {:ok, cwd, _} = FileSystem.pwd(fs)
      assert cwd == "/"
    end

    test "normalizes paths with redundant components" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/a")
      {:ok, fs} = FileSystem.cd(fs, "/a/./././")

      {:ok, cwd, _} = FileSystem.pwd(fs)
      assert cwd == "/a"
    end
  end

  describe "buffer integration" do
    test "format_ls creates buffer" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.mkdir(fs, "/documents")
      {:ok, fs} = FileSystem.create_file(fs, "/readme.txt", "content")

      {:ok, entries, _} = FileSystem.ls(fs, "/")
      buffer = FileSystem.format_ls(entries, fs, "/")

      assert buffer.width > 0
      assert buffer.height > 0
    end

    test "format_cat creates buffer" do
      content = "Line 1\nLine 2\nLine 3"
      buffer = FileSystem.format_cat(content, 40, 10)

      assert buffer.width == 40
      assert buffer.height == 10
    end
  end
end
