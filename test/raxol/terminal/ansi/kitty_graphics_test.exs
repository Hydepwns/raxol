defmodule Raxol.Terminal.ANSI.KittyGraphicsTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.ANSI.KittyGraphics

  describe "new/0" do
    test "creates default graphics state" do
      state = KittyGraphics.new()

      assert state.width == 0
      assert state.height == 0
      assert state.data == <<>>
      assert state.format == :rgba
      assert state.compression == :none
      assert state.image_id == nil
      assert state.placement_id == nil
      assert state.position == {0, 0}
      assert state.cell_position == nil
      assert state.z_index == 0
      assert state.pixel_buffer == <<>>
      assert state.animation_frames == []
      assert state.current_frame == 0
    end
  end

  describe "new/2" do
    test "creates graphics state with dimensions" do
      state = KittyGraphics.new(100, 200)

      assert state.width == 100
      assert state.height == 200
    end

    test "requires positive dimensions" do
      assert_raise FunctionClauseError, fn ->
        KittyGraphics.new(0, 100)
      end

      assert_raise FunctionClauseError, fn ->
        KittyGraphics.new(100, 0)
      end

      assert_raise FunctionClauseError, fn ->
        KittyGraphics.new(-1, 100)
      end
    end
  end

  describe "set_data/2 and get_data/1" do
    test "sets and gets image data" do
      state = KittyGraphics.new()
      data = <<1, 2, 3, 4, 5>>

      state = KittyGraphics.set_data(state, data)

      assert KittyGraphics.get_data(state) == data
      assert state.pixel_buffer == data
    end
  end

  describe "set_format/2" do
    test "sets image format" do
      state = KittyGraphics.new()

      state = KittyGraphics.set_format(state, :rgb)
      assert state.format == :rgb

      state = KittyGraphics.set_format(state, :rgba)
      assert state.format == :rgba

      state = KittyGraphics.set_format(state, :png)
      assert state.format == :png
    end

    test "rejects invalid formats" do
      state = KittyGraphics.new()

      assert_raise FunctionClauseError, fn ->
        KittyGraphics.set_format(state, :invalid)
      end
    end
  end

  describe "set_compression/2" do
    test "sets compression method" do
      state = KittyGraphics.new()

      state = KittyGraphics.set_compression(state, :zlib)
      assert state.compression == :zlib

      state = KittyGraphics.set_compression(state, :none)
      assert state.compression == :none
    end

    test "rejects invalid compression" do
      state = KittyGraphics.new()

      assert_raise FunctionClauseError, fn ->
        KittyGraphics.set_compression(state, :gzip)
      end
    end
  end

  describe "transmit_image/2" do
    test "sets transmission parameters" do
      state = KittyGraphics.new(100, 100)

      state = KittyGraphics.transmit_image(state, %{
        format: :rgb,
        compression: :zlib,
        id: 42
      })

      assert state.format == :rgb
      assert state.compression == :zlib
      assert state.image_id == 42
    end

    test "generates image_id if not provided" do
      state = KittyGraphics.new(100, 100)

      state = KittyGraphics.transmit_image(state, %{})

      assert is_integer(state.image_id)
      assert state.image_id > 0
    end
  end

  describe "place_image/2" do
    test "sets placement position" do
      state = KittyGraphics.new(100, 100)

      state = KittyGraphics.place_image(state, %{
        x: 10,
        y: 20,
        cell_x: 5,
        cell_y: 3,
        z: 2
      })

      assert state.position == {10, 20}
      assert state.cell_position == {5, 3}
      assert state.z_index == 2
    end

    test "handles partial options" do
      state = KittyGraphics.new(100, 100)

      state = KittyGraphics.place_image(state, %{x: 10})

      assert state.position == {10, 0}
      assert state.cell_position == nil
    end
  end

  describe "delete_image/2" do
    test "clears data when image_id matches" do
      state = %KittyGraphics{
        image_id: 42,
        pixel_buffer: "data",
        data: "data"
      }

      state = KittyGraphics.delete_image(state, 42)

      assert state.pixel_buffer == <<>>
      assert state.data == <<>>
    end

    test "does not clear data when image_id does not match" do
      state = %KittyGraphics{
        image_id: 42,
        pixel_buffer: "data",
        data: "data"
      }

      state = KittyGraphics.delete_image(state, 99)

      assert state.pixel_buffer == "data"
      assert state.data == "data"
    end
  end

  describe "query_image/2" do
    test "returns image info when id matches" do
      state = %KittyGraphics{
        image_id: 42,
        width: 100,
        height: 200,
        format: :rgba,
        pixel_buffer: "12345"
      }

      assert {:ok, info} = KittyGraphics.query_image(state, 42)

      assert info.id == 42
      assert info.width == 100
      assert info.height == 200
      assert info.format == :rgba
      assert info.size == 5
    end

    test "returns error when id does not match" do
      state = %KittyGraphics{image_id: 42}

      assert {:error, :not_found} = KittyGraphics.query_image(state, 99)
    end
  end

  describe "add_animation_frame/2" do
    test "adds frame to animation" do
      state = KittyGraphics.new(100, 100)

      state = KittyGraphics.add_animation_frame(state, "frame1")
      state = KittyGraphics.add_animation_frame(state, "frame2")

      assert length(state.animation_frames) == 2
      assert Enum.at(state.animation_frames, 0) == "frame1"
      assert Enum.at(state.animation_frames, 1) == "frame2"
    end
  end

  describe "get_current_frame/1" do
    test "returns pixel_buffer when no frames" do
      state = %KittyGraphics{
        pixel_buffer: "buffer_data",
        animation_frames: [],
        current_frame: 0
      }

      assert KittyGraphics.get_current_frame(state) == "buffer_data"
    end

    test "returns current animation frame" do
      state = %KittyGraphics{
        pixel_buffer: "buffer_data",
        animation_frames: ["frame1", "frame2", "frame3"],
        current_frame: 1
      }

      assert KittyGraphics.get_current_frame(state) == "frame2"
    end
  end

  describe "next_frame/1" do
    test "advances to next frame" do
      state = %KittyGraphics{
        animation_frames: ["f1", "f2", "f3"],
        current_frame: 0
      }

      state = KittyGraphics.next_frame(state)
      assert state.current_frame == 1

      state = KittyGraphics.next_frame(state)
      assert state.current_frame == 2
    end

    test "wraps around to first frame" do
      state = %KittyGraphics{
        animation_frames: ["f1", "f2", "f3"],
        current_frame: 2
      }

      state = KittyGraphics.next_frame(state)
      assert state.current_frame == 0
    end

    test "does nothing with no frames" do
      state = %KittyGraphics{
        animation_frames: [],
        current_frame: 0
      }

      state = KittyGraphics.next_frame(state)
      assert state.current_frame == 0
    end
  end

  describe "encode/1" do
    test "returns empty binary for empty buffer" do
      state = KittyGraphics.new()

      assert KittyGraphics.encode(state) == <<>>
    end

    test "encodes image with data" do
      state = %KittyGraphics{
        width: 2,
        height: 2,
        format: :rgba,
        compression: :none,
        pixel_buffer: <<255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255>>
      }

      encoded = KittyGraphics.encode(state)

      # Should start with APC sequence
      assert String.starts_with?(encoded, "\e_G")
      # Should end with ST
      assert String.ends_with?(encoded, "\e\\")
      # Should contain control data
      assert encoded =~ "a=T"
      assert encoded =~ "f=32"
    end

    test "encodes with compression" do
      state = %KittyGraphics{
        width: 10,
        height: 10,
        format: :rgba,
        compression: :zlib,
        pixel_buffer: String.duplicate("RGBA", 100)
      }

      encoded = KittyGraphics.encode(state)

      assert encoded =~ "o=z"
    end
  end

  describe "decode/1" do
    test "decodes kitty sequence" do
      # Create a simple encoded sequence
      data = Base.encode64("pixel data")
      sequence = "\e_Ga=t,f=24,s=10,v=10;#{data}\e\\"

      state = KittyGraphics.decode(sequence)

      assert state.format == :rgb
      assert state.width == 10
      assert state.height == 10
    end

    test "returns empty state for invalid sequence" do
      state = KittyGraphics.decode("not a kitty sequence")

      assert state.width == 0
      assert state.height == 0
    end
  end

  describe "process_sequence/2" do
    test "processes transmit action" do
      state = KittyGraphics.new()
      data = Base.encode64("RGBA")

      {new_state, :ok} = KittyGraphics.process_sequence(state, "a=t,f=32,s=1,v=1;#{data}")

      assert new_state.format == :rgba
      assert new_state.width == 1
      assert new_state.height == 1
      assert new_state.pixel_buffer == "RGBA"
    end

    test "returns error for invalid data" do
      state = KittyGraphics.new()

      {_state, {:error, _reason}} = KittyGraphics.process_sequence(state, "a=t;invalid_base64!!!")
    end
  end

  describe "supported?/0" do
    test "returns boolean" do
      result = KittyGraphics.supported?()

      assert is_boolean(result) or result in [:supported, :partial_support, :unknown]
    end
  end

  describe "generate_delete_command/2" do
    test "generates delete by id command" do
      cmd = KittyGraphics.generate_delete_command(42, %{delete_action: :id})

      assert cmd =~ "\e_G"
      assert cmd =~ "a=d"
      assert cmd =~ "d=i"
      assert cmd =~ "i=42"
      assert String.ends_with?(cmd, "\e\\")
    end

    test "generates delete all command" do
      cmd = KittyGraphics.generate_delete_command(0, %{delete_action: :all})

      assert cmd =~ "d=A"
    end

    test "generates delete by z-index command" do
      cmd = KittyGraphics.generate_delete_command(0, %{delete_action: :z_index, z: 5})

      assert cmd =~ "d=z"
      assert cmd =~ "z=5"
    end
  end

  describe "generate_query_command/0" do
    test "generates query command" do
      cmd = KittyGraphics.generate_query_command()

      assert cmd =~ "\e_G"
      assert cmd =~ "a=q"
      assert String.ends_with?(cmd, "\e\\")
    end
  end
end
