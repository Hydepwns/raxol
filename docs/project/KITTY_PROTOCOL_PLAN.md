# Kitty Graphics Protocol Implementation Plan

**Status**: Implemented
**Completed**: 2025-12-12
**Priority**: Low (defer to v2.2+)
**Created**: 2025-12-05

## Protocol Overview

Kitty Graphics Protocol enables pixel-level graphics rendering in terminals with features superior to Sixel:
- **Base Format**: `<ESC>_G<control data>;<payload><ESC>\` (APC sequence, NOT DCS)
- **Control Data**: Comma-separated key=value pairs
- **Payload**: Base64 encoded binary data
- **Key Advantage**: Native animation support, better compression, more flexible placement

> **IMPORTANT**: Kitty uses APC (Application Program Command) sequences starting with `ESC _`,
> not DCS (Device Control String) sequences. This is a key difference from Sixel which uses DCS.

## Architecture (Mirror Sixel Pattern)

```
KittyParser          -> Parses escape sequences (lib/raxol/terminal/ansi/kitty_parser.ex)
KittyGraphics        -> State management and encoding/decoding (lib/raxol/terminal/ansi/kitty_graphics.ex)
KittyAnimation       -> Frame sequencing and playback (lib/raxol/terminal/ansi/kitty_animation.ex)
ControlSequenceHandler -> Route APC to KittyGraphics.process_sequence/2
ImageRenderer        -> Plugin integration (create_kitty_cells)
```

## Implementation Status

### Completed Modules

| Module | File | Status |
|--------|------|--------|
| KittyParser | `lib/raxol/terminal/ansi/kitty_parser.ex` | Implemented |
| KittyGraphics | `lib/raxol/terminal/ansi/kitty_graphics.ex` | Implemented |
| KittyAnimation | `lib/raxol/terminal/ansi/kitty_animation.ex` | Implemented |
| KittyGraphics Behaviour | `lib/raxol/terminal/ansi/behaviours.ex` | Implemented |
| APC Handler | `lib/raxol/terminal/input/control_sequence_handler.ex` | Implemented |

### Key Technical Notes

1. **APC vs DCS**: Kitty uses APC (`ESC _G`) sequences, not DCS. The integration is in
   `control_sequence_handler.ex` via `handle_apc_sequence/3`, not DCS handlers.

2. **Compression**: Zlib compression is handled inline using Erlang's `:zlib` module.
   No separate KittyCompression module needed.

3. **Behaviours**: KittyGraphics behaviour is defined in `behaviours.ex` alongside
   SixelGraphics and other ANSI behaviours.

## Module Details

### KittyParser (`lib/raxol/terminal/ansi/kitty_parser.ex`)

Parses Kitty graphics protocol control sequences:

```elixir
defmodule Raxol.Terminal.ANSI.KittyParser do
  defmodule ParserState do
    @type t :: %__MODULE__{
      action: :transmit | :transmit_display | :display | :delete | :query | :frame,
      format: :rgb | :rgba | :png | :unknown,
      compression: :none | :zlib,
      transmission: :direct | :file | :temp_file | :shared_memory,
      image_id: non_neg_integer() | nil,
      placement_id: non_neg_integer() | nil,
      width: non_neg_integer() | nil,
      height: non_neg_integer() | nil,
      x_offset: non_neg_integer(),
      y_offset: non_neg_integer(),
      cell_x: non_neg_integer() | nil,
      cell_y: non_neg_integer() | nil,
      z_index: integer(),
      quiet: 0 | 1 | 2,
      more_data: boolean(),
      chunk_data: binary(),
      pixel_buffer: binary(),
      errors: [term()],
      raw_control: binary()
    }
  end

  @spec parse(binary(), ParserState.t()) ::
    {:ok, ParserState.t()} | {:error, atom(), ParserState.t()}

  @spec parse_control_data(binary(), ParserState.t()) ::
    {:ok, ParserState.t()} | {:error, atom(), ParserState.t()}

  @spec decode_base64_payload(binary()) :: {:ok, binary()} | {:error, :invalid_base64}

  @spec handle_chunked_data(binary(), ParserState.t()) :: ParserState.t()

  @spec decompress(binary(), :none | :zlib) :: {:ok, binary()} | {:error, term()}
end
```

**Key Control Data Parameters**:
- `a` - Action: t (transmit), T (transmit+display), p (display), d (delete), q (query)
- `f` - Format: 24 (RGB), 32 (RGBA), 100 (PNG)
- `o` - Compression: z (zlib)
- `t` - Transmission: d (direct), f (file), t (temp file), s (shared memory)
- `i` - Image ID
- `p` - Placement ID
- `s` / `v` - Width / Height in pixels
- `x` / `y` - Pixel offset within cell
- `X` / `Y` - Cell position
- `z` - Z-index
- `m` - More data follows (0 or 1)
- `q` - Quiet mode (0, 1, or 2)

### KittyGraphics (`lib/raxol/terminal/ansi/kitty_graphics.ex`)

High-level API implementing the KittyGraphics behaviour:

```elixir
defmodule Raxol.Terminal.ANSI.KittyGraphics do
  @behaviour Raxol.Terminal.ANSI.Behaviours.KittyGraphics

  @type t :: %__MODULE__{
    width: non_neg_integer(),
    height: non_neg_integer(),
    data: binary(),
    format: :rgb | :rgba | :png,
    compression: :none | :zlib,
    image_id: non_neg_integer() | nil,
    placement_id: non_neg_integer() | nil,
    position: {non_neg_integer(), non_neg_integer()},
    cell_position: {non_neg_integer(), non_neg_integer()} | nil,
    z_index: integer(),
    pixel_buffer: binary(),
    animation_frames: [binary()],
    current_frame: non_neg_integer()
  }

  # Core API (behaviour callbacks)
  @spec new() :: t()
  @spec new(pos_integer(), pos_integer()) :: t()
  @spec set_data(t(), binary()) :: t()
  @spec get_data(t()) :: binary()
  @spec encode(t()) :: binary()
  @spec decode(binary()) :: t()
  @spec supported?() :: boolean()
  @spec process_sequence(t(), binary()) :: {t(), :ok | {:error, term()}}

  # Kitty-specific (optional callbacks)
  @spec transmit_image(t(), map()) :: t()
  @spec place_image(t(), map()) :: t()
  @spec delete_image(t(), non_neg_integer()) :: t()
  @spec query_image(t(), non_neg_integer()) :: {:ok, map()} | {:error, term()}
  @spec add_animation_frame(t(), binary()) :: t()
end
```

### KittyAnimation (`lib/raxol/terminal/ansi/kitty_animation.ex`)

Animation support with GenServer-based frame scheduling:

```elixir
defmodule Raxol.Terminal.ANSI.KittyAnimation do
  use GenServer

  @type loop_mode :: :once | :infinite | :ping_pong
  @type playback_state :: :stopped | :playing | :paused

  @type t :: %__MODULE__{
    image_id: non_neg_integer() | nil,
    width: non_neg_integer(),
    height: non_neg_integer(),
    format: KittyGraphics.format(),
    frames: [frame()],
    current_frame: non_neg_integer(),
    frame_rate: pos_integer(),
    loop_mode: loop_mode(),
    loop_count: non_neg_integer(),
    direction: :forward | :backward,
    state: playback_state(),
    on_frame: (frame() -> :ok) | nil,
    on_complete: (() -> :ok) | nil
  }

  # Creation
  @spec create_animation(map()) :: {:ok, t()} | {:error, term()}
  @spec add_frame(t(), binary(), keyword()) :: t()

  # Playback control (GenServer)
  @spec start(t(), keyword()) :: GenServer.on_start()
  @spec play(GenServer.server()) :: :ok
  @spec pause(GenServer.server()) :: :ok
  @spec resume(GenServer.server()) :: :ok
  @spec stop(GenServer.server()) :: :ok
  @spec seek(GenServer.server(), non_neg_integer()) :: :ok
end
```

### APC Handler Integration

The handler is integrated into `lib/raxol/terminal/input/control_sequence_handler.ex`:

```elixir
def handle_apc_sequence(emulator, command, data) do
  case command do
    "G" -> handle_kitty_graphics(emulator, data)
    _ -> emulator
  end
end

defp handle_kitty_graphics(emulator, data) do
  kitty_state = Map.get(emulator, :kitty_graphics, KittyGraphics.new())

  case KittyGraphics.process_sequence(kitty_state, data) do
    {updated_kitty_state, :ok} ->
      Map.put(emulator, :kitty_graphics, updated_kitty_state)

    {_kitty_state, {:error, _reason}} ->
      emulator
  end
end
```

## Testing (Pending)

**Files to Create**:
- `test/raxol/terminal/ansi/kitty_parser_test.exs`
- `test/raxol/terminal/ansi/kitty_graphics_test.exs`
- `test/raxol/terminal/ansi/kitty_animation_test.exs`
- `test/raxol/terminal/integration/kitty_integration_test.exs`

**Test Coverage**:
- Control data parsing (key=value extraction)
- Base64 payload decoding
- Chunked transmission accumulation
- Format detection (RGB, RGBA, PNG)
- Compression handling (zlib)
- Action routing (transmit, display, delete)
- Animation frame sequencing
- Full pipeline integration

## Terminal Detection

```elixir
defp detect_kitty_support do
  term = System.get_env("TERM", "")
  term_program = System.get_env("TERM_PROGRAM", "")

  cond do
    String.contains?(term, "kitty") or term_program == "kitty" -> :supported
    term_program == "WezTerm" -> :supported
    term_program == "ghostty" -> :supported
    term_program == "iTerm.app" -> :partial_support
    true -> :unknown
  end
end
```

## Performance Targets

- **Parsing**: < 10us per control sequence
- **Decoding**: < 1ms for 1MB image
- **Rendering**: < 5ms for 1000x1000 pixel image
- **Memory**: < 100MB image store quota
- **Animation**: 60fps capable (16ms per frame)

## References

- Kitty Graphics Protocol: https://sw.kovidgoyal.net/kitty/graphics-protocol
- GitHub Source: https://github.com/kovidgoyal/kitty/blob/master/docs/graphics-protocol.rst
- Terminal Control Sequences: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
