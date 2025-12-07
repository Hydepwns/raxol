# Virtual File System

> [Documentation](../README.md) > [Features](README.md) > File System

In-memory filesystem with Unix commands.

## Usage

```elixir
alias Raxol.Commands.FileSystem

fs = FileSystem.new()
{:ok, fs} = FileSystem.mkdir(fs, "/documents")
{:ok, fs} = FileSystem.create_file(fs, "/readme.txt", "Hello")
{:ok, files, _} = FileSystem.ls(fs, "/")
{:ok, content, _} = FileSystem.cat(fs, "/readme.txt")
```

## Commands

```elixir
# ls - List directory
{:ok, contents, fs} = FileSystem.ls(fs, "/documents")

# cat - Read file
{:ok, content, fs} = FileSystem.cat(fs, "/readme.txt")

# cd - Change directory
{:ok, fs} = FileSystem.cd(fs, "/documents")
{:ok, fs} = FileSystem.cd(fs, "..")  # Parent
{:ok, fs} = FileSystem.cd(fs, "-")   # Previous

# pwd - Current directory
{:ok, path, fs} = FileSystem.pwd(fs)

# mkdir - Create directory
{:ok, fs} = FileSystem.mkdir(fs, "/projects")

# rm - Remove file/empty directory
{:ok, fs} = FileSystem.rm(fs, "/old.txt")
```

## Paths

```elixir
# Absolute
{:ok, fs} = FileSystem.cd(fs, "/documents/projects")

# Relative (from current directory)
{:ok, fs} = FileSystem.cd(fs, "subdirectory")
{:ok, fs} = FileSystem.cd(fs, "../other")
```

## File Operations

```elixir
# Create file
{:ok, fs} = FileSystem.create_file(fs, "/notes.txt", "content")

# Check existence
FileSystem.exists?(fs, "/notes.txt")  # => true

# Get metadata
{:ok, meta, fs} = FileSystem.stat(fs, "/notes.txt")
# meta.type => :file, meta.size => 7

# Directory tree
{:ok, tree, fs} = FileSystem.tree(fs, "/", 3)  # max depth 3
```

## Buffer Integration

```elixir
# Format directory listing
{:ok, contents, fs} = FileSystem.ls(fs, "/documents")
buffer = FileSystem.format_ls(contents, fs, "/documents")

# Format file contents
{:ok, content, fs} = FileSystem.cat(fs, "/readme.txt")
buffer = FileSystem.format_cat(content, 80, 24)
```

## Integration

```elixir
def handle_command(state, "ls " <> path) do
  case FileSystem.ls(state.fs, path) do
    {:ok, contents, fs} ->
      buffer = FileSystem.format_ls(contents, fs, path)
      %{state | fs: fs, buffer: buffer}
    {:error, reason} ->
      show_error(state, reason)
  end
end
```

Performance: ~10μs for directory listing
