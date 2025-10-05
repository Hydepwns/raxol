# VIM Navigation

VIM-style keybindings for terminal buffers.

## Usage

```elixir
alias Raxol.Navigation.Vim

vim = Vim.new(buffer)
{:ok, vim} = Vim.handle_key("j", vim)  # Move down
{:ok, vim} = Vim.handle_key("w", vim)  # Next word
{:ok, vim} = Vim.handle_key("/", vim)  # Search
```

## Commands

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| h/j/k/l | Left/Down/Up/Right | w/b/e | Word fwd/back/end |
| gg/G | Top/Bottom | 0/$ | Line start/end |
| / | Search forward | ? | Search backward |
| n/N | Next/Prev match | v | Visual mode |

## Configuration

```elixir
config = %{
  wrap_horizontal: true,
  wrap_vertical: false,
  word_separators: " .,;:!?",
  search_incremental: true
}

vim = Vim.new(buffer, config)
```

## Search

```elixir
# Start search
{:ok, vim} = Vim.handle_key("/", vim)
# Type pattern, press Enter
{:ok, vim} = Vim.handle_key("Enter", vim)
# Navigate matches
{:ok, vim} = Vim.handle_key("n", vim)
```

## Visual Mode

```elixir
{:ok, vim} = Vim.handle_key("v", vim)    # Enter visual
{:ok, vim} = Vim.handle_key("l", vim)    # Expand selection
{{x1, y1}, {x2, y2}} = Vim.get_selection(vim)
```

## Integration

```elixir
def handle_input(state, key) do
  {:ok, vim} = Vim.handle_key(key, state.vim)
  {x, y} = vim.cursor
  buffer = Buffer.set_cursor(state.buffer, x, y)
  %{state | vim: vim, buffer: buffer}
end
```

Performance: < 1μs per movement
