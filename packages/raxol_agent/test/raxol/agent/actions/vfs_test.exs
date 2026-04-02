defmodule Raxol.Agent.Actions.VfsTest do
  use ExUnit.Case, async: true

  alias Raxol.Commands.FileSystem
  alias Raxol.Agent.Actions.Vfs
  alias Raxol.Agent.Action.ToolConverter

  setup do
    fs = FileSystem.new()
    {:ok, fs} = FileSystem.mkdir(fs, "/docs")
    {:ok, fs} = FileSystem.create_file(fs, "/docs/readme.txt", "Hello, world!")
    {:ok, fs} = FileSystem.create_file(fs, "/hello.txt", "Hi")
    %{fs: fs, context: %{vfs: fs}}
  end

  describe "Vfs.actions/0" do
    test "returns all VFS action modules" do
      actions = Vfs.actions()
      assert length(actions) == 7
      assert Vfs.ListDir in actions
      assert Vfs.ReadFile in actions
      assert Vfs.WriteFile in actions
      assert Vfs.MakeDir in actions
      assert Vfs.Remove in actions
      assert Vfs.ChangeDir in actions
      assert Vfs.GetTree in actions
    end
  end

  describe "ListDir" do
    test "lists directory entries", %{context: ctx} do
      assert {:ok, result} = Vfs.ListDir.call(%{path: "/"}, ctx)
      assert "docs" in result.entries
      assert "hello.txt" in result.entries
    end

    test "defaults to current directory", %{context: ctx} do
      assert {:ok, result} = Vfs.ListDir.call(%{}, ctx)
      assert is_list(result.entries)
    end

    test "returns error for missing path", %{context: ctx} do
      assert {:error, :not_found} = Vfs.ListDir.call(%{path: "/nope"}, ctx)
    end

    test "creates fresh vfs when none in context" do
      assert {:ok, result} = Vfs.ListDir.call(%{}, %{})
      assert result.entries == []
      assert result.cwd == "/"
    end
  end

  describe "ReadFile" do
    test "reads file content", %{context: ctx} do
      assert {:ok, result} = Vfs.ReadFile.call(%{path: "/docs/readme.txt"}, ctx)
      assert result.content == "Hello, world!"
      assert result.path == "/docs/readme.txt"
    end

    test "returns error for missing file", %{context: ctx} do
      assert {:error, :not_found} = Vfs.ReadFile.call(%{path: "/nope.txt"}, ctx)
    end

    test "returns error for directory", %{context: ctx} do
      assert {:error, :is_a_directory} = Vfs.ReadFile.call(%{path: "/docs"}, ctx)
    end

    test "requires path parameter", %{context: ctx} do
      assert {:error, _} = Vfs.ReadFile.call(%{}, ctx)
    end
  end

  describe "WriteFile" do
    test "creates file and returns updated vfs", %{context: ctx} do
      assert {:ok, result} = Vfs.WriteFile.call(%{path: "/new.txt", content: "test"}, ctx)
      assert result.path == "/new.txt"
      assert result.size == 4
      assert %FileSystem{} = result.vfs
      assert {:ok, "test"} = FileSystem.cat(result.vfs, "/new.txt")
    end

    test "returns error for missing parent", %{context: ctx} do
      assert {:error, :parent_not_found} =
               Vfs.WriteFile.call(%{path: "/deep/nested/file.txt", content: "x"}, ctx)
    end

    test "requires path and content", %{context: ctx} do
      assert {:error, _} = Vfs.WriteFile.call(%{path: "/f.txt"}, ctx)
      assert {:error, _} = Vfs.WriteFile.call(%{content: "x"}, ctx)
    end
  end

  describe "MakeDir" do
    test "creates directory and returns updated vfs", %{context: ctx} do
      assert {:ok, result} = Vfs.MakeDir.call(%{path: "/src"}, ctx)
      assert result.path == "/src"
      assert FileSystem.exists?(result.vfs, "/src")
    end

    test "returns error for duplicate", %{context: ctx} do
      assert {:error, :already_exists} = Vfs.MakeDir.call(%{path: "/docs"}, ctx)
    end
  end

  describe "Remove" do
    test "removes file and returns updated vfs", %{context: ctx} do
      assert {:ok, result} = Vfs.Remove.call(%{path: "/hello.txt"}, ctx)
      refute FileSystem.exists?(result.vfs, "/hello.txt")
    end

    test "returns error for non-empty directory", %{context: ctx} do
      assert {:error, :directory_not_empty} = Vfs.Remove.call(%{path: "/docs"}, ctx)
    end

    test "returns error for root", %{context: ctx} do
      assert {:error, :cannot_remove_root} = Vfs.Remove.call(%{path: "/"}, ctx)
    end
  end

  describe "ChangeDir" do
    test "changes cwd and returns updated vfs", %{context: ctx} do
      assert {:ok, result} = Vfs.ChangeDir.call(%{path: "/docs"}, ctx)
      assert result.cwd == "/docs"
      assert FileSystem.pwd(result.vfs) == "/docs"
    end

    test "returns error for missing path", %{context: ctx} do
      assert {:error, :not_found} = Vfs.ChangeDir.call(%{path: "/nope"}, ctx)
    end
  end

  describe "GetTree" do
    test "returns tree structure", %{context: ctx} do
      assert {:ok, result} = Vfs.GetTree.call(%{path: "/"}, ctx)
      assert %{tree: tree} = result
      assert %{name: "/", children: children} = tree
      assert is_list(children)
    end

    test "formats files as strings" do
      fs = FileSystem.new()
      {:ok, fs} = FileSystem.create_file(fs, "/a.txt", "x")

      assert {:ok, result} = Vfs.GetTree.call(%{}, %{vfs: fs})
      assert %{tree: %{children: children}} = result
      assert "a.txt" in children
    end

    test "defaults to root with depth 3", %{context: ctx} do
      assert {:ok, _result} = Vfs.GetTree.call(%{}, ctx)
    end
  end

  describe "ToolConverter integration" do
    test "generates tool definitions for all VFS actions" do
      defs = ToolConverter.to_tool_definitions(Vfs.actions())
      assert length(defs) == 7

      names = Enum.map(defs, fn d -> d["function"]["name"] end)
      assert "vfs_list_dir" in names
      assert "vfs_read_file" in names
      assert "vfs_write_file" in names
      assert "vfs_make_dir" in names
      assert "vfs_remove" in names
      assert "vfs_change_dir" in names
      assert "vfs_get_tree" in names
    end

    test "dispatches tool call to correct action", %{context: ctx} do
      tool_call = %{"name" => "vfs_read_file", "arguments" => %{"path" => "/hello.txt"}}
      assert {:ok, result} = ToolConverter.dispatch_tool_call(tool_call, Vfs.actions(), ctx)
      assert result.content == "Hi"
    end

    test "dispatches mutating action and returns updated vfs", %{context: ctx} do
      tool_call = %{
        "name" => "vfs_write_file",
        "arguments" => %{"path" => "/new.txt", "content" => "created"}
      }

      assert {:ok, result} = ToolConverter.dispatch_tool_call(tool_call, Vfs.actions(), ctx)
      assert {:ok, "created"} = FileSystem.cat(result.vfs, "/new.txt")
    end
  end

  describe "pipeline composition" do
    test "actions can be composed in a pipeline" do
      alias Raxol.Agent.Action.Pipeline

      fs = FileSystem.new()

      assert {:ok, state, _commands} =
               Pipeline.run(
                 [
                   {Vfs.MakeDir, %{path: "/src"}},
                   {Vfs.WriteFile, %{path: "/src/app.ex", content: "defmodule App do\nend"}}
                 ],
                 %{},
                 %{vfs: fs}
               )

      assert state.path == "/src/app.ex"
    end
  end
end
