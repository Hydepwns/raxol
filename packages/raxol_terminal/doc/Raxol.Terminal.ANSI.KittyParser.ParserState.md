# `Raxol.Terminal.ANSI.KittyParser.ParserState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/kitty_parser.ex#L30)

Represents the state during parsing of a Kitty graphics data stream.
Tracks control parameters, chunked data, and image buffers.

# `action`

```elixir
@type action() :: :transmit | :transmit_display | :display | :delete | :query | :frame
```

# `compression`

```elixir
@type compression() :: :none | :zlib
```

# `format`

```elixir
@type format() :: :rgb | :rgba | :png | :unknown
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.ANSI.KittyParser.ParserState{
  action: action(),
  cell_x: non_neg_integer() | nil,
  cell_y: non_neg_integer() | nil,
  chunk_data: binary(),
  compression: compression(),
  errors: [term()],
  format: format(),
  height: non_neg_integer() | nil,
  image_id: non_neg_integer() | nil,
  more_data: boolean(),
  pixel_buffer: binary(),
  placement_id: non_neg_integer() | nil,
  quiet: 0 | 1 | 2,
  raw_control: binary(),
  transmission: transmission(),
  width: non_neg_integer() | nil,
  x_offset: non_neg_integer(),
  y_offset: non_neg_integer(),
  z_index: integer()
}
```

# `transmission`

```elixir
@type transmission() :: :direct | :file | :temp_file | :shared_memory
```

# `new`

```elixir
@spec new() :: %Raxol.Terminal.ANSI.KittyParser.ParserState{
  action: :transmit,
  cell_x: nil,
  cell_y: nil,
  chunk_data: &lt;&lt;_::0&gt;&gt;,
  compression: :none,
  errors: [],
  format: :rgba,
  height: nil,
  image_id: nil,
  more_data: false,
  pixel_buffer: &lt;&lt;_::0&gt;&gt;,
  placement_id: nil,
  quiet: 0,
  raw_control: &lt;&lt;_::0&gt;&gt;,
  transmission: :direct,
  width: nil,
  x_offset: 0,
  y_offset: 0,
  z_index: 0
}
```

Create a new parser state with default values.

# `new`

```elixir
@spec new(pos_integer(), pos_integer()) :: t()
```

Create a new parser state with initial dimensions.

# `reset`

```elixir
@spec reset(t()) :: t()
```

Reset the parser state for a new image while preserving accumulated data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
