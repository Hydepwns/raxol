# Features

> [Documentation](../README.md) > Features

Advanced terminal interface features from droodotfoo.

## Features

### [VIM Navigation](VIM_NAVIGATION.md)
VIM-style keybindings: h/j/k/l, gg/G, w/b/e, search, visual mode.

```elixir
vim = Vim.new(buffer)
{:ok, vim} = Vim.handle_key("j", vim)
```

### [Command Parser](COMMAND_PARSER.md)
CLI with tab completion, history, aliases, argument parsing.

```elixir
parser = Parser.new()
  |> Parser.register_command("echo", &echo/1)
{:ok, result, _} = Parser.parse_and_execute(parser, "echo hi")
```

### [Fuzzy Search](FUZZY_SEARCH.md)
Multi-mode search: fuzzy (fzf-style), exact, regex with highlighting.

```elixir
results = Fuzzy.search(buffer, "hlo", :fuzzy)  # Matches "hello"
```

### [File System](FILESYSTEM.md)
Virtual filesystem: ls, cat, cd, pwd, mkdir, rm with path resolution.

```elixir
fs = FileSystem.new()
{:ok, fs} = FileSystem.mkdir(fs, "/docs")
{:ok, files, _} = FileSystem.ls(fs, "/")
```

### [Cursor Effects](CURSOR_EFFECTS.md)
Visual trails and glow: configurable colors, presets, smooth interpolation.

```elixir
trail = CursorTrail.rainbow()
trail = CursorTrail.update(trail, {x, y})
buffer = CursorTrail.apply(trail, buffer)
```

## Combined Example

```elixir
defmodule Terminal do
  defstruct [:buffer, :vim, :parser, :search, :fs, :trail]

  def new do
    buffer = Buffer.create_blank_buffer(80, 24)
    %__MODULE__{
      buffer: buffer,
      vim: Vim.new(buffer),
      parser: Parser.new(),
      search: Fuzzy.new(buffer),
      fs: FileSystem.new(),
      trail: CursorTrail.rainbow()
    }
  end

  def handle_key(state, key) do
    {:ok, vim} = Vim.handle_key(key, state.vim)
    trail = CursorTrail.update(state.trail, vim.cursor)
    %{state | vim: vim, trail: trail}
  end
end
```

## Performance

| Feature | Operation | Time |
|---------|-----------|------|
| VIM | Movement | < 1μs |
| Parser | Execute | ~5μs |
| Search | 1000 lines | ~100μs |
| FileSystem | List dir | ~10μs |
| Trail | Update+apply | ~7μs |

Total: < 150μs per frame (60fps = 16ms budget)
