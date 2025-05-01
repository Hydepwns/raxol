# SingleLineInput Syntax Error (`after` keyword)

Date: 2024-06-05
File: `lib/raxol/components/input/single_line_input.ex`

## Issue

Compilation failed repeatedly with a `SyntaxError: syntax error before: '='` pointing to the line where the `after` variable was assigned, even though the syntax appeared correct.

## Problematic Code Snippet (within `render/2`)

```elixir
    # Render with cursor if focused
    rendered_content = if state.focused do
      before = String.slice(display_text, 0, state.cursor_pos)
      after_cursor = String.slice(display_text, state.cursor_pos..-1)
      # Use simple characters, assume fixed width font
      [Raxol.View.Elements.label(before), Raxol.View.Elements.label("|"), Raxol.View.Elements.label(after_cursor)]
    else
      Raxol.View.Elements.label(display_text)
    end
```

## Diagnosis

The variable name `after` conflicts with the `after` keyword used in `try...catch...after` blocks, causing a syntax error when used within the `if` statement.

## Resolution

Renamed the variable `after` to `after_cursor`.
