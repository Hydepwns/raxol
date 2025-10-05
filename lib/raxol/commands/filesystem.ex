defmodule Raxol.Commands.FileSystem do
  @moduledoc """
  Virtual file system for terminal navigation and content display.

  Provides familiar file system commands for navigating terminal buffers:
  - ls - List directory contents
  - cat - Display file content
  - cd - Change current directory
  - pwd - Print working directory
  - mkdir - Create directory

  ## Example

      fs = FileSystem.new()
      fs = FileSystem.mkdir(fs, "/documents")
      fs = FileSystem.create_file(fs, "/documents/readme.txt", "Hello World")

      {:ok, contents, _fs} = FileSystem.ls(fs, "/documents")
      # => ["readme.txt"]

      {:ok, content, _fs} = FileSystem.cat(fs, "/documents/readme.txt")
      # => "Hello World"

  ## Virtual Filesystem

  The filesystem is a tree structure stored in memory:
  - Directories are maps with entries
  - Files have content and metadata
  - Paths are Unix-style (absolute or relative)
  """

  alias Raxol.Core.Buffer

  @type path :: String.t()
  @type entry_type :: :file | :directory
  @type metadata :: %{
          type: entry_type(),
          created: DateTime.t(),
          modified: DateTime.t(),
          size: non_neg_integer()
        }

  @type file_entry :: %{
          type: :file,
          content: String.t(),
          metadata: metadata()
        }

  @type dir_entry :: %{
          type: :directory,
          entries: %{String.t() => file_entry() | dir_entry()},
          metadata: metadata()
        }

  @type t :: %__MODULE__{
          root: dir_entry(),
          cwd: path(),
          history: list(path())
        }

  defstruct root: nil,
            cwd: "/",
            history: ["/"]

  @doc """
  Create a new virtual filesystem.
  """
  @spec new() :: t()
  def new do
    now = DateTime.utc_now()

    root = %{
      type: :directory,
      entries: %{},
      metadata: %{
        type: :directory,
        created: now,
        modified: now,
        size: 0
      }
    }

    %__MODULE__{
      root: root,
      cwd: "/",
      history: ["/"]
    }
  end

  @doc """
  List directory contents.
  """
  @spec ls(t(), path() | nil) ::
          {:ok, list(String.t()), t()} | {:error, String.t()}
  def ls(fs, path \\ nil) do
    target_path = resolve_path(fs, path)

    case get_entry(fs, target_path) do
      {:ok, %{type: :directory, entries: entries}} ->
        contents =
          entries
          |> Map.keys()
          |> Enum.sort()

        {:ok, contents, fs}

      {:ok, %{type: :file}} ->
        {:error, "Not a directory: #{target_path}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Display file contents.
  """
  @spec cat(t(), path()) :: {:ok, String.t(), t()} | {:error, String.t()}
  def cat(fs, path) do
    target_path = resolve_path(fs, path)

    case get_entry(fs, target_path) do
      {:ok, %{type: :file, content: content}} ->
        {:ok, content, fs}

      {:ok, %{type: :directory}} ->
        {:error, "Is a directory: #{target_path}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Change current directory.
  """
  @spec cd(t(), path() | nil) :: {:ok, t()} | {:error, String.t()}
  def cd(fs, path \\ nil) do
    target_path =
      case path do
        nil -> "/"
        "-" -> List.first(fs.history) || "/"
        p -> resolve_path(fs, p)
      end

    case get_entry(fs, target_path) do
      {:ok, %{type: :directory}} ->
        new_history = [fs.cwd | Enum.take(fs.history, 9)]
        {:ok, %{fs | cwd: target_path, history: new_history}}

      {:ok, %{type: :file}} ->
        {:error, "Not a directory: #{target_path}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Print working directory.
  """
  @spec pwd(t()) :: {:ok, path(), t()}
  def pwd(fs) do
    {:ok, fs.cwd, fs}
  end

  @doc """
  Create a new directory.
  """
  @spec mkdir(t(), path()) :: {:ok, t()} | {:error, String.t()}
  def mkdir(fs, path) do
    target_path = resolve_path(fs, path)

    case get_entry(fs, target_path) do
      {:ok, _entry} ->
        {:error, "Already exists: #{target_path}"}

      {:error, _} ->
        case create_directory(fs, target_path) do
          {:ok, new_root} ->
            {:ok, %{fs | root: new_root}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Create a new file with content.
  """
  @spec create_file(t(), path(), String.t()) ::
          {:ok, t()} | {:error, String.t()}
  def create_file(fs, path, content) do
    target_path = resolve_path(fs, path)

    case get_entry(fs, target_path) do
      {:ok, _entry} ->
        {:error, "Already exists: #{target_path}"}

      {:error, _} ->
        case create_file_entry(fs, target_path, content) do
          {:ok, new_root} ->
            {:ok, %{fs | root: new_root}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Remove a file or empty directory.
  """
  @spec rm(t(), path()) :: {:ok, t()} | {:error, String.t()}
  def rm(fs, path) do
    target_path = resolve_path(fs, path)

    if target_path == "/" do
      {:error, "Cannot remove root directory"}
    else
      case get_entry(fs, target_path) do
        {:ok, %{type: :directory, entries: entries}}
        when map_size(entries) > 0 ->
          {:error, "Directory not empty: #{target_path}"}

        {:ok, _entry} ->
          case remove_entry(fs, target_path) do
            {:ok, new_root} ->
              {:ok, %{fs | root: new_root}}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Format directory listing as a buffer.
  """
  @spec format_ls(list(String.t()), t(), path()) :: Buffer.t()
  def format_ls(entries, fs, path) do
    buffer = Buffer.create_blank_buffer(80, length(entries) + 2)
    resolved_path = resolve_path(fs, path)

    buffer = Buffer.write_at(buffer, 0, 0, "Contents of #{resolved_path}:")

    entries
    |> Enum.with_index(1)
    |> Enum.reduce(buffer, fn {entry, idx}, buf ->
      entry_path = Path.join(resolved_path, entry)

      case get_entry(fs, entry_path) do
        {:ok, %{type: :directory}} ->
          Buffer.write_at(buf, 2, idx, "[DIR]  #{entry}")

        {:ok, %{type: :file, metadata: %{size: size}}} ->
          Buffer.write_at(buf, 2, idx, "[FILE] #{entry} (#{size} bytes)")

        {:error, _} ->
          Buffer.write_at(buf, 2, idx, "       #{entry}")
      end
    end)
  end

  @doc """
  Format file contents as a buffer.
  """
  @spec format_cat(String.t(), non_neg_integer(), non_neg_integer()) ::
          Buffer.t()
  def format_cat(content, width \\ 80, height \\ 24) do
    lines = String.split(content, "\n")
    buffer = Buffer.create_blank_buffer(width, height)

    lines
    |> Enum.take(height)
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, y}, buf ->
      trimmed_line = String.slice(line, 0, width - 1)
      Buffer.write_at(buf, 0, y, trimmed_line)
    end)
  end

  # Private functions

  defp resolve_path(%{cwd: cwd}, nil), do: cwd

  defp resolve_path(%{cwd: cwd}, path) do
    case path do
      "/" <> _ ->
        # Absolute path
        normalize_path(path)

      _ ->
        # Relative path
        normalize_path(Path.join(cwd, path))
    end
  end

  defp normalize_path(path) do
    path
    |> String.split("/")
    |> Enum.reject(&(&1 == "" or &1 == "."))
    |> Enum.reduce([], fn
      "..", [] ->
        []

      "..", acc ->
        tl(acc)

      segment, acc ->
        [segment | acc]
    end)
    |> Enum.reverse()
    |> case do
      [] -> "/"
      segments -> "/" <> Enum.join(segments, "/")
    end
  end

  defp get_entry(fs, "/"), do: {:ok, fs.root}

  defp get_entry(fs, path) do
    segments =
      path
      |> String.trim_leading("/")
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))

    traverse_path(fs.root, segments)
  end

  defp traverse_path(current, []), do: {:ok, current}

  defp traverse_path(%{type: :directory, entries: entries}, [segment | rest]) do
    case Map.get(entries, segment) do
      nil ->
        {:error, "No such file or directory: #{segment}"}

      entry ->
        traverse_path(entry, rest)
    end
  end

  defp traverse_path(%{type: :file}, _segments) do
    {:error, "Not a directory"}
  end

  defp create_directory(fs, path) do
    now = DateTime.utc_now()

    segments =
      path
      |> String.trim_leading("/")
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))

    new_dir = %{
      type: :directory,
      entries: %{},
      metadata: %{
        type: :directory,
        created: now,
        modified: now,
        size: 0
      }
    }

    update_at_path(fs.root, segments, new_dir, :create)
  end

  defp create_file_entry(fs, path, content) do
    now = DateTime.utc_now()

    segments =
      path
      |> String.trim_leading("/")
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))

    new_file = %{
      type: :file,
      content: content,
      metadata: %{
        type: :file,
        created: now,
        modified: now,
        size: byte_size(content)
      }
    }

    update_at_path(fs.root, segments, new_file, :create)
  end

  defp remove_entry(fs, path) do
    segments =
      path
      |> String.trim_leading("/")
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))

    update_at_path(fs.root, segments, nil, :delete)
  end

  defp update_at_path(root, [segment], new_entry, :create) do
    case root do
      %{type: :directory, entries: entries} = dir ->
        now = DateTime.utc_now()
        new_entries = Map.put(entries, segment, new_entry)

        updated_dir = %{
          dir
          | entries: new_entries,
            metadata: Map.put(dir.metadata, :modified, now)
        }

        {:ok, updated_dir}

      _ ->
        {:error, "Parent is not a directory"}
    end
  end

  defp update_at_path(root, [segment], _new_entry, :delete) do
    case root do
      %{type: :directory, entries: entries} = dir ->
        now = DateTime.utc_now()
        new_entries = Map.delete(entries, segment)

        updated_dir = %{
          dir
          | entries: new_entries,
            metadata: Map.put(dir.metadata, :modified, now)
        }

        {:ok, updated_dir}

      _ ->
        {:error, "Parent is not a directory"}
    end
  end

  defp update_at_path(root, [segment | rest], new_entry, operation) do
    case root do
      %{type: :directory, entries: entries} = dir ->
        child = Map.get(entries, segment)

        if child do
          case update_at_path(child, rest, new_entry, operation) do
            {:ok, updated_child} ->
              now = DateTime.utc_now()
              new_entries = Map.put(entries, segment, updated_child)

              updated_dir = %{
                dir
                | entries: new_entries,
                  metadata: Map.put(dir.metadata, :modified, now)
              }

              {:ok, updated_dir}

            {:error, reason} ->
              {:error, reason}
          end
        else
          # Need to create intermediate directory
          case operation do
            :create ->
              now = DateTime.utc_now()

              intermediate = %{
                type: :directory,
                entries: %{},
                metadata: %{
                  type: :directory,
                  created: now,
                  modified: now,
                  size: 0
                }
              }

              case update_at_path(intermediate, rest, new_entry, operation) do
                {:ok, updated_child} ->
                  new_entries = Map.put(entries, segment, updated_child)

                  updated_dir = %{
                    dir
                    | entries: new_entries,
                      metadata: Map.put(dir.metadata, :modified, now)
                  }

                  {:ok, updated_dir}

                {:error, reason} ->
                  {:error, reason}
              end

            :delete ->
              {:error, "Path not found"}
          end
        end

      _ ->
        {:error, "Not a directory"}
    end
  end

  @doc """
  Get file or directory metadata.
  """
  @spec stat(t(), path()) :: {:ok, metadata(), t()} | {:error, String.t()}
  def stat(fs, path) do
    target_path = resolve_path(fs, path)

    case get_entry(fs, target_path) do
      {:ok, %{metadata: metadata}} ->
        {:ok, metadata, fs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if path exists.
  """
  @spec exists?(t(), path()) :: boolean()
  def exists?(fs, path) do
    target_path = resolve_path(fs, path)

    case get_entry(fs, target_path) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Get directory tree as nested structure.
  """
  @spec tree(t(), path() | nil, non_neg_integer()) ::
          {:ok, list(), t()} | {:error, String.t()}
  def tree(fs, path \\ nil, max_depth \\ 3) do
    target_path = resolve_path(fs, path)

    case get_entry(fs, target_path) do
      {:ok, entry} ->
        tree_structure = build_tree(entry, "", max_depth, 0)
        {:ok, tree_structure, fs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_tree(
         %{type: :file, metadata: %{size: size}},
         name,
         _max_depth,
         _depth
       ) do
    {name, :file, size}
  end

  defp build_tree(%{type: :directory, entries: entries}, name, max_depth, depth)
       when depth >= max_depth do
    {name, :directory, map_size(entries)}
  end

  defp build_tree(%{type: :directory, entries: entries}, name, max_depth, depth) do
    children =
      entries
      |> Enum.map(fn {child_name, child_entry} ->
        build_tree(child_entry, child_name, max_depth, depth + 1)
      end)
      |> Enum.sort()

    {name, :directory, children}
  end
end
