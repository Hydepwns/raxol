# Command Parser

> [Documentation](../README.md) > [Features](README.md) > Command Parser

CLI with tab completion, history, and argument parsing.

## Usage

```elixir
alias Raxol.Command.Parser

parser =
  Parser.new()
  |> Parser.register_command("echo", fn args ->
    {:ok, Enum.join(args, " ")}
  end)
  |> Parser.register_alias("e", "echo")

{:ok, result, parser} = Parser.parse_and_execute(parser, "echo Hello")
```

## Registration

```elixir
# Command with validation
parser = Parser.register_command(parser, "add", fn args ->
  case args do
    [a, b] ->
      {:ok, String.to_integer(a) + String.to_integer(b)}
    _ ->
      {:error, "Usage: add <n1> <n2>"}
  end
end)

# Alias
parser = Parser.register_alias(parser, "ls", "list")
```

## Arguments

```elixir
# Quoted strings
Parser.parse_and_execute(parser, ~s(echo "Hello World" test))
# args => ["Hello World", "test"]

# Multiple arguments
Parser.parse_and_execute(parser, "join one two three")
```

## Interactive Mode

```elixir
# Tab completion
parser = %{parser | input: "ech"}
parser = Parser.handle_key(parser, "Tab")  # Completes to "echo"

# History navigation
parser = Parser.handle_key(parser, "ArrowUp")    # Previous
parser = Parser.handle_key(parser, "ArrowDown")  # Next

# History search (Ctrl+R)
parser = Parser.handle_key(parser, "Ctrl+R")
# Type search query, press Enter

# Execute
parser = Parser.handle_key(parser, "Enter")
```

## Integration

```elixir
def handle_key(state, key) do
  parser = Parser.handle_key(state.parser, key)

  # Check if command executed
  case Parser.get_input(parser) do
    "" -> handle_result(state, parser)
    _ -> %{state | parser: parser}
  end
end
```

Performance: ~5μs per command
