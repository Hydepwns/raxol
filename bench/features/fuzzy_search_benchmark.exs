
# Fuzzy Search Performance Benchmark
# Target: Search < 5ms for 1000 lines, update < 1ms

alias Raxol.Search.Fuzzy
alias Raxol.Core.Buffer

# Create buffer with substantial content
buffer = Buffer.create_blank_buffer(80, 100)

buffer = Enum.reduce(0..99, buffer, fn i, acc ->
  text = case rem(i, 4) do
    0 -> "Hello World from line #{i}"
    1 -> "Testing search functionality"
    2 -> "Lorem ipsum dolor sit amet"
    3 -> "Quick brown fox jumps over lazy dog"
  end
  Buffer.write_at(acc, 0, i, text)
end)

search = Fuzzy.new(buffer)
search_with_matches = Fuzzy.update_query(search, "hello")

Benchee.run(
  %{
    "new/1" => fn ->
      Fuzzy.new(buffer)
    end,
    "search (fuzzy, short)" => fn ->
      Fuzzy.search(buffer, "hlo", :fuzzy)
    end,
    "search (fuzzy, medium)" => fn ->
      Fuzzy.search(buffer, "hello", :fuzzy)
    end,
    "search (fuzzy, long)" => fn ->
      Fuzzy.search(buffer, "hello world", :fuzzy)
    end,
    "search (exact, short)" => fn ->
      Fuzzy.search(buffer, "hello", :exact)
    end,
    "search (exact, long)" => fn ->
      Fuzzy.search(buffer, "Hello World", :exact)
    end,
    "search (regex, simple)" => fn ->
      Fuzzy.search(buffer, ~r/H\w+/, :regex)
    end,
    "search (regex, complex)" => fn ->
      Fuzzy.search(buffer, ~r/[Hh]ello\s+\w+/, :regex)
    end,
    "update_query" => fn ->
      Fuzzy.update_query(search, "test")
    end,
    "next_match" => fn ->
      Fuzzy.next_match(search_with_matches)
    end,
    "previous_match" => fn ->
      Fuzzy.previous_match(search_with_matches)
    end,
    "get_current_match" => fn ->
      Fuzzy.get_current_match(search_with_matches)
    end,
    "get_all_matches" => fn ->
      Fuzzy.get_all_matches(search_with_matches)
    end,
    "highlight_matches" => fn ->
      results = Fuzzy.search(buffer, "hello", :exact)
      Fuzzy.highlight_matches(buffer, results)
    end,
    "get_stats" => fn ->
      Fuzzy.get_stats(search_with_matches)
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
IO.puts("Target: Search < 5ms (5000μs), navigation < 1ms")
IO.puts("\nMeasuring key operations:")

measurements = [
  {"fuzzy search (short)", fn -> Fuzzy.search(buffer, "hlo", :fuzzy) end},
  {"fuzzy search (long)", fn -> Fuzzy.search(buffer, "hello world", :fuzzy) end},
  {"exact search", fn -> Fuzzy.search(buffer, "hello", :exact) end},
  {"regex search", fn -> Fuzzy.search(buffer, ~r/H\w+/, :regex) end},
  {"update query", fn -> Fuzzy.update_query(search, "test") end},
  {"next match", fn -> Fuzzy.next_match(search_with_matches) end},
  {"highlight", fn ->
    results = Fuzzy.search(buffer, "hello", :exact)
    Fuzzy.highlight_matches(buffer, results)
  end}
]

results = Enum.map(measurements, fn {name, func} ->
  {time_us, _result} = :timer.tc(func)
  target = if String.contains?(name, "search"), do: 5000, else: 1000
  status = if time_us < target, do: "PASS", else: "FAIL"
  IO.puts("  #{name}: #{time_us}μs [#{status}]")
  {name, time_us < target}
end)

all_passed = Enum.all?(results, fn {_name, passed} -> passed end)

if all_passed do
  IO.puts("\n[OK] All performance targets met!")
else
  IO.puts("\n[FAIL] Some performance targets not met")
end
