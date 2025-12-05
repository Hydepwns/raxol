# Kitty Graphics Protocol Implementation Plan

**Status**: Planning Phase
**Effort**: 1-2 weeks
**Priority**: Low (defer to v2.2+)
**Created**: 2025-12-05

## Protocol Overview

Kitty Graphics Protocol enables pixel-level graphics rendering in terminals with features superior to Sixel:
- **Base Format**: `<ESC>_G<control data>;<payload><ESC>\`
- **Control Data**: Comma-separated key=value pairs
- **Payload**: Base64 encoded binary data
- **Key Advantage**: Native animation support, better compression, more flexible placement

## Architecture (Mirror Sixel Pattern)

```
KittyParser          -> Parses escape sequences
KittyGraphics        -> State management and encoding/decoding
KittyAnimation       -> Frame sequencing and playback
DCS Handler          -> Route to KittyGraphics.process_sequence/2
ImageRenderer        -> Plugin integration (create_kitty_cells)
```

## Implementation Phases

### Phase 1: Parser Implementation (Days 1-3)

**File**: `lib/raxol/terminal/ansi/kitty_parser.ex`

**Pattern after SixelParser structure**:
```elixir
defmodule Raxol.Terminal.ANSI.KittyParser do
  defmodule ParserState do
    @type t :: %__MODULE__{
      action: atom(),           # :transmit, :display, :delete, :query
      format: atom(),           # :rgb, :rgba, :png
      compression: atom(),      # :none, :zlib
      transmission: atom(),     # :direct, :file, :temp_file, :shm
      image_id: non_neg_integer(),
      image_number: non_neg_integer(),
      width: non_neg_integer(),
      height: non_neg_integer(),
      x_offset: non_neg_integer(),
      y_offset: non_neg_integer(),
      z_index: integer(),
      placement_id: non_neg_integer(),
      chunk_data: binary(),
      more_data: boolean(),
      pixel_buffer: map(),
      control_data: map()
    }
  end

  @spec parse(binary(), ParserState.t()) ::
    {:ok, ParserState.t()} | {:error, atom()}
  def parse(data, state)

  # Key functions to implement:
  # - parse_control_data/1      - Extract key=value pairs
  # - parse_action/1            - Decode action (a=t, a=p, a=d)
  # - parse_format/1            - Decode format (f=24, f=32, f=100)
  # - parse_transmission/1      - Decode transmission method
  # - decode_base64_payload/1   - Handle base64 decoding
  # - handle_chunked_data/2     - Accumulate multi-chunk transmissions
  # - decompress_payload/2      - Handle zlib/png decompression
end
```

**Key Parsing Steps**:
1. Extract control data (comma-separated key=value before semicolon)
2. Parse payload (base64 after semicolon)
3. Handle chunking (m=1 means more data coming)
4. Decode based on format (RGB, RGBA, PNG)
5. Apply compression (zlib if o=z)

### Phase 2: Graphics State Management (Days 4-6)

**File**: `lib/raxol/terminal/ansi/kitty_graphics.ex`

**Pattern after SixelGraphics structure**:
```elixir
defmodule Raxol.Terminal.ANSI.KittyGraphics do
  @behaviour Raxol.Terminal.ANSI.Behaviours.KittyGraphics

  @type t :: %__MODULE__{
    width: non_neg_integer(),
    height: non_neg_integer(),
    format: :rgb | :rgba | :png,
    data: binary(),
    pixel_buffer: map(),
    image_store: map(),           # id -> image_data
    placements: map(),            # placement_id -> placement_data
    z_index: integer(),
    compression: :none | :zlib,
    animation_frames: [t()] | nil,
    current_frame: non_neg_integer()
  }

  # Core API (mirror Sixel):
  @spec new() :: t()
  @spec new(pos_integer(), pos_integer()) :: t()
  @spec process_sequence(t(), binary()) :: {t(), :ok | {:error, term()}}
  @spec encode(t()) :: binary()
  @spec decode(binary()) :: t()

  # Kitty-specific functions:
  @spec transmit_image(t(), map()) :: t()
  @spec place_image(t(), map()) :: t()
  @spec delete_image(t(), non_neg_integer()) :: t()
  @spec query_image(t(), non_neg_integer()) :: {:ok, map()} | {:error, term()}
  @spec add_animation_frame(t(), binary()) :: t()
end
```

**Image Store Design**:
- Store transmitted images by ID
- Support virtual placements (multiple instances of same image)
- Handle z-indexing for layering
- Memory quota management

### Phase 3: DCS Handler Integration (Day 7)

**File**: `lib/raxol/terminal/commands/dcs_handlers.ex`

**Changes needed**:
```elixir
# Add Kitty detection
defp detect_graphics_type(data) do
  cond do
    String.starts_with?(data, "q") -> :sixel
    String.starts_with?(data, "G") -> :kitty  # NEW
    true -> :unknown
  end
end

# Add Kitty routing
defp handle_graphics_dcs(emulator, :kitty, data) do
  state = get_in(emulator, [:graphics, :kitty]) || KittyGraphics.new()

  case KittyGraphics.process_sequence(state, data) do
    {updated_state, :ok} ->
      emulator = put_in(emulator, [:graphics, :kitty], updated_state)
      {:ok, emulator}

    {_state, {:error, reason}} ->
      {:error, reason, emulator}
  end
end
```

### Phase 4: Compression Support (Day 8)

**File**: `lib/raxol/terminal/ansi/kitty_compression.ex`

**Implementation**:
```elixir
defmodule Raxol.Terminal.ANSI.KittyCompression do
  @spec decompress(binary(), :zlib | :none) ::
    {:ok, binary()} | {:error, term()}

  def decompress(data, :none), do: {:ok, data}

  def decompress(data, :zlib) do
    case :zlib.uncompress(data) do
      uncompressed when is_binary(uncompressed) ->
        {:ok, uncompressed}
      _ ->
        {:error, :decompression_failed}
    end
  catch
    _, _ -> {:error, :invalid_zlib_data}
  end

  @spec compress(binary(), :zlib | :none) :: binary()
  def compress(data, :none), do: data
  def compress(data, :zlib), do: :zlib.compress(data)

  # PNG handling
  def decode_png(data) do
    # Use existing image library or implement minimal PNG decoder
    # For MVP, can rely on external tools
    {:error, :not_implemented}
  end
end
```

### Phase 5: Animation Support (Days 9-10)

**File**: `lib/raxol/terminal/ansi/kitty_animation.ex`

**Design**:
```elixir
defmodule Raxol.Terminal.ANSI.KittyAnimation do
  @type frame :: %{
    data: binary(),
    delay: non_neg_integer(),  # milliseconds
    composition: :alpha | :overwrite
  }

  @type animation :: %{
    frames: [frame()],
    current_frame: non_neg_integer(),
    loop: boolean(),
    playing: boolean()
  }

  @spec create_animation([frame()]) :: animation()
  @spec add_frame(animation(), frame()) :: animation()
  @spec next_frame(animation()) :: {animation(), frame()}
  @spec play(animation()) :: animation()
  @spec stop(animation()) :: animation()

  # Integration with GenServer for frame scheduling
  defmodule AnimationScheduler do
    use GenServer

    # Schedule frame updates based on delays
    # Emit events for frame changes
  end
end
```

### Phase 6: Plugin Integration (Days 11-12)

**File**: `lib/raxol/plugins/visualization/image_renderer.ex`

**Update `create_kitty_cells/2`**:
```elixir
defp create_kitty_cells(kitty_data, %{width: width, height: height}) do
  case Raxol.Core.ErrorHandling.safe_call(fn ->
    create_kitty_cells_from_buffer(kitty_data, {width, height})
  end) do
    {:ok, cells} -> cells
    {:error, reason} ->
      Log.error("[ImageRenderer] Error creating Kitty cells: #{inspect(reason)}")
      List.duplicate(List.duplicate(Cell.new(" "), width), height)
  end
end

defp create_kitty_cells_from_buffer(kitty_data, {width, height}) do
  state = Raxol.Terminal.ANSI.KittyGraphics.new()

  case Raxol.Terminal.ANSI.KittyGraphics.process_sequence(state, kitty_data) do
    {updated_state, :ok} ->
      kitty_buffer_to_cells(updated_state, width, height)

    {_state, {:error, reason}} ->
      Log.warning_with_context(
        "[ImageRenderer] Kitty processing failed: #{inspect(reason)}",
        %{}
      )
      List.duplicate(List.duplicate(Cell.new(" "), width), height)
  end
end

defp kitty_buffer_to_cells(kitty_state, width, height) do
  # Convert RGBA pixel buffer to Cell grid
  # Similar to Sixel but handle alpha blending
  for y <- 0..(height - 1) do
    for x <- 0..(width - 1) do
      case get_pixel_rgba(kitty_state.pixel_buffer, x, y) do
        {r, g, b, a} when a > 0 ->
          style = %Raxol.Terminal.ANSI.TextFormatting{
            background: {:rgb, r, g, b}
          }
          Cell.new_sixel(" ", style)

        _ ->
          Cell.new(" ")
      end
    end
  end
end
```

### Phase 7: Testing (Days 13-14)

**Files to Create**:
- `test/raxol/terminal/ansi/kitty_parser_test.exs`
- `test/raxol/terminal/ansi/kitty_graphics_test.exs`
- `test/raxol/terminal/ansi/kitty_compression_test.exs`
- `test/raxol/terminal/ansi/kitty_animation_test.exs`
- `test/raxol/terminal/integration/kitty_integration_test.exs`

**Test Coverage**:
```elixir
# Parser Tests
- Control data parsing (key=value extraction)
- Base64 payload decoding
- Chunked transmission accumulation
- Format detection (RGB, RGBA, PNG)
- Compression flag handling
- Action routing (transmit, display, delete)

# Graphics Tests
- Image storage and retrieval
- Placement management
- Z-index handling
- Memory quota enforcement
- Alpha blending
- Animation frame sequencing

# Integration Tests
- Full pipeline: DCS -> Parser -> Graphics -> Buffer -> Cell
- Multiple image placements
- Animated GIF rendering
- Error recovery
```

## Key Implementation Considerations

### 1. Memory Management
```elixir
# Implement image store quota
@max_image_store_bytes 100_000_000  # 100MB

defp enforce_quota(state) do
  total_size = calculate_total_size(state.image_store)

  if total_size > @max_image_store_bytes do
    # Evict oldest images using LRU
    evict_oldest_images(state)
  else
    state
  end
end
```

### 2. Terminal Capability Detection
```elixir
defp supports_kitty?(state) do
  term_program = get_in(state, [:terminal, :program])
  term_features = get_in(state, [:terminal, :features]) || []

  term_program == "kitty" or "kitty_graphics" in term_features
end
```

### 3. Alpha Blending
```elixir
defp blend_alpha(fg_color, bg_color, alpha) do
  {fr, fg, fb} = fg_color
  {br, bg, bb} = bg_color
  a = alpha / 255.0

  {
    round(fr * a + br * (1 - a)),
    round(fg * a + bg * (1 - a)),
    round(fb * a + bb * (1 - a))
  }
end
```

### 4. Chunked Transmission
```elixir
defp handle_chunked_transmission(state, control_data, payload) do
  case Map.get(control_data, "m") do
    "1" ->
      # More chunks coming
      %{state | chunk_data: state.chunk_data <> payload, more_data: true}

    _ ->
      # Final chunk
      complete_data = state.chunk_data <> payload
      %{state | chunk_data: <<>>, more_data: false}
      |> process_complete_image(complete_data)
  end
end
```

## Dependencies

**Elixir Modules Needed**:
- `:zlib` - Built-in Erlang compression
- Base module - Base64 encoding/decoding
- Pattern matching for control data parsing
- GenServer for animation scheduling (optional)

**External Libraries** (optional):
- PNG decoder (or use Mogrify for conversion)
- Image processing utilities

## Performance Targets

- **Parsing**: < 10μs per control sequence
- **Decoding**: < 1ms for 1MB image
- **Rendering**: < 5ms for 1000x1000 pixel image
- **Memory**: < 100MB image store quota
- **Animation**: 60fps capable (16ms per frame)

## Testing Strategy

1. **Unit Tests**: Each module independently
2. **Property Tests**: Control data parsing, base64 encoding
3. **Integration Tests**: Full pipeline with sample images
4. **Performance Tests**: Large images, animations, memory usage
5. **Compatibility Tests**: With actual Kitty terminal

## Migration Path from Sixel

Users can choose protocol based on terminal capabilities:
```elixir
def detect_best_protocol(state) do
  cond do
    supports_kitty?(state) -> :kitty
    supports_sixel?(state) -> :sixel
    true -> :placeholder
  end
end
```

## Future Enhancements

- **Unicode placeholders**: Display images inline with text
- **Z-index management**: Layer multiple images
- **Query responses**: Terminal capability detection
- **Shared memory**: Zero-copy for local images
- **Delta frames**: Efficient animation updates

## Success Criteria

- ✓ Parse all Kitty control sequences correctly
- ✓ Handle RGB, RGBA, and PNG formats
- ✓ Support zlib compression
- ✓ Implement chunked transmission
- ✓ Basic animation playback
- ✓ Integration with plugin system
- ✓ 100% test coverage for core modules
- ✓ Zero compilation warnings
- ✓ Performance targets met

## Effort Breakdown

| Phase | Days | Complexity |
|-------|------|------------|
| 1. Parser | 3 | Medium |
| 2. Graphics State | 3 | Medium |
| 3. DCS Integration | 1 | Low |
| 4. Compression | 1 | Low |
| 5. Animation | 2 | Medium |
| 6. Plugin Integration | 2 | Low |
| 7. Testing | 2 | Medium |
| **Total** | **14** | **Medium-High** |

## References

- Kitty Graphics Protocol: https://sw.kovidgoyal.net/kitty/graphics-protocol
- GitHub Source: https://github.com/kovidgoyal/kitty/blob/master/docs/graphics-protocol.rst
- Terminal Control Sequences: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
