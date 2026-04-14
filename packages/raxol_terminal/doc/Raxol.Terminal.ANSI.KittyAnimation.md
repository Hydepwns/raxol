# `Raxol.Terminal.ANSI.KittyAnimation`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/kitty_animation.ex#L1)

Animation support for the Kitty graphics protocol.

Provides frame sequencing, playback control, and animation management
for Kitty terminal graphics. Uses a GenServer for frame scheduling
and supports various animation modes.

## Features

* Frame-based animation with configurable frame rates
* Loop modes: once, infinite, ping-pong
* Frame timing control
* Animation state management
* Integration with KittyGraphics

## Usage

    # Create an animation
    {:ok, anim} = KittyAnimation.create_animation(%{
      width: 100,
      height: 100,
      frame_rate: 30
    })

    # Add frames
    anim = KittyAnimation.add_frame(anim, frame1_data)
    anim = KittyAnimation.add_frame(anim, frame2_data)

    # Start playback
    {:ok, pid} = KittyAnimation.start(anim)

    # Control playback
    KittyAnimation.pause(pid)
    KittyAnimation.resume(pid)
    KittyAnimation.stop(pid)

# `frame`

```elixir
@type frame() :: %{
  data: binary(),
  duration_ms: non_neg_integer(),
  index: non_neg_integer()
}
```

# `loop_mode`

```elixir
@type loop_mode() :: :once | :infinite | :ping_pong
```

# `playback_state`

```elixir
@type playback_state() :: :stopped | :playing | :paused
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.ANSI.KittyAnimation{
  current_frame: non_neg_integer(),
  direction: :forward | :backward,
  format: Raxol.Terminal.ANSI.KittyGraphics.format(),
  frame_rate: pos_integer(),
  frames: [frame()],
  height: non_neg_integer(),
  image_id: non_neg_integer() | nil,
  loop_count: non_neg_integer(),
  loop_mode: loop_mode(),
  on_complete: (-&gt; :ok) | nil,
  on_frame: (frame() -&gt; :ok) | nil,
  state: playback_state(),
  width: non_neg_integer()
}
```

# `add_frame`

```elixir
@spec add_frame(t(), binary(), keyword()) :: t()
```

Adds a frame to the animation.

## Parameters

* `animation` - The animation struct
* `frame_data` - Binary pixel data for the frame
* `opts` - Optional frame options:
  * `:duration_ms` - Frame duration override in milliseconds

## Returns

The updated animation with the new frame added.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `create_animation`

```elixir
@spec create_animation(map()) :: {:ok, t()} | {:error, term()}
```

Creates a new animation with the given options.

## Options

* `:width` - Image width in pixels (required)
* `:height` - Image height in pixels (required)
* `:format` - Image format (:rgb, :rgba, :png), defaults to :rgba
* `:frame_rate` - Frames per second, defaults to 30
* `:loop_mode` - Loop mode (:once, :infinite, :ping_pong), defaults to :infinite
* `:image_id` - Optional image ID for the animation

## Returns

* `{:ok, animation}` - New animation struct
* `{:error, reason}` - If required options are missing

# `generate_sequences`

```elixir
@spec generate_sequences(t()) :: [binary()]
```

Generates Kitty protocol escape sequences for the animation.

## Parameters

* `animation` - The animation struct

## Returns

A list of escape sequences for each frame.

# `get_frame`

```elixir
@spec get_frame(t()) :: frame() | nil
```

Gets the current frame from the animation.

## Parameters

* `animation` - The animation struct

## Returns

The current frame struct, or nil if no frames exist.

# `get_frame`

```elixir
@spec get_frame(t(), non_neg_integer()) :: frame() | nil
```

Gets a frame by index.

## Parameters

* `animation` - The animation struct
* `index` - The frame index

## Returns

The frame at the specified index, or nil if not found.

# `get_state`

```elixir
@spec get_state(GenServer.server()) :: t()
```

Gets the current animation state.

## Parameters

* `pid` - The animation player process

## Returns

The current animation struct.

# `next_frame`

```elixir
@spec next_frame(t()) :: {:ok, t()} | {:complete, t()}
```

Advances to the next frame.

Handles loop modes and direction for ping-pong animations.

## Parameters

* `animation` - The animation struct

## Returns

* `{:ok, updated_animation}` - Animation advanced to next frame
* `{:complete, animation}` - Animation completed (for :once mode)

# `pause`

```elixir
@spec pause(GenServer.server()) :: :ok
```

Pauses playback.

## Parameters

* `pid` - The animation player process

## Returns

`:ok`

# `play`

```elixir
@spec play(GenServer.server()) :: :ok
```

Starts playback (for already running process).

## Parameters

* `pid` - The animation player process

## Returns

`:ok`

# `resume`

```elixir
@spec resume(GenServer.server()) :: :ok
```

Resumes playback from current frame.

## Parameters

* `pid` - The animation player process

## Returns

`:ok`

# `seek`

```elixir
@spec seek(GenServer.server(), non_neg_integer()) :: :ok
```

Seeks to a specific frame.

## Parameters

* `pid` - The animation player process
* `frame_index` - The frame to seek to

## Returns

`:ok`

# `set_frame_rate`

```elixir
@spec set_frame_rate(GenServer.server(), pos_integer()) :: :ok
```

Sets the frame rate during playback.

## Parameters

* `pid` - The animation player process
* `fps` - Frames per second

## Returns

`:ok`

# `set_loop_mode`

```elixir
@spec set_loop_mode(GenServer.server(), loop_mode()) :: :ok
```

Sets the loop mode during playback.

## Parameters

* `pid` - The animation player process
* `mode` - Loop mode (:once, :infinite, :ping_pong)

## Returns

`:ok`

# `start`

```elixir
@spec start(
  t(),
  keyword()
) :: GenServer.on_start()
```

Starts playback of the animation as a GenServer process.

## Parameters

* `animation` - The animation struct
* `opts` - GenServer start options

## Returns

* `{:ok, pid}` - The animation player process
* `{:error, reason}` - If start fails

# `stop`

```elixir
@spec stop(GenServer.server()) :: :ok
```

Stops playback and resets to first frame.

## Parameters

* `pid` - The animation player process

## Returns

`:ok`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
