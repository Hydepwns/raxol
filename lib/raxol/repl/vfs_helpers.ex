defmodule Raxol.REPL.VfsHelpers do
  @moduledoc """
  Shell-like helper functions for the virtual filesystem in REPL sessions.

  Functions print their output via IO (captured by the evaluator) and return
  the VFS struct, making them chainable:

      vfs = ls(vfs)
      vfs = mkdir(vfs, "/docs")
      vfs = touch(vfs, "/docs/readme.txt", "Hello!")
      vfs = cat(vfs, "/docs/readme.txt")

  Enable with `Evaluator.with_vfs/1` which seeds a `vfs` binding and
  auto-imports this module into each evaluation.
  """

  alias Raxol.Commands.FileSystem

  @ansi_red "\e[31m"
  @ansi_blue_bold "\e[1;34m"
  @ansi_reset "\e[0m"

  @doc "List directory contents."
  @spec ls(FileSystem.t(), String.t()) :: FileSystem.t()
  def ls(fs, path \\ ".") do
    case FileSystem.ls(fs, path) do
      {:ok, entries} ->
        FileSystem.format_ls(entries, fs, path)
        |> Enum.each(fn {text, type} ->
          case type do
            :directory -> IO.puts("#{@ansi_blue_bold}#{text}#{@ansi_reset}")
            :file -> IO.puts(text)
          end
        end)

      {:error, reason} ->
        print_error("ls", reason)
    end

    fs
  end

  @doc "Change working directory."
  @spec cd(FileSystem.t(), String.t()) :: FileSystem.t()
  def cd(fs, path) do
    case FileSystem.cd(fs, path) do
      {:ok, new_fs} ->
        IO.puts(FileSystem.pwd(new_fs))
        new_fs

      {:error, reason} ->
        print_error("cd", reason)
        fs
    end
  end

  @doc "Print working directory."
  @spec pwd(FileSystem.t()) :: FileSystem.t()
  def pwd(fs) do
    IO.puts(FileSystem.pwd(fs))
    fs
  end

  @doc "Print file contents."
  @spec cat(FileSystem.t(), String.t()) :: FileSystem.t()
  def cat(fs, path) do
    case FileSystem.cat(fs, path) do
      {:ok, content} -> IO.puts(content)
      {:error, reason} -> print_error("cat", reason)
    end

    fs
  end

  @doc "Create a directory."
  @spec mkdir(FileSystem.t(), String.t()) :: FileSystem.t()
  def mkdir(fs, path) do
    case FileSystem.mkdir(fs, path) do
      {:ok, new_fs} ->
        IO.puts("mkdir: created #{path}")
        new_fs

      {:error, reason} ->
        print_error("mkdir", reason)
        fs
    end
  end

  @doc "Create a file with optional content."
  @spec touch(FileSystem.t(), String.t(), String.t()) :: FileSystem.t()
  def touch(fs, path, content \\ "") do
    case FileSystem.create_file(fs, path, content) do
      {:ok, new_fs} ->
        IO.puts("touch: created #{path}")
        new_fs

      {:error, reason} ->
        print_error("touch", reason)
        fs
    end
  end

  @doc "Remove a file or empty directory."
  @spec rm(FileSystem.t(), String.t()) :: FileSystem.t()
  def rm(fs, path) do
    case FileSystem.rm(fs, path) do
      {:ok, new_fs} ->
        IO.puts("rm: removed #{path}")
        new_fs

      {:error, reason} ->
        print_error("rm", reason)
        fs
    end
  end

  @doc "Print directory tree."
  @spec tree(FileSystem.t(), String.t(), non_neg_integer()) :: FileSystem.t()
  def tree(fs, path \\ "/", depth \\ 3) do
    case FileSystem.tree(fs, path, depth) do
      {:ok, tree_node} -> render_tree(tree_node)
      {:error, reason} -> print_error("tree", reason)
    end

    fs
  end

  @doc "Show filesystem node metadata."
  @spec stat(FileSystem.t(), String.t()) :: FileSystem.t()
  def stat(fs, path) do
    case FileSystem.stat(fs, path) do
      {:ok, info} ->
        IO.puts("  path: #{info.path}")
        IO.puts("  type: #{info.type}")
        IO.puts("  size: #{info.size}")

      {:error, reason} ->
        print_error("stat", reason)
    end

    fs
  end

  # -- Tree rendering --

  @spec render_tree(FileSystem.tree_node()) :: :ok
  defp render_tree({name, :directory, children}) do
    IO.puts(name <> "/")
    render_children(children, "")
  end

  defp render_tree({name, :file, _children}) do
    IO.puts(name)
  end

  @spec render_children([FileSystem.tree_node()], String.t()) :: :ok
  defp render_children([], _prefix), do: :ok

  defp render_children(children, prefix) do
    last_idx = length(children) - 1

    children
    |> Enum.with_index()
    |> Enum.each(fn {child, idx} ->
      render_child(child, prefix, idx == last_idx)
    end)
  end

  @spec render_child(FileSystem.tree_node(), String.t(), boolean()) :: :ok
  defp render_child({name, type, grandchildren}, prefix, is_last?) do
    connector = if is_last?, do: "`-- ", else: "|-- "
    print_tree_node(prefix <> connector, name, type)
    next_prefix = prefix <> if(is_last?, do: "    ", else: "|   ")
    render_children(grandchildren, next_prefix)
  end

  @spec print_tree_node(String.t(), String.t(), FileSystem.node_type()) :: :ok
  defp print_tree_node(prefix, name, :directory) do
    IO.puts("#{prefix}#{@ansi_blue_bold}#{name}/#{@ansi_reset}")
  end

  defp print_tree_node(prefix, name, :file) do
    IO.puts("#{prefix}#{name}")
  end

  @spec print_error(String.t(), atom()) :: :ok
  defp print_error(command, reason) do
    IO.puts("#{@ansi_red}#{command}: #{format_error(reason)}#{@ansi_reset}")
  end

  @spec format_error(atom()) :: String.t()
  defp format_error(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> String.replace("_", " ")
  end
end
