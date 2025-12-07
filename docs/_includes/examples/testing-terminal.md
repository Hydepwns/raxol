## Terminal Testing Example

```elixir
defmodule MyTerminalTest do
  use ExUnit.Case
  alias Raxol.Core.{Buffer, Box}

  test "renders correctly" do
    buffer = Buffer.create_blank_buffer(20, 10)
    buffer = Box.draw_box(buffer, 0, 0, 20, 10, :single)
    buffer = Buffer.write_at(buffer, 2, 2, "Test")

    # Verify structure
    assert buffer.width == 20
    assert buffer.height == 10

    # Verify content
    cell = Buffer.get_cell(buffer, 2, 2)
    assert cell.char == "T"
  end
end
```
