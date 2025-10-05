
# Command Parser Performance Benchmark
# Target: Parsing < 50μs, execution < 100μs

alias Raxol.Command.Parser

parser = Parser.new()
  |> Parser.register_command("echo", fn args -> {:ok, Enum.join(args, " ")} end)
  |> Parser.register_command("add", fn args ->
    sum = args |> Enum.map(&String.to_integer/1) |> Enum.sum()
    {:ok, sum}
  end)
  |> Parser.register_command("test", fn _args -> {:ok, "test"} end)
  |> Parser.register_alias("e", "echo")

Benchee.run(
  %{
    "new/0" => fn ->
      Parser.new()
    end,
    "register_command" => fn ->
      Parser.new()
      |> Parser.register_command("cmd", fn _ -> {:ok, ""} end)
    end,
    "register_alias" => fn ->
      Parser.new()
      |> Parser.register_command("list", fn _ -> {:ok, ""} end)
      |> Parser.register_alias("ls", "list")
    end,
    "parse_and_execute (simple)" => fn ->
      Parser.parse_and_execute(parser, "echo hello")
    end,
    "parse_and_execute (args)" => fn ->
      Parser.parse_and_execute(parser, "echo hello world test")
    end,
    "parse_and_execute (quoted)" => fn ->
      Parser.parse_and_execute(parser, ~s(echo "hello world" test))
    end,
    "parse_and_execute (numeric)" => fn ->
      Parser.parse_and_execute(parser, "add 10 20 30 40")
    end,
    "parse_and_execute (alias)" => fn ->
      Parser.parse_and_execute(parser, "e hello")
    end,
    "handle_key (char)" => fn ->
      Parser.handle_key(parser, "h")
    end,
    "handle_key (Backspace)" => fn ->
      p = %{parser | input: "hello", cursor_pos: 5}
      Parser.handle_key(p, "Backspace")
    end,
    "handle_key (Tab)" => fn ->
      p = %{parser | input: "ec"}
      Parser.handle_key(p, "Tab")
    end,
    "handle_key (ArrowUp)" => fn ->
      p = %{parser | history: ["cmd1", "cmd2", "cmd3"]}
      Parser.handle_key(p, "ArrowUp")
    end,
    "get_input" => fn ->
      Parser.get_input(parser)
    end,
    "get_history" => fn ->
      Parser.get_history(parser)
    end,
    "get_completions" => fn ->
      Parser.get_completions(parser)
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
IO.puts("Target: Parsing < 50μs, execution < 100μs")
IO.puts("\nMeasuring key operations:")

measurements = [
  {"new", fn -> Parser.new() end},
  {"parse simple", fn -> Parser.parse_and_execute(parser, "echo hello") end},
  {"parse with args", fn -> Parser.parse_and_execute(parser, "echo hello world test") end},
  {"parse quoted", fn -> Parser.parse_and_execute(parser, ~s(echo "hello world")) end},
  {"handle key", fn -> Parser.handle_key(parser, "h") end},
  {"tab completion", fn ->
    p = %{parser | input: "ec"}
    Parser.handle_key(p, "Tab")
  end}
]

results = Enum.map(measurements, fn {name, func} ->
  {time_us, _result} = :timer.tc(func)
  target = if String.contains?(name, "parse"), do: 100, else: 50
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
