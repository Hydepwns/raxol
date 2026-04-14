# `Raxol.Terminal.ANSI.KittyParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/kitty_parser.ex#L1)

Handles the parsing logic for Kitty graphics protocol sequences.

The Kitty graphics protocol uses APC (Application Program Command) sequences
with the format: `<ESC>_G<control-data>;<payload><ESC>\`

## Control Data Format

Control data consists of key=value pairs separated by commas:
- `a` - Action: t (transmit), T (transmit+display), d (delete), etc.
- `f` - Format: 24 (RGB), 32 (RGBA), 100 (PNG)
- `o` - Compression: z (zlib)
- `t` - Transmission: d (direct), f (file), t (temp file), s (shared memory)
- `i` - Image ID
- `p` - Placement ID
- `q` - Quiet mode (0, 1, or 2)
- `s` - Width in pixels
- `v` - Height in pixels
- `m` - More data follows (0 or 1)

## Example

    iex> state = KittyParser.ParserState.new()
    iex> {:ok, state} = KittyParser.parse("a=t,f=32,s=100,v=100;base64data", state)

# `decode_base64_payload`

```elixir
@spec decode_base64_payload(binary()) :: {:ok, binary()} | {:error, :invalid_base64}
```

Decode a base64-encoded payload.

## Examples

    iex> {:ok, decoded} = KittyParser.decode_base64_payload("SGVsbG8=")
    iex> decoded
    "Hello"

# `decompress`

```elixir
@spec decompress(binary(), Raxol.Terminal.ANSI.KittyParser.ParserState.compression()) ::
  {:ok, binary()} | {:error, term()}
```

Decompress data if compression is enabled.

## Examples

    iex> compressed = :zlib.compress("test data")
    iex> {:ok, decompressed} = KittyParser.decompress(compressed, :zlib)
    iex> decompressed
    "test data"

# `extract_png_dimensions`

```elixir
@spec extract_png_dimensions(binary()) ::
  {:ok, {pos_integer(), pos_integer()}} | {:error, :invalid_png}
```

Extract image dimensions from PNG data.

PNG header format: 8-byte signature + IHDR chunk with width/height.

# `handle_chunked_data`

```elixir
@spec handle_chunked_data(binary(), Raxol.Terminal.ANSI.KittyParser.ParserState.t()) ::
  Raxol.Terminal.ANSI.KittyParser.ParserState.t()
```

Handle chunked data accumulation for multi-part transmissions.

When `m=1` is set, data is accumulated. When `m=0`, the complete
data is finalized.

## Examples

    iex> state = %ParserState{more_data: true, chunk_data: "part1"}
    iex> state = KittyParser.handle_chunked_data("part2", state)
    iex> state.chunk_data
    "part1part2"

# `parse`

```elixir
@spec parse(binary(), Raxol.Terminal.ANSI.KittyParser.ParserState.t()) ::
  {:ok, Raxol.Terminal.ANSI.KittyParser.ParserState.t()}
  | {:error, atom(), Raxol.Terminal.ANSI.KittyParser.ParserState.t()}
```

Parse a Kitty graphics sequence.

Expects data in the format: `<control-data>;<payload>` (without the APC wrapper).

## Examples

    iex> state = KittyParser.ParserState.new()
    iex> {:ok, state} = KittyParser.parse("a=t,f=32,s=100,v=100;base64data", state)
    iex> state.action
    :transmit

# `parse_control_data`

```elixir
@spec parse_control_data(binary(), Raxol.Terminal.ANSI.KittyParser.ParserState.t()) ::
  {:ok, Raxol.Terminal.ANSI.KittyParser.ParserState.t()}
  | {:error, atom(), Raxol.Terminal.ANSI.KittyParser.ParserState.t()}
```

Parse only the control data portion of a Kitty sequence.

## Examples

    iex> {:ok, state} = KittyParser.parse_control_data("a=t,f=32,s=100,v=100", %ParserState{})
    iex> state.action
    :transmit

---

*Consult [api-reference.md](api-reference.md) for complete listing*
