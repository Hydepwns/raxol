# `Raxol.Terminal.Buffer.LineOperations.Utils`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/line_operations/utils.ex#L1)

Shared utility functions for line operations.
Extracted to eliminate code duplication between Deletion and Insertion modules.

# `fill_new_lines`

```elixir
@spec fill_new_lines(map(), non_neg_integer(), non_neg_integer(), map() | nil) ::
  map()
```

Fills new lines in the buffer with empty cells.

## Parameters
  - buffer: The buffer to modify
  - start_y: Starting line index
  - count: Number of lines to fill
  - style: Style to apply to new cells

## Returns
  Updated buffer with filled lines

---

*Consult [api-reference.md](api-reference.md) for complete listing*
