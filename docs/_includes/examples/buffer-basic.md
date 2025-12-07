## Basic Buffer Example

```elixir
alias Raxol.Core.{Buffer, Box}

# Create buffer
buffer = Buffer.create_blank_buffer(40, 10)

# Draw box
buffer = Box.draw_box(buffer, 0, 0, 40, 10, :double)

# Write text
buffer = Buffer.write_at(buffer, 5, 4, "Hello, Raxol!")

# Render
IO.puts(Buffer.to_string(buffer))
```

Output:
```
╔══════════════════════════════════════╗
║                                      ║
║                                      ║
║                                      ║
║     Hello, Raxol!                    ║
║                                      ║
║                                      ║
║                                      ║
║                                      ║
╚══════════════════════════════════════╝
```
