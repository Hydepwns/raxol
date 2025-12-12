defmodule Raxol.Terminal.ANSI.KittyParserTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.ANSI.KittyParser
  alias Raxol.Terminal.ANSI.KittyParser.ParserState

  describe "ParserState.new/0" do
    test "creates default parser state" do
      state = ParserState.new()

      assert state.action == :transmit
      assert state.format == :rgba
      assert state.compression == :none
      assert state.transmission == :direct
      assert state.image_id == nil
      assert state.width == nil
      assert state.height == nil
      assert state.x_offset == 0
      assert state.y_offset == 0
      assert state.more_data == false
      assert state.chunk_data == <<>>
      assert state.pixel_buffer == <<>>
    end
  end

  describe "ParserState.new/2" do
    test "creates parser state with dimensions" do
      state = ParserState.new(100, 200)

      assert state.width == 100
      assert state.height == 200
    end
  end

  describe "parse/2" do
    test "parses empty data" do
      state = ParserState.new()
      assert {:ok, ^state} = KittyParser.parse(<<>>, state)
    end

    test "parses action parameter" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("a=t", state)
      assert result.action == :transmit

      {:ok, result} = KittyParser.parse("a=T", state)
      assert result.action == :transmit_display

      {:ok, result} = KittyParser.parse("a=p", state)
      assert result.action == :display

      {:ok, result} = KittyParser.parse("a=d", state)
      assert result.action == :delete

      {:ok, result} = KittyParser.parse("a=q", state)
      assert result.action == :query
    end

    test "parses format parameter" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("f=24", state)
      assert result.format == :rgb

      {:ok, result} = KittyParser.parse("f=32", state)
      assert result.format == :rgba

      {:ok, result} = KittyParser.parse("f=100", state)
      assert result.format == :png
    end

    test "parses compression parameter" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("o=z", state)
      assert result.compression == :zlib

      {:ok, result} = KittyParser.parse("o=n", state)
      assert result.compression == :none
    end

    test "parses transmission parameter" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("t=d", state)
      assert result.transmission == :direct

      {:ok, result} = KittyParser.parse("t=f", state)
      assert result.transmission == :file

      {:ok, result} = KittyParser.parse("t=t", state)
      assert result.transmission == :temp_file

      {:ok, result} = KittyParser.parse("t=s", state)
      assert result.transmission == :shared_memory
    end

    test "parses image dimensions" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("s=100,v=200", state)
      assert result.width == 100
      assert result.height == 200
    end

    test "parses image and placement IDs" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("i=42,p=7", state)
      assert result.image_id == 42
      assert result.placement_id == 7
    end

    test "parses position offsets" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("x=10,y=20", state)
      assert result.x_offset == 10
      assert result.y_offset == 20
    end

    test "parses cell positions" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("X=5,Y=10", state)
      assert result.cell_x == 5
      assert result.cell_y == 10
    end

    test "parses z-index" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("z=3", state)
      assert result.z_index == 3

      {:ok, result} = KittyParser.parse("z=-1", state)
      assert result.z_index == -1
    end

    test "parses quiet mode" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("q=0", state)
      assert result.quiet == 0

      {:ok, result} = KittyParser.parse("q=1", state)
      assert result.quiet == 1

      {:ok, result} = KittyParser.parse("q=2", state)
      assert result.quiet == 2
    end

    test "parses more_data flag" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("m=1", state)
      assert result.more_data == true

      {:ok, result} = KittyParser.parse("m=0", state)
      assert result.more_data == false
    end

    test "parses multiple parameters" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("a=T,f=32,s=100,v=100,i=1", state)

      assert result.action == :transmit_display
      assert result.format == :rgba
      assert result.width == 100
      assert result.height == 100
      assert result.image_id == 1
    end

    test "parses control data with payload" do
      state = ParserState.new()
      # "Hello" in base64
      payload = Base.encode64("Hello")

      {:ok, result} = KittyParser.parse("a=t,f=24;#{payload}", state)

      assert result.action == :transmit
      assert result.format == :rgb
      assert result.pixel_buffer == "Hello"
    end

    test "handles invalid base64 payload" do
      state = ParserState.new()

      {:error, :invalid_base64, error_state} = KittyParser.parse("a=t;not_valid_base64!!!", state)

      assert :invalid_base64 in error_state.errors
    end

    test "ignores unknown parameters" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse("a=t,unknown=value,f=32", state)

      assert result.action == :transmit
      assert result.format == :rgba
    end
  end

  describe "parse_control_data/2" do
    test "parses control data string" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse_control_data("a=t,f=32,s=50,v=50", state)

      assert result.action == :transmit
      assert result.format == :rgba
      assert result.width == 50
      assert result.height == 50
    end

    test "handles empty control data" do
      state = ParserState.new()

      {:ok, result} = KittyParser.parse_control_data("", state)

      assert result == state
    end
  end

  describe "decode_base64_payload/1" do
    test "decodes valid base64" do
      encoded = Base.encode64("test data")

      assert {:ok, "test data"} = KittyParser.decode_base64_payload(encoded)
    end

    test "returns error for invalid base64" do
      assert {:error, :invalid_base64} = KittyParser.decode_base64_payload("not valid!!!")
    end

    test "handles empty string" do
      assert {:ok, ""} = KittyParser.decode_base64_payload("")
    end
  end

  describe "handle_chunked_data/2" do
    test "accumulates data when more_data is true" do
      state = %ParserState{more_data: true, chunk_data: "part1"}

      result = KittyParser.handle_chunked_data("part2", state)

      assert result.chunk_data == "part1part2"
      assert result.pixel_buffer == <<>>
    end

    test "finalizes data when more_data is false" do
      state = %ParserState{more_data: false, chunk_data: "part1"}

      result = KittyParser.handle_chunked_data("part2", state)

      assert result.chunk_data == <<>>
      assert result.pixel_buffer == "part1part2"
    end
  end

  describe "decompress/2" do
    test "returns data unchanged for :none compression" do
      data = "test data"

      assert {:ok, ^data} = KittyParser.decompress(data, :none)
    end

    test "decompresses zlib data" do
      original = "test data for compression"
      compressed = :zlib.compress(original)

      assert {:ok, ^original} = KittyParser.decompress(compressed, :zlib)
    end

    test "returns error for invalid zlib data" do
      assert {:error, {:decompression_failed, _}} = KittyParser.decompress("not compressed", :zlib)
    end
  end

  describe "extract_png_dimensions/1" do
    test "extracts dimensions from valid PNG header" do
      # Minimal PNG header with width=100, height=200
      png_signature = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
      ihdr_length = <<0, 0, 0, 13>>
      ihdr_type = "IHDR"
      width = <<0, 0, 0, 100>>
      height = <<0, 0, 0, 200>>
      rest = <<8, 6, 0, 0, 0>>

      png_data = png_signature <> ihdr_length <> ihdr_type <> width <> height <> rest

      assert {:ok, {100, 200}} = KittyParser.extract_png_dimensions(png_data)
    end

    test "returns error for invalid PNG data" do
      assert {:error, :invalid_png} = KittyParser.extract_png_dimensions("not a png")
    end

    test "returns error for truncated PNG data" do
      png_signature = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>

      assert {:error, :invalid_png} = KittyParser.extract_png_dimensions(png_signature)
    end
  end

  describe "ParserState.reset/1" do
    test "resets state while preserving accumulated data" do
      state = %ParserState{
        action: :delete,
        format: :png,
        compression: :zlib,
        more_data: true,
        chunk_data: "accumulated",
        pixel_buffer: "pixels",
        image_id: 42,
        width: 100,
        height: 100
      }

      result = ParserState.reset(state)

      # These should be reset
      assert result.action == :transmit
      assert result.format == :rgba
      assert result.compression == :none
      assert result.more_data == false
      assert result.errors == []

      # These should be preserved
      assert result.chunk_data == "accumulated"
      assert result.pixel_buffer == "pixels"
      assert result.image_id == 42
      assert result.width == 100
      assert result.height == 100
    end
  end
end
