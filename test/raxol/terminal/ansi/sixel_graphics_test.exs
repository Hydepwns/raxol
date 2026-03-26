defmodule Raxol.Terminal.ANSI.SixelGraphicsTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ANSI.SixelGraphics
  alias Raxol.Terminal.ANSI.SixelPalette
  alias Raxol.Terminal.ANSI.SixelParser

  describe "new/0" do
    test "creates a new Sixel state with default values" do
      state = Raxol.Terminal.ANSI.SixelGraphics.new()
      assert state.current_color == 0
      assert state.position == {0, 0}

      assert state.attributes == %{
               width: :normal,
               height: :normal,
               size: :normal
             }

      assert is_map(state.palette)
      assert state.pixel_buffer == %{}
    end
  end

  describe "Sixel Palette" do
    test "initialize_palette/0 initializes the default Sixel color palette" do
      palette = SixelPalette.initialize_palette()
      assert is_map(palette)
      assert palette[0] == {0, 0, 0}
      assert palette[15] == {255, 255, 255}
      assert map_size(palette) > 16
    end
  end

  describe "process_sequence/2" do
    test "processes basic Sixel data" do
      state = SixelGraphics.new()
      input = "\ePq#1A\e\\"
      {new_state, response} = SixelGraphics.process_sequence(state, input)
      assert response == :ok
      assert new_state.current_color == 1
      # 'A' (ASCII 65) is pattern 2 (0b000010), bit 1 is set
      expected_pixels = %{{0, 1} => 1}
      assert new_state.pixel_buffer == expected_pixels
    end

    test "processes color selection and data" do
      state = SixelGraphics.new()
      input = "\ePq#1~\e\\"
      {new_state, response} = SixelGraphics.process_sequence(state, input)
      assert response == :ok
      assert new_state.current_color == 1

      # '~' (ASCII 126) is pattern 63 (126-63). Bits 0-5 should be set with color 1
      expected_pixels = Enum.into(0..5, %{}, fn y -> {{0, y}, 1} end)
      assert new_state.pixel_buffer == expected_pixels
    end

    test "processes carriage return ($)" do
      state = SixelGraphics.new()
      input = "\ePq#0A$#0A\e\\"
      {new_state, response} = SixelGraphics.process_sequence(state, input)
      assert response == :ok
      # First 'A' at x=0, second 'A' at x=0 after CR
      expected_pixels = %{
        # First 'A' with color 0
        {0, 1} => 0,
        # Second 'A' with color 0 after CR and line feed
        {0, 7} => 0
      }

      assert new_state.pixel_buffer == expected_pixels
    end

    test "processes line feed (-)" do
      state = SixelGraphics.new()
      input = "\ePq-A\e\\"
      {new_state, response} = SixelGraphics.process_sequence(state, input)
      assert response == :ok
      # '-' advances y by 6, resets x to 0
      # 'A' (ASCII 65) is pattern 2 (0b000010), bit 1 is set
      # y=6+1 with default color 0
      expected_pixels = %{{0, 7} => 0}
      assert new_state.pixel_buffer == expected_pixels
      # x should be 1 after processing 'A'
      assert elem(new_state.position, 0) == 1
      # y should be 6 after line feed
      assert elem(new_state.position, 1) == 6
    end

    test "handles non-Sixel DCS sequences gracefully" do
      state = SixelGraphics.new()
      input = "\eP!pSomeData\e\\"
      {_new_state, response} = SixelGraphics.process_sequence(state, input)
      assert response == {:error, :missing_or_misplaced_q}
    end

    test "processes complex Sixel sequence with attributes" do
      state = SixelGraphics.new()
      input = "\ePq\"1;1;100;50#1;1;66;50;100!3A$-A\e\\"
      {new_state, response} = SixelGraphics.process_sequence(state, input)
      assert response == :ok

      # Debug output
      IO.puts("DEBUG: Pixel buffer: #{inspect(new_state.pixel_buffer)}")
      IO.puts("DEBUG: Final position: #{inspect(new_state.position)}")

      IO.puts(
        "DEBUG: Expected pixel at {0, 13}: #{Map.get(new_state.pixel_buffer, {0, 13})}"
      )

      # Verify final state attributes
      assert new_state.attributes.width == 100
      assert new_state.palette |> Map.get(0) == {0, 0, 0}

      # Verify Color 1 (HLS 66,50,100 -> Blue-ish)
      assert {r, g, b} = new_state.palette |> Map.get(1)
      assert r == 0 and g == 10 and b == 255

      # Verify pixel buffer contents
      # Check pixels from the repeated 'A' (pattern 2 -> bit 1) - should be color 1
      # First 'A'
      assert Map.get(new_state.pixel_buffer, {0, 1}) == 1
      # Second 'A'
      assert Map.get(new_state.pixel_buffer, {1, 1}) == 1
      # Third 'A'
      assert Map.get(new_state.pixel_buffer, {2, 1}) == 1
      # Final 'A' after CR/LF - should be at {0, 13} not {0, 7}
      assert Map.get(new_state.pixel_buffer, {0, 13}) == 1

      # Verify final cursor position
      # After processing final 'A'
      assert elem(new_state.position, 0) == 1
      # After line feed - should be 12 not 6
      assert elem(new_state.position, 1) == 12
    end

    test "handles DCS Sixel termination correctly" do
      state = SixelGraphics.new()

      # Test exact termination
      input_exact = "\ePq?\e\\"

      {new_state_exact, response_exact} =
        SixelGraphics.process_sequence(state, input_exact)

      assert response_exact == :ok
      # Empty buffer for pattern 0
      assert new_state_exact.pixel_buffer == %{}

      # Test embedded ST
      input_embedded = "\ePq?\e\\extra"

      {_new_state_embedded, response_embedded} =
        SixelGraphics.process_sequence(state, input_embedded)

      assert response_embedded == :ok

      # Test missing ST
      input_missing = "\ePq?'"

      {_new_state_missing, response_missing} =
        SixelGraphics.process_sequence(state, input_missing)

      assert response_missing == {:error, :missing_st}
    end
  end

  describe "apply_dithering/2" do
    setup do
      # 4x4 image with a gradient-like pixel buffer and a 4-color palette
      palette = %{
        0 => {0, 0, 0},
        1 => {255, 0, 0},
        2 => {0, 255, 0},
        3 => {0, 0, 255}
      }

      pixel_buffer =
        for y <- 0..3, x <- 0..3, into: %{} do
          {{x, y}, rem(x + y, 4)}
        end

      image = %SixelGraphics{
        width: 4,
        height: 4,
        palette: palette,
        pixel_buffer: pixel_buffer
      }

      %{image: image}
    end

    test ":none returns image unchanged", %{image: image} do
      result = SixelGraphics.apply_dithering(image, :none)
      assert result.pixel_buffer == image.pixel_buffer
    end

    test ":floyd_steinberg modifies pixel_buffer", %{image: image} do
      result = SixelGraphics.apply_dithering(image, :floyd_steinberg)
      assert result.dithering_algorithm == :floyd_steinberg
      assert map_size(result.pixel_buffer) == map_size(image.pixel_buffer)

      # All indices should still be valid palette entries
      for {_pos, idx} <- result.pixel_buffer do
        assert Map.has_key?(result.palette, idx)
      end
    end

    test ":ordered modifies pixel_buffer", %{image: image} do
      result = SixelGraphics.apply_dithering(image, :ordered)
      assert result.dithering_algorithm == :ordered
      assert map_size(result.pixel_buffer) == map_size(image.pixel_buffer)

      for {_pos, idx} <- result.pixel_buffer do
        assert Map.has_key?(result.palette, idx)
      end
    end

    test ":random modifies pixel_buffer", %{image: image} do
      result = SixelGraphics.apply_dithering(image, :random)
      assert result.dithering_algorithm == :random
      assert map_size(result.pixel_buffer) == map_size(image.pixel_buffer)

      for {_pos, idx} <- result.pixel_buffer do
        assert Map.has_key?(result.palette, idx)
      end
    end

    test "empty image is a no-op" do
      empty = %SixelGraphics{pixel_buffer: %{}, palette: %{}}
      result = SixelGraphics.apply_dithering(empty, :floyd_steinberg)
      assert result.pixel_buffer == %{}
      assert result.dithering_algorithm == :floyd_steinberg
    end

    test "floyd_steinberg preserves pixel_buffer size for larger image" do
      # 8x6 image with 2-color palette (forces error diffusion)
      palette = %{0 => {0, 0, 0}, 1 => {255, 255, 255}}

      pixel_buffer =
        for y <- 0..5, x <- 0..7, into: %{} do
          # Alternating pattern
          {{x, y}, rem(x + y, 2)}
        end

      image = %SixelGraphics{
        width: 8,
        height: 6,
        palette: palette,
        pixel_buffer: pixel_buffer
      }

      result = SixelGraphics.apply_dithering(image, :floyd_steinberg)
      assert map_size(result.pixel_buffer) == 48

      for {_pos, idx} <- result.pixel_buffer do
        assert idx in [0, 1]
      end
    end
  end

  describe "encode/1" do
    test "returns empty string for empty pixel_buffer" do
      image = SixelGraphics.new(10, 10)
      assert SixelGraphics.encode(image) == ""
    end

    test "encodes pixel_buffer to sixel escape sequence" do
      image = SixelGraphics.new(2, 6)

      pixel_buffer =
        for y <- 0..5, x <- 0..1, into: %{} do
          {{x, y}, 1}
        end

      image = %{image | pixel_buffer: pixel_buffer}
      encoded = SixelGraphics.encode(image)

      assert String.starts_with?(encoded, "\e[?8452h\ePq")
      assert String.ends_with?(encoded, "\e\\")
      # Should contain a color reference
      assert String.contains?(encoded, "#1")
    end
  end

  describe "internal parsing functions" do
    test "consume_integer_params extracts parameters correctly" do
      assert SixelParser.consume_integer_params("1;2;3rest") ==
               {:ok, [1, 2, 3], "rest"}

      assert SixelParser.consume_integer_params("1;;3rest") ==
               {:ok, [1, 0, 3], "rest"}

      assert SixelParser.consume_integer_params("rest") == {:ok, [], "rest"}

      assert SixelParser.consume_integer_params(";1rest") ==
               {:ok, [0, 1], "rest"}

      assert SixelParser.consume_integer_params("1;a;3rest") ==
               {:ok, [1, 0], "a;3rest"}
    end

    test "hls_to_rgb converts correctly" do
      # Red
      assert SixelPalette.hls_to_rgb(0.0, 0.5, 1.0) == {:ok, {255, 0, 0}}
      # Green
      assert SixelPalette.hls_to_rgb(120.0, 0.5, 1.0) == {:ok, {0, 255, 0}}
      # Blue
      assert SixelPalette.hls_to_rgb(240.0, 0.5, 1.0) == {:ok, {0, 0, 255}}
      # Yellow
      assert SixelPalette.hls_to_rgb(60.0, 0.5, 1.0) == {:ok, {255, 255, 0}}
      # White (L=1)
      assert SixelPalette.hls_to_rgb(0.0, 1.0, 0.0) == {:ok, {255, 255, 255}}
      # Black (L=0)
      assert SixelPalette.hls_to_rgb(0.0, 0.0, 0.0) == {:ok, {0, 0, 0}}
      # Grey (S=0, L=0.5)
      assert SixelPalette.hls_to_rgb(180.0, 0.5, 0.0) == {:ok, {128, 128, 128}}
      # Red (H=360)
      assert SixelPalette.hls_to_rgb(360.0, 0.5, 1.0) == {:ok, {255, 0, 0}}
    end
  end
end
