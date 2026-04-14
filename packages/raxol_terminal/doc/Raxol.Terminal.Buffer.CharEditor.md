# `Raxol.Terminal.Buffer.CharEditor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/char_editor.ex#L1)

Manages terminal character editing operations.

# `char_width`

Gets the width of a character.

# `content_length`

Determines the content length of a line (number of non-blank characters).

# `control_char?`

Checks if a character is a control character.

# `delete_char`

Deletes a character at the current position.

# `delete_characters`

```elixir
@spec delete_characters(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  Raxol.Terminal.ANSI.TextFormatting.text_style()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Deletes a specified number of characters starting from the given position.
Characters to the right of the deleted characters are shifted left.
Blank characters are added at the end of the line with the specified style.

## Parameters

* `buffer` - The screen buffer to modify
* `row` - The row to delete characters from
* `col` - The column to start deleting from
* `count` - The number of characters to delete
* `default_style` - The style to apply to new blank characters

## Returns

The updated screen buffer.

# `delete_chars`

```elixir
@spec delete_chars(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Deletes a specified number of characters starting from the given position.
Characters to the right of the deleted characters are shifted left.
Blank characters are added at the end of the line.

## Parameters

* `buffer` - The screen buffer to modify
* `row` - The row to delete characters from
* `col` - The column to start deleting from
* `count` - The number of characters to delete

## Returns

The updated screen buffer.

# `delete_from_line`

```elixir
@spec delete_from_line(
  [Raxol.Terminal.Cell.t()],
  non_neg_integer(),
  non_neg_integer(),
  Raxol.Terminal.ANSI.TextFormatting.text_style()
) :: [Raxol.Terminal.Cell.t()]
```

Deletes characters from a line at the specified position.

## Parameters

* `line` - The line to modify
* `col` - The column to start deleting from
* `count` - The number of characters to delete
* `default_style` - The style to apply to new blank characters

## Returns

The updated line with deleted characters replaced by blanks.

## Examples

    iex> line = List.duplicate(%Cell{}, 10)
    iex> style = %{fg: :red, bg: :blue}
    iex> new_line = CharEditor.delete_from_line(line, 5, 3, style)
    iex> length(new_line)
    10

# `delete_string`

Deletes a string of characters.

# `erase_chars`

```elixir
@spec erase_chars(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Erases a specified number of characters starting from the given position.
Characters to the right of the erased characters are shifted left.
Blank characters are added at the end of the line.

## Parameters

* `buffer` - The screen buffer to modify
* `row` - The row to erase characters from
* `col` - The column to start erasing from
* `count` - The number of characters to erase

## Returns

The updated screen buffer.

# `erase_chars`

```elixir
@spec erase_chars(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  Raxol.Terminal.ANSI.TextFormatting.text_style()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Erases a specified number of characters starting from the given position with a specific style.
Characters to the right of the erased characters are shifted left.
Blank characters are added at the end of the line with the specified style.

## Parameters

* `buffer` - The screen buffer to modify
* `row` - The row to erase characters from
* `col` - The column to start erasing from
* `count` - The number of characters to erase
* `style` - The style to apply to new blank characters

## Returns

The updated screen buffer.

# `insert_char`

Inserts a character at the current position.

# `insert_characters`

```elixir
@spec insert_characters(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  Raxol.Terminal.ANSI.TextFormatting.text_style()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Inserts a specified number of characters at the given position.
Characters to the right of the insertion point are shifted right.
Characters shifted off the end of the line are discarded.
Uses the provided default style for new characters.

## Parameters

* `buffer` - The screen buffer to modify
* `row` - The row to insert characters in
* `col` - The column to start inserting at
* `count` - The number of characters to insert
* `default_style` - The style to apply to new characters

## Returns

The updated screen buffer.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> style = %{fg: :red, bg: :blue}
    iex> buffer = CharEditor.insert_characters(buffer, 0, 0, 5, style)
    iex> CharEditor.get_char(buffer, 0, 0)
    " "

# `insert_chars`

```elixir
@spec insert_chars(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: Raxol.Terminal.ScreenBuffer.t()
```

Inserts a specified number of characters at the given position.
Characters to the right of the insertion point are shifted right.
Characters shifted off the end of the line are discarded.

## Parameters

* `buffer` - The screen buffer to modify
* `row` - The row to insert characters in
* `col` - The column to start inserting at
* `count` - The number of characters to insert

## Returns

The updated screen buffer.

# `insert_into_line`

```elixir
@spec insert_into_line(
  [Raxol.Terminal.Cell.t()],
  non_neg_integer(),
  non_neg_integer(),
  Raxol.Terminal.ANSI.TextFormatting.text_style()
) :: [Raxol.Terminal.Cell.t()]
```

Inserts characters into a line at the specified position.

## Parameters

* `line` - The line to modify
* `col` - The column to start inserting at
* `count` - The number of characters to insert
* `default_style` - The style to apply to new characters

## Returns

The updated line with inserted characters.

## Examples

    iex> line = List.duplicate(%Cell{}, 10)
    iex> style = %{fg: :red, bg: :blue}
    iex> new_line = CharEditor.insert_into_line(line, 5, 3, style)
    iex> length(new_line)
    10

# `insert_string`

Inserts a string of characters.

# `printable_char?`

Checks if a character is a printable character.

# `replace_char`

Replaces a character at the current position.

# `replace_chars`

# `replace_string`

Replaces a string of characters.

# `string_width`

Gets the width of a string.

# `truncate_to_content_length`

Truncates a line to the specified content length, padding with blank cells if needed.

# `update_line_with_string`

# `whitespace_char?`

Checks if a character is a whitespace character.

# `write_char`

Writes a character at the specified position in the buffer.

# `write_string`

Writes a string at the specified position in the buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
