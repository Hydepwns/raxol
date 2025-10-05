
# Virtual FileSystem Performance Benchmark
# Target: All operations < 500μs for responsive file operations

alias Raxol.Commands.FileSystem

# Create a filesystem with some structure
fs = FileSystem.new()
{:ok, fs} = FileSystem.mkdir(fs, "/documents")
{:ok, fs} = FileSystem.mkdir(fs, "/documents/work")
{:ok, fs} = FileSystem.mkdir(fs, "/documents/personal")
{:ok, fs} = FileSystem.mkdir(fs, "/projects")
{:ok, fs} = FileSystem.create_file(fs, "/readme.txt", "Hello World")
{:ok, fs} = FileSystem.create_file(fs, "/documents/notes.txt", "Some notes here")
{:ok, fs} = FileSystem.create_file(fs, "/documents/work/todo.txt", "Tasks to do")

Benchee.run(
  %{
    "new/0" => fn ->
      FileSystem.new()
    end,
    "mkdir (root)" => fn ->
      FileSystem.mkdir(fs, "/newdir")
    end,
    "mkdir (nested)" => fn ->
      FileSystem.mkdir(fs, "/documents/subdir")
    end,
    "create_file (small)" => fn ->
      FileSystem.create_file(fs, "/test.txt", "content")
    end,
    "create_file (large)" => fn ->
      content = String.duplicate("test ", 100)
      FileSystem.create_file(fs, "/large.txt", content)
    end,
    "ls (root)" => fn ->
      FileSystem.ls(fs, "/")
    end,
    "ls (subdirectory)" => fn ->
      FileSystem.ls(fs, "/documents")
    end,
    "cat (small)" => fn ->
      FileSystem.cat(fs, "/readme.txt")
    end,
    "cat (nested)" => fn ->
      FileSystem.cat(fs, "/documents/work/todo.txt")
    end,
    "cd (absolute)" => fn ->
      FileSystem.cd(fs, "/documents/work")
    end,
    "cd (relative)" => fn ->
      {:ok, fs_at_docs} = FileSystem.cd(fs, "/documents")
      FileSystem.cd(fs_at_docs, "work")
    end,
    "cd (parent)" => fn ->
      {:ok, fs_at_work} = FileSystem.cd(fs, "/documents/work")
      FileSystem.cd(fs_at_work, "..")
    end,
    "cd (previous)" => fn ->
      {:ok, fs_at_docs} = FileSystem.cd(fs, "/documents")
      {:ok, fs_at_root} = FileSystem.cd(fs_at_docs, "/")
      FileSystem.cd(fs_at_root, "-")
    end,
    "pwd" => fn ->
      FileSystem.pwd(fs)
    end,
    "rm (file)" => fn ->
      {:ok, fs_with_file} = FileSystem.create_file(fs, "/temp.txt", "temp")
      FileSystem.rm(fs_with_file, "/temp.txt")
    end,
    "rm (empty dir)" => fn ->
      {:ok, fs_with_dir} = FileSystem.mkdir(fs, "/tempdir")
      FileSystem.rm(fs_with_dir, "/tempdir")
    end,
    "stat (file)" => fn ->
      FileSystem.stat(fs, "/readme.txt")
    end,
    "stat (directory)" => fn ->
      FileSystem.stat(fs, "/documents")
    end,
    "exists? (true)" => fn ->
      FileSystem.exists?(fs, "/readme.txt")
    end,
    "exists? (false)" => fn ->
      FileSystem.exists?(fs, "/nonexistent")
    end,
    "tree (depth 1)" => fn ->
      FileSystem.tree(fs, "/", 1)
    end,
    "tree (depth 3)" => fn ->
      FileSystem.tree(fs, "/", 3)
    end,
    "format_ls" => fn ->
      {:ok, entries, _} = FileSystem.ls(fs, "/")
      FileSystem.format_ls(entries, fs, "/")
    end,
    "format_cat" => fn ->
      content = "Line 1\nLine 2\nLine 3"
      FileSystem.format_cat(content, 80, 24)
    end
  },
  time: 2,
  memory_time: 1,
  print: [
    fast_warning: false,
    configuration: false
  ]
)

# Performance validation
IO.puts("\n\n=== Performance Target Validation ===")
IO.puts("Target: All operations < 500μs")
IO.puts("\nMeasuring key operations:")

measurements = [
  {"new", fn -> FileSystem.new() end},
  {"mkdir", fn -> FileSystem.mkdir(fs, "/testdir") end},
  {"create_file", fn -> FileSystem.create_file(fs, "/test.txt", "content") end},
  {"ls", fn -> FileSystem.ls(fs, "/") end},
  {"cat", fn -> FileSystem.cat(fs, "/readme.txt") end},
  {"cd", fn -> FileSystem.cd(fs, "/documents") end},
  {"pwd", fn -> FileSystem.pwd(fs) end},
  {"stat", fn -> FileSystem.stat(fs, "/readme.txt") end},
  {"exists?", fn -> FileSystem.exists?(fs, "/readme.txt") end},
  {"tree", fn -> FileSystem.tree(fs, "/", 2) end}
]

results = Enum.map(measurements, fn {name, func} ->
  {time_us, _result} = :timer.tc(func)
  status = if time_us < 500, do: "PASS", else: "FAIL"
  IO.puts("  #{name}: #{time_us}μs [#{status}]")
  {name, time_us < 500}
end)

all_passed = Enum.all?(results, fn {_name, passed} -> passed end)

if all_passed do
  IO.puts("\n[OK] All performance targets met!")
else
  IO.puts("\n[FAIL] Some performance targets not met")
end
