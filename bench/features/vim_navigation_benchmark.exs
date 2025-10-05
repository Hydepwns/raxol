
# VIM Navigation Performance Benchmark
# Target: All operations < 100μs for responsive navigation

alias Raxol.Navigation.Vim
alias Raxol.Core.Buffer

buffer = Buffer.create_blank_buffer(80, 24)
buffer = Buffer.write_at(buffer, 0, 0, "Hello World")
buffer = Buffer.write_at(buffer, 0, 1, "Second line here")
buffer = Buffer.write_at(buffer, 0, 2, "Third line with more text")

vim = Vim.new(buffer)

Benchee.run(
  %{
    "new/1" => fn ->
      Vim.new(buffer)
    end,
    "handle_key (h)" => fn ->
      vim = %{vim | cursor: {5, 5}}
      Vim.handle_key("h", vim)
    end,
    "handle_key (j)" => fn ->
      Vim.handle_key("j", vim)
    end,
    "handle_key (k)" => fn ->
      vim = %{vim | cursor: {5, 5}}
      Vim.handle_key("k", vim)
    end,
    "handle_key (l)" => fn ->
      Vim.handle_key("l", vim)
    end,
    "handle_key (w)" => fn ->
      Vim.handle_key("w", vim)
    end,
    "handle_key (b)" => fn ->
      vim = %{vim | cursor: {10, 0}}
      Vim.handle_key("b", vim)
    end,
    "handle_key (gg)" => fn ->
      vim = %{vim | cursor: {10, 10}}
      Vim.handle_key("gg", vim)
    end,
    "handle_key (G)" => fn ->
      Vim.handle_key("G", vim)
    end,
    "handle_key (0)" => fn ->
      vim = %{vim | cursor: {10, 5}}
      Vim.handle_key("0", vim)
    end,
    "handle_key ($)" => fn ->
      Vim.handle_key("$", vim)
    end,
    "enter visual mode (v)" => fn ->
      Vim.handle_key("v", vim)
    end,
    "enter search mode (/)" => fn ->
      Vim.handle_key("/", vim)
    end,
    "get_selection" => fn ->
      vim_visual = %{vim | mode: :visual, visual_start: {0, 0}, cursor: {10, 0}}
      Vim.get_selection(vim_visual)
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
IO.puts("Target: All operations < 100μs")
IO.puts("\nMeasuring key operations:")

measurements = [
  {"new", fn -> Vim.new(buffer) end},
  {"movement (h)", fn ->
    vim = %{vim | cursor: {5, 5}}
    Vim.handle_key("h", vim)
  end},
  {"movement (j)", fn -> Vim.handle_key("j", vim) end},
  {"word jump (w)", fn -> Vim.handle_key("w", vim) end},
  {"line jump (gg)", fn ->
    vim = %{vim | cursor: {10, 10}}
    Vim.handle_key("gg", vim)
  end}
]

results = Enum.map(measurements, fn {name, func} ->
  {time_us, _result} = :timer.tc(func)
  status = if time_us < 100, do: "PASS", else: "FAIL"
  IO.puts("  #{name}: #{time_us}μs [#{status}]")
  {name, time_us < 100}
end)

all_passed = Enum.all?(results, fn {_name, passed} -> passed end)

if all_passed do
  IO.puts("\n[OK] All performance targets met!")
else
  IO.puts("\n[FAIL] Some performance targets not met")
end
