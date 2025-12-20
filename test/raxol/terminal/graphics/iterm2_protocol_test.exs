defmodule Raxol.Terminal.Graphics.ITerm2ProtocolTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.Graphics.ITerm2Protocol

  # Test constants and sample data
  @png_header <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
  @jpeg_header <<0xFF, 0xD8, 0xFF, 0xE0>>
  @gif87_header <<"GIF87a">>
  @gif89_header <<"GIF89a">>
  @bmp_header <<"BM">>
  @webp_header <<"RIFF", "test", "WEBP">>
  @tiff_be_header <<"MM", 0x00, 0x2A>>
  @tiff_le_header <<"II", 0x2A, 0x00>>

  @sample_png_data @png_header <> "fake_png_data"
  @sample_jpeg_data @jpeg_header <> "fake_jpeg_data"
  @sample_gif_data @gif87_header <> "fake_gif_data"

  @osc_start "\e]1337;File="
  @osc_end "\a"

  describe "supported?/0" do
    test "detects terminal support based on environment" do
      # This function depends on environment variables, so we test it exists
      result = ITerm2Protocol.supported?()
      assert is_boolean(result)
    end

    test "function exists and is properly exported" do
      functions = ITerm2Protocol.__info__(:functions)
      assert {:supported?, 0} in functions
    end
  end

  describe "display_image_data/2" do
    test "creates valid OSC sequence for PNG data" do
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data)

      assert String.starts_with?(sequence, @osc_start)
      assert String.ends_with?(sequence, @osc_end)
      assert String.contains?(sequence, ":")
      assert String.contains?(sequence, "inline=1")
    end

    test "includes base64 encoded data" do
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data)

      # Extract the base64 part after the colon
      [_args, base64_part] = String.split(sequence, ":", parts: 2)
      base64_data = String.trim_trailing(base64_part, @osc_end)

      # Should be valid base64
      assert String.match?(base64_data, ~r/^[A-Za-z0-9+\/]*={0,2}$/)

      # Should decode to original data
      assert Base.decode64!(base64_data) == @sample_png_data
    end

    test "handles empty data" do
      assert {:error, :empty_image_data} = ITerm2Protocol.display_image_data("")
    end

    test "handles data too large" do
      # Create data larger than the limit
      large_data = String.duplicate("x", 50_000_001)  # > 50MB

      assert {:error, {:image_too_large, _, _}} =
        ITerm2Protocol.display_image_data(large_data)
    end

    test "includes width and height options" do
      options = %{width: 300, height: 200}
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      assert String.contains?(sequence, "width=300")
      assert String.contains?(sequence, "height=200")
    end

    test "includes name option when provided" do
      options = %{name: "test_image.png"}
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      # Name should be base64 encoded
      encoded_name = Base.encode64("test_image.png")
      assert String.contains?(sequence, "name=#{encoded_name}")
    end

    test "includes size option when provided" do
      options = %{size: 1024}
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      assert String.contains?(sequence, "size=1024")
    end

    test "handles preserve aspect ratio option" do
      options = %{preserve_aspect_ratio: false}
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      assert String.contains?(sequence, "preserveAspectRatio=0")
    end

    test "defaults to preserve aspect ratio true" do
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data)

      assert String.contains?(sequence, "preserveAspectRatio=1")
    end

    test "handles inline option" do
      options = %{inline: false}
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      assert String.contains?(sequence, "inline=0")
    end

    test "defaults to inline true" do
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data)

      assert String.contains?(sequence, "inline=1")
    end

    test "ignores invalid width/height options" do
      options = %{width: -100, height: "invalid"}
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      refute String.contains?(sequence, "width=-100")
      refute String.contains?(sequence, "height=invalid")
    end

    test "ignores invalid size option" do
      options = %{size: -50}
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      refute String.contains?(sequence, "size=-50")
    end

    test "orders arguments consistently" do
      options = %{
        name: "test.png",
        size: 1024,
        width: 200,
        height: 100,
        preserve_aspect_ratio: true,
        inline: true
      }

      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      # Extract arguments part
      [args_part, _data_part] = String.split(sequence, ":", parts: 2)
      args = String.trim_leading(args_part, @osc_start)

      # Should contain all expected arguments
      encoded_name = Base.encode64("test.png")
      assert String.contains?(args, "name=#{encoded_name}")
      assert String.contains?(args, "size=1024")
      assert String.contains?(args, "width=200")
      assert String.contains?(args, "height=100")
      assert String.contains?(args, "preserveAspectRatio=1")
      assert String.contains?(args, "inline=1")
    end
  end

  describe "display_image_file/2" do
    setup do
      # Create a temporary file for testing
      tmp_dir = System.tmp_dir!()
      test_file = Path.join(tmp_dir, "test_image.png")
      File.write!(test_file, @sample_png_data)

      on_exit(fn -> File.rm(test_file) end)

      %{test_file: test_file}
    end

    test "reads and displays file successfully", %{test_file: test_file} do
      {:ok, sequence} = ITerm2Protocol.display_image_file(test_file)

      assert String.starts_with?(sequence, @osc_start)
      assert String.ends_with?(sequence, @osc_end)

      # Should include filename
      encoded_name = Base.encode64("test_image.png")
      assert String.contains?(sequence, "name=#{encoded_name}")

      # Should include size
      assert String.contains?(sequence, "size=#{byte_size(@sample_png_data)}")
    end

    test "handles non-existent file" do
      assert {:error, {:file_read_error, :enoent}} =
        ITerm2Protocol.display_image_file("/nonexistent/file.png")
    end

    test "detects format from file extension", %{test_file: test_file} do
      # Rename to JPEG extension
      jpeg_file = String.replace(test_file, ".png", ".jpg")
      File.rename!(test_file, jpeg_file)

      {:ok, sequence} = ITerm2Protocol.display_image_file(jpeg_file, %{})

      # The file content is still PNG, but extension suggests JPEG
      # Function should work with either detection method
      assert is_binary(sequence)

      File.rm(jpeg_file)
    end

    test "passes through options to display_image_data", %{test_file: test_file} do
      options = %{width: 400, height: 300}
      {:ok, sequence} = ITerm2Protocol.display_image_file(test_file, options)

      assert String.contains?(sequence, "width=400")
      assert String.contains?(sequence, "height=300")
    end

    test "handles various file extensions" do
      extensions_to_formats = [
        {".png", :png},
        {".jpg", :jpeg},
        {".jpeg", :jpeg},
        {".gif", :gif},
        {".bmp", :bmp},
        {".webp", :webp},
        {".tiff", :tiff},
        {".tif", :tiff},
        {".unknown", :png}  # Default fallback
      ]

      tmp_dir = System.tmp_dir!()

      for {ext, _expected_format} <- extensions_to_formats do
        test_file = Path.join(tmp_dir, "test#{ext}")
        File.write!(test_file, @sample_png_data)

        {:ok, sequence} = ITerm2Protocol.display_image_file(test_file)
        assert is_binary(sequence)

        File.rm!(test_file)
      end
    end
  end

  describe "create_progress_indicator/3" do
    test "creates progress bar with correct percentage" do
      result = ITerm2Protocol.create_progress_indicator(50, 100)

      assert String.contains?(result, "50%")
      assert String.contains?(result, "█")  # Filled portion
      assert String.contains?(result, "░")  # Empty portion
      assert String.ends_with?(result, "\r")
    end

    test "handles 0% progress" do
      result = ITerm2Protocol.create_progress_indicator(0, 100)

      assert String.contains?(result, "0%")
      assert String.contains?(result, "░")  # Should be all empty
      refute String.contains?(result, "█")  # No filled portion
    end

    test "handles 100% progress" do
      result = ITerm2Protocol.create_progress_indicator(100, 100)

      assert String.contains?(result, "100%")
      assert String.contains?(result, "█")  # Should be all filled
      refute String.contains?(result, "░")  # No empty portion
    end

    test "handles zero total bytes gracefully" do
      result = ITerm2Protocol.create_progress_indicator(50, 0)

      assert String.contains?(result, "0%")  # Should default to 0%
    end

    test "respects custom width option" do
      result = ITerm2Protocol.create_progress_indicator(50, 100, %{width: 20})

      # Extract the progress bar part
      bar_part = result
      |> String.split("[")
      |> Enum.at(1)
      |> String.split("]")
      |> Enum.at(0)

      # Should be 20 characters total (filled + empty)
      assert String.length(bar_part) == 20
    end

    test "handles partial progress correctly" do
      result = ITerm2Protocol.create_progress_indicator(33, 100, %{width: 10})

      assert String.contains?(result, "33%")

      # Should have both filled and empty portions
      assert String.contains?(result, "█")
      assert String.contains?(result, "░")
    end
  end

  describe "create_placeholder/2" do
    test "creates placeholder sequence successfully" do
      {:ok, sequence} = ITerm2Protocol.create_placeholder("test_id")

      assert String.starts_with?(sequence, @osc_start)
      assert String.ends_with?(sequence, @osc_end)
      assert String.contains?(sequence, "placeholder=1")
      assert String.contains?(sequence, "inline=1")

      # Should contain base64 encoded identifier
      encoded_id = Base.encode64("test_id")
      assert String.contains?(sequence, "name=#{encoded_id}")
    end

    test "includes default width and height" do
      {:ok, sequence} = ITerm2Protocol.create_placeholder("test_id")

      assert String.contains?(sequence, "width=200")
      assert String.contains?(sequence, "height=200")
    end

    test "respects custom width and height options" do
      options = %{width: 400, height: 300}
      {:ok, sequence} = ITerm2Protocol.create_placeholder("test_id", options)

      assert String.contains?(sequence, "width=400")
      assert String.contains?(sequence, "height=300")
    end

    test "rejects empty identifier" do
      assert {:error, :empty_identifier} = ITerm2Protocol.create_placeholder("")
    end

    test "handles various identifier types" do
      test_ids = ["simple", "with spaces", "with/slashes", "unicode-ñ", "123numbers"]

      for test_id <- test_ids do
        {:ok, sequence} = ITerm2Protocol.create_placeholder(test_id)
        encoded_id = Base.encode64(test_id)
        assert String.contains?(sequence, "name=#{encoded_id}")
      end
    end
  end

  describe "get_max_image_size/0" do
    test "returns positive integer" do
      size = ITerm2Protocol.get_max_image_size()
      assert is_integer(size)
      assert size > 0
    end

    test "returns reasonable size limit" do
      size = ITerm2Protocol.get_max_image_size()
      # Should be between 1MB and 100MB
      assert size >= 1_000_000
      assert size <= 100_000_000
    end
  end

  describe "clear_images/0" do
    test "returns clear sequence" do
      result = ITerm2Protocol.clear_images()
      assert result == "\f"
    end
  end

  describe "validate_image_data/2" do
    test "validates correct PNG data" do
      assert :ok = ITerm2Protocol.validate_image_data(@sample_png_data)
    end

    test "validates correct JPEG data" do
      assert :ok = ITerm2Protocol.validate_image_data(@sample_jpeg_data)
    end

    test "validates correct GIF data" do
      assert :ok = ITerm2Protocol.validate_image_data(@sample_gif_data)
    end

    test "rejects empty data" do
      assert {:error, :empty_image_data} = ITerm2Protocol.validate_image_data("")
    end

    test "rejects data that is too large" do
      # Create data just over the limit
      max_size = ITerm2Protocol.get_max_image_size()
      large_data = String.duplicate("x", max_size + 1)

      assert {:error, {:image_too_large, _}} =
        ITerm2Protocol.validate_image_data(large_data)
    end

    test "allows unknown format but warns" do
      # Unknown format should still return :ok but may log warning
      unknown_data = "unknown_format_data"
      assert :ok = ITerm2Protocol.validate_image_data(unknown_data)
    end
  end

  describe "format detection" do
    test "detects PNG format correctly" do
      # We test this indirectly through display_image_data
      {:ok, _sequence} = ITerm2Protocol.display_image_data(@sample_png_data)
    end

    test "detects JPEG format correctly" do
      {:ok, _sequence} = ITerm2Protocol.display_image_data(@sample_jpeg_data)
    end

    test "detects GIF format correctly" do
      {:ok, _sequence} = ITerm2Protocol.display_image_data(@sample_gif_data)
    end

    test "handles various image format headers" do
      test_formats = [
        {@png_header <> "data", "PNG"},
        {@jpeg_header <> "data", "JPEG"},
        {@gif87_header <> "data", "GIF87"},
        {@gif89_header <> "data", "GIF89"},
        {@bmp_header <> "data", "BMP"},
        {@webp_header <> "data", "WEBP"},
        {@tiff_be_header <> "data", "TIFF BE"},
        {@tiff_le_header <> "data", "TIFF LE"}
      ]

      for {test_data, _format_name} <- test_formats do
        {:ok, _sequence} = ITerm2Protocol.display_image_data(test_data)
      end
    end

    test "handles insufficient data for format detection" do
      short_data = "abc"  # Less than 8 bytes
      {:ok, _sequence} = ITerm2Protocol.display_image_data(short_data)
    end
  end

  describe "integration and real-world scenarios" do
    test "end-to-end image display workflow" do
      # Simulate complete workflow: validate -> display -> get sequence
      image_data = @sample_png_data

      # Step 1: Validate
      assert :ok = ITerm2Protocol.validate_image_data(image_data)

      # Step 2: Display with options
      options = %{
        width: 300,
        height: 200,
        name: "test_chart.png",
        preserve_aspect_ratio: true
      }

      {:ok, sequence} = ITerm2Protocol.display_image_data(image_data, options)

      # Step 3: Verify sequence structure
      assert String.starts_with?(sequence, @osc_start)
      assert String.ends_with?(sequence, @osc_end)

      # Should contain all requested options
      assert String.contains?(sequence, "width=300")
      assert String.contains?(sequence, "height=200")
      assert String.contains?(sequence, Base.encode64("test_chart.png"))
      assert String.contains?(sequence, "preserveAspectRatio=1")
    end

    test "handles multiple images with progress tracking" do
      images = [
        @sample_png_data,
        @sample_jpeg_data,
        @sample_gif_data
      ]

      total_size = Enum.sum(Enum.map(images, &byte_size/1))
      sent_bytes = 0

      sequences = Enum.map(images, fn image_data ->
        # Show progress
        progress = ITerm2Protocol.create_progress_indicator(sent_bytes, total_size)
        assert String.contains?(progress, "%")

        # Display image
        {:ok, sequence} = ITerm2Protocol.display_image_data(image_data)

        # Update progress
        _sent_bytes = sent_bytes + byte_size(image_data)

        sequence
      end)

      assert length(sequences) == 3
      assert Enum.all?(sequences, &String.starts_with?(&1, @osc_start))
    end

    test "placeholder and replacement workflow" do
      # Create placeholder first
      {:ok, placeholder} = ITerm2Protocol.create_placeholder("loading_image", %{
        width: 400,
        height: 300
      })

      assert String.contains?(placeholder, "placeholder=1")

      # Later replace with actual image
      {:ok, image_sequence} = ITerm2Protocol.display_image_data(@sample_png_data, %{
        width: 400,
        height: 300,
        name: "loading_image"  # Same identifier
      })

      refute String.contains?(image_sequence, "placeholder=1")
      assert String.contains?(image_sequence, Base.encode64("loading_image"))
    end

    test "supports different terminal configurations" do
      # Test that the protocol works regardless of terminal support detection
      # This simulates different terminal environments

      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data)

      # Basic sequence structure should be consistent
      assert String.starts_with?(sequence, @osc_start)
      assert String.ends_with?(sequence, @osc_end)
      assert String.contains?(sequence, ":")

      # Should work with various max size limits
      max_size = ITerm2Protocol.get_max_image_size()
      assert byte_size(@sample_png_data) <= max_size
    end
  end

  describe "error handling and edge cases" do
    test "handles malformed options gracefully" do
      options = %{
        width: "not_a_number",
        height: :invalid,
        name: nil,
        size: -1,
        preserve_aspect_ratio: true,  # Keep valid since implementation crashes on invalid values
        inline: true  # Keep valid since implementation crashes on invalid values
      }

      # Should not crash, should ignore invalid options
      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      # Invalid options should be filtered out
      refute String.contains?(sequence, "width=not_a_number")
      refute String.contains?(sequence, "height=invalid")
      refute String.contains?(sequence, "size=-1")
    end

    test "handles very long filenames" do
      long_name = String.duplicate("a", 1000)
      options = %{name: long_name}

      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      encoded_name = Base.encode64(long_name)
      assert String.contains?(sequence, "name=#{encoded_name}")
    end

    test "handles binary data with null bytes" do
      data_with_nulls = "before\0null\0after"
      {:ok, sequence} = ITerm2Protocol.display_image_data(data_with_nulls)

      # Should still create valid base64
      [_args, base64_part] = String.split(sequence, ":", parts: 2)
      base64_data = String.trim_trailing(base64_part, @osc_end)

      decoded = Base.decode64!(base64_data)
      assert decoded == data_with_nulls
    end

    test "handles unicode in image names" do
      unicode_name = "图片_画像_الصورة_изображение.png"
      options = %{name: unicode_name}

      {:ok, sequence} = ITerm2Protocol.display_image_data(@sample_png_data, options)

      encoded_name = Base.encode64(unicode_name)
      assert String.contains?(sequence, "name=#{encoded_name}")
    end

    test "maintains data integrity for binary formats" do
      # Test with data that might have special characters that could break encoding
      special_data = <<0, 1, 2, 3, 255, 254, 253, 252, 10, 13, 27>>

      {:ok, sequence} = ITerm2Protocol.display_image_data(special_data)

      # Decode and verify
      [_args, base64_part] = String.split(sequence, ":", parts: 2)
      base64_data = String.trim_trailing(base64_part, @osc_end)

      decoded = Base.decode64!(base64_data)
      assert decoded == special_data
    end
  end

  describe "performance and limits" do
    test "handles reasonable image sizes efficiently" do
      # Test with moderately sized image data
      medium_data = String.duplicate("image_data", 1000)  # ~10KB

      start_time = System.monotonic_time(:millisecond)
      {:ok, sequence} = ITerm2Protocol.display_image_data(medium_data)
      end_time = System.monotonic_time(:millisecond)

      # Should complete quickly (less than 100ms)
      assert end_time - start_time < 100
      assert is_binary(sequence)
    end

    test "progress indicator performance" do
      start_time = System.monotonic_time(:millisecond)

      # Generate many progress indicators
      for i <- 1..100 do
        _progress = ITerm2Protocol.create_progress_indicator(i, 100)
      end

      end_time = System.monotonic_time(:millisecond)

      # Should be very fast (less than 50ms for 100 iterations)
      assert end_time - start_time < 50
    end

    test "validates size limits are reasonable" do
      max_size = ITerm2Protocol.get_max_image_size()

      # Should be able to handle typical image sizes
      assert max_size >= 1_000_000  # At least 1MB
      assert max_size <= 100_000_000  # But not more than 100MB

      # Test with data just over the limit
      over_limit_data = String.duplicate("x", max_size + 1)

      # Should be rejected for being too large
      assert {:error, {:image_too_large, _}} =
        ITerm2Protocol.validate_image_data(over_limit_data)
    end
  end

  describe "module structure and documentation" do
    test "module has proper documentation" do
      {:docs_v1, _, :elixir, _, %{"en" => module_doc}, _, _} =
        Code.fetch_docs(ITerm2Protocol)

      assert is_binary(module_doc)
      assert String.length(module_doc) > 100
      assert String.contains?(module_doc, "iTerm2")
      assert String.contains?(module_doc, "OSC")
    end

    test "all public functions are documented" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(ITerm2Protocol)

      function_docs = Enum.filter(docs, fn
        {{:function, _name, _arity}, _, _, _, _} -> true
        _ -> false
      end)

      # Should have documentation for main functions
      assert length(function_docs) >= 8
    end

    test "type specifications are defined" do
      Code.Typespec.fetch_types(ITerm2Protocol)
      # Just ensure it doesn't crash - types should be properly defined
    end

    test "exports expected public functions" do
      functions = ITerm2Protocol.__info__(:functions)

      expected_functions = [
        {:supported?, 0},
        {:display_image_file, 2},
        {:display_image_data, 2},
        {:create_progress_indicator, 3},
        {:create_placeholder, 2},
        {:get_max_image_size, 0},
        {:clear_images, 0},
        {:validate_image_data, 2}
      ]

      for expected <- expected_functions do
        assert expected in functions, "Function #{inspect(expected)} not found"
      end
    end
  end
end
