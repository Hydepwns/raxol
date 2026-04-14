# `Raxol.Terminal.ScreenBuffer.DataAdapter`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer/data_adapter.ex#L1)

Data structure adapter for ScreenBuffer operations.

Provides bidirectional conversion between the two buffer formats:
- ScreenBuffer.Core format: `:cells` (list of lists of Cell structs)
- LineOperations format: `:lines` (map with integer keys to line lists)

This adapter allows seamless interoperability between different buffer
operation layers without requiring architectural changes.

# `cells_to_lines`

Convert buffer from cells format to lines format.

Transforms `buffer.cells` (list of lists) into a `:lines` map
where keys are row indices and values are cell lists.

# `create_empty_cells`

Create empty cells structure for initialization.

# `create_empty_line`

Create an empty line with the specified width and style.

# `get_line`

Get a line from buffer regardless of format.

# `has_cells_format?`

Check if buffer uses cells format (list of lists).

# `has_lines_format?`

Check if buffer uses lines format (map).

# `lines_to_cells`

Convert buffer from lines format back to cells format.

Transforms `:lines` map back into `buffer.cells` (list of lists).

# `set_line`

Set a line in buffer regardless of format.

# `with_lines_format`

Execute an operation function with the buffer temporarily in lines format.

This is the key function that allows LineOperations to work with
ScreenBuffer.Core structures without permanent conversion.

The operation function can return either:
- A modified buffer map
- A tuple where the second element is the modified buffer map

---

*Consult [api-reference.md](api-reference.md) for complete listing*
