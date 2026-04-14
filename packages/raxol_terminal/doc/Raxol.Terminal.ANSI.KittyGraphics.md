# `Raxol.Terminal.ANSI.KittyGraphics`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/kitty_graphics.ex#L1)

Complete Kitty graphics protocol support for terminal rendering.

This module provides comprehensive Kitty Graphics Protocol support:
* Full image encoding and decoding
* RGB, RGBA, and PNG format support
* Zlib compression support
* Multi-chunk transmission for large images
* Image placement and positioning
* Image deletion and management
* Animation frame support

## Kitty Graphics Protocol

The Kitty Graphics Protocol is a modern graphics protocol that enables
pixel-level graphics rendering in compatible terminals. It uses APC
(Application Program Command) escape sequences and supports:

* Multiple image formats (RGB, RGBA, PNG)
* Compression (zlib)
* Chunked transmission for large images
* Image placement at cell or pixel level
* Z-index layering
* Animation support

## Usage

    # Create a new image
    image = KittyGraphics.new(100, 100)

    # Set image data
    image = KittyGraphics.set_data(image, pixel_data)

    # Encode for transmission
    escape_sequence = KittyGraphics.encode(image)

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
@type format() :: :rgb | :rgba | :png
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.ANSI.KittyGraphics{
  animation_frames: [binary()],
  cell_position: {non_neg_integer(), non_neg_integer()} | nil,
  compression: compression(),
  current_frame: non_neg_integer(),
  data: binary(),
  format: format(),
  height: non_neg_integer(),
  image_id: non_neg_integer() | nil,
  pixel_buffer: binary(),
  placement_id: non_neg_integer() | nil,
  position: {non_neg_integer(), non_neg_integer()},
  width: non_neg_integer(),
  z_index: integer()
}
```

# `transmission`

```elixir
@type transmission() :: :direct | :file | :temp_file | :shared_memory
```

# `add_animation_frame`

Adds an animation frame to the image.

## Parameters

* `image` - The current image state
* `frame_data` - Binary data for the new frame

## Returns

The updated image with the new frame added.

# `decode`

Decodes an APC escape sequence into a Kitty image.

## Parameters

* `data` - The APC escape sequence to decode

## Returns

A new `t:Raxol.Terminal.ANSI.KittyGraphics.t/0` struct with the decoded image data.

# `delete_image`

Deletes an image by its ID.

## Parameters

* `image` - The current image state
* `image_id` - The ID of the image to delete

## Returns

The updated image state (cleared if ID matches).

# `encode`

Encodes a Kitty image to APC escape sequence.

Generates the complete escape sequence for transmitting the image
to a Kitty-compatible terminal.

## Parameters

* `image` - The image to encode

## Returns

A binary containing the APC escape sequence for the Kitty image.

# `generate_delete_command`

Generates a delete command for an image.

## Parameters

* `image_id` - The ID of the image to delete
* `opts` - Delete options:
  * `:delete_action` - What to delete (:all, :id, :placement, :z_index, :cell, :animation)

## Returns

The APC escape sequence for the delete command.

# `generate_query_command`

Generates a query command for image capabilities.

## Returns

The APC escape sequence for querying terminal capabilities.

# `get_current_frame`

Gets the current animation frame.

## Parameters

* `image` - The current image

## Returns

The binary data for the current animation frame, or nil if no frames.

# `get_data`

Gets the current image data.

## Parameters

* `image` - The current image

## Returns

The binary image data.

# `new`

Creates a new Kitty image with default values.

## Returns

A new `t:Raxol.Terminal.ANSI.KittyGraphics.t/0` struct with default values.

# `new`

Creates a new Kitty image with specified dimensions.

## Parameters

* `width` - The image width in pixels
* `height` - The image height in pixels

## Returns

A new `t:Raxol.Terminal.ANSI.KittyGraphics.t/0` struct with the specified dimensions.

# `next_frame`

Advances to the next animation frame.

## Parameters

* `image` - The current image

## Returns

The updated image with the next frame selected.

# `place_image`

Places an image at a specific position.

## Parameters

* `image` - The current image state
* `opts` - Placement options:
  * `:x` - Pixel X offset within cell
  * `:y` - Pixel Y offset within cell
  * `:cell_x` - Cell column position
  * `:cell_y` - Cell row position
  * `:z` - Z-index for layering

## Returns

The updated image state with placement information.

# `process_sequence`

Processes a Kitty graphics protocol sequence.

## Parameters

* `state` - The current Kitty graphics state
* `data` - The Kitty graphics data to process (control + payload)

## Returns

A tuple containing the updated state and a response:
* `{updated_state, :ok}` - Successful processing
* `{state, {:error, reason}}` - Processing error

# `query_image`

Queries information about an image.

## Parameters

* `image` - The current image state
* `image_id` - The ID of the image to query

## Returns

* `{:ok, info_map}` - Image information if found
* `{:error, :not_found}` - Image not found

# `set_compression`

Sets the compression method.

## Parameters

* `image` - The current image
* `compression` - The compression method (:none, :zlib)

## Returns

The updated image with the new compression setting.

# `set_data`

Sets the image data for a Kitty image.

## Parameters

* `image` - The current image
* `data` - The binary image data (raw pixels or PNG)

## Returns

The updated image with new data.

# `set_format`

Sets the image format.

## Parameters

* `image` - The current image
* `format` - The format (:rgb, :rgba, :png)

## Returns

The updated image with the new format.

# `supported?`

Checks if the terminal supports Kitty graphics.

## Returns

`true` if Kitty graphics are supported, `false` otherwise.

# `transmit_image`

Transmits an image to the terminal.

## Parameters

* `image` - The current image state
* `opts` - Transmission options:
  * `:format` - Image format (:rgb, :rgba, :png)
  * `:compression` - Compression method (:none, :zlib)
  * `:id` - Optional image ID for later reference

## Returns

The updated image state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
