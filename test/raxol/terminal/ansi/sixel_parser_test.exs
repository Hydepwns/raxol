# test/raxol/terminal/ansi/sixel_parser_test.exs

defmodule Raxol.Terminal.ANSI.SixelParserTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.ANSI.SixelPalette
  alias Raxol.Terminal.ANSI.SixelParser

  test "SixelParser handles raster attributes" do
    initial_state = %SixelParser.ParserState{
      x: 0,
      y: 0,
      color_index: 0,
      repeat_count: 1,
      palette: SixelPalette.initialize_palette(),
      # Initial empty map
      raster_attrs: %{},
      pixel_buffer: %{},
      max_x: 0,
      max_y: 0
    }

    # DCS " Pn1 ; Pn2 ; Pn3 ; Pn4 q DATA ST
    # Pn1 = Pan, Pn2 = Pad, Pn3 = Ph, Pn4 = Pv
    # Example data with raster attributes then a pixel command
    sixel_data = "\\\"1;1;123;456?"

    {:ok, actual_state} = SixelParser.parse(sixel_data, initial_state)

    # Updated expectation: A map with width and height keys
    expected_attributes = %{
      aspect_num: 1,
      aspect_den: 1,
      width: 123,
      height: 456
    }

    # Assert that the raster_attrs field in the state is the expected map
    assert actual_state.raster_attrs == expected_attributes
  end

  test "SixelParser handles missing raster attributes" do
    initial_state = %SixelParser.ParserState{
      x: 0,
      y: 0,
      color_index: 0,
      repeat_count: 1,
      palette: SixelPalette.initialize_palette(),
      raster_attrs: %{},
      pixel_buffer: %{},
      max_x: 0,
      max_y: 0
    }

    # DCS " Pn1 q DATA ST (Missing Pad, Ph, Pv)
    # Only Pan provided, then pixel data
    sixel_data = "\\\"1?"

    {:ok, actual_state} = SixelParser.parse(sixel_data, initial_state)

    # Expect aspect_den to default to 1, width/height to be nil
    expected_attributes = %{
      aspect_num: 1,
      aspect_den: 1,
      width: nil,
      height: nil
    }

    assert actual_state.raster_attrs == expected_attributes
  end

  test "SixelParser handles empty raster attributes" do
    initial_state = %SixelParser.ParserState{
      x: 0,
      y: 0,
      color_index: 0,
      repeat_count: 1,
      palette: SixelPalette.initialize_palette(),
      raster_attrs: %{},
      pixel_buffer: %{},
      max_x: 0,
      max_y: 0
    }

    # DCS " q DATA ST (No parameters)
    # No params, just pixel data
    sixel_data = "\\\"?"

    {:ok, actual_state} = SixelParser.parse(sixel_data, initial_state)

    # Expect aspect ratio 1/1, width/height nil
    expected_attributes = %{
      aspect_num: 1,
      aspect_den: 1,
      width: nil,
      height: nil
    }

    assert actual_state.raster_attrs == expected_attributes
  end
end
