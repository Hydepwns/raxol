defmodule Raxol.Bench.KittyGraphicsBenchmark do
  @moduledoc """
  Performance benchmarks for the Kitty Graphics Protocol implementation.

  Measures performance across key operations:
  - Parsing control sequences
  - Encoding images to APC sequences
  - Decoding APC sequences
  - Base64 encoding/decoding
  - Compression/decompression
  - Chunked transmission handling

  ## Usage

      mix run bench/suites/kitty_graphics_benchmark.exs

  Or run specific benchmarks:

      iex> Raxol.Bench.KittyGraphicsBenchmark.run_parsing_benchmark()
      iex> Raxol.Bench.KittyGraphicsBenchmark.run_encoding_benchmark()
  """

  alias Raxol.Terminal.ANSI.{KittyGraphics, KittyParser}

  # Test data sizes
  @small_image_size {16, 16}
  @medium_image_size {100, 100}
  @large_image_size {500, 500}
  @xlarge_image_size {1920, 1080}

  # ============================================================================
  # Main Benchmark Runner
  # ============================================================================

  @doc """
  Run all Kitty graphics benchmarks.
  """
  def run_all(opts \\ []) do
    IO.puts("\n=== Kitty Graphics Protocol Benchmarks ===\n")

    run_parsing_benchmark(opts)
    run_encoding_benchmark(opts)
    run_compression_benchmark(opts)
    run_chunking_benchmark(opts)
    run_roundtrip_benchmark(opts)
    run_memory_benchmark(opts)

    IO.puts("\n=== Benchmarks Complete ===\n")
  end

  # ============================================================================
  # Parsing Benchmarks
  # ============================================================================

  @doc """
  Benchmark parsing performance for Kitty control sequences.
  """
  def run_parsing_benchmark(opts \\ []) do
    IO.puts("\n--- Parsing Benchmarks ---\n")

    iterations = Keyword.get(opts, :iterations, 10_000)
    warmup = Keyword.get(opts, :warmup, 1000)

    # Test sequences of varying complexity
    simple_sequence = "a=t,f=32,s=100,v=100"
    medium_sequence = "a=T,f=32,s=500,v=500,i=123,p=1,x=10,y=20,z=5,o=z,m=1"
    complex_sequence = "a=T,f=32,s=1920,v=1080,i=999,p=42,x=100,y=200,X=10,Y=5,z=-1,q=2,o=z,m=1"

    benchmarks = %{
      "Simple control (5 params)" => fn -> parse_control(simple_sequence) end,
      "Medium control (10 params)" => fn -> parse_control(medium_sequence) end,
      "Complex control (13 params)" => fn -> parse_control(complex_sequence) end
    }

    results = run_benchmark_set(benchmarks, iterations, warmup)
    print_results("Parsing", results)
    results
  end

  defp parse_control(data) do
    state = KittyParser.ParserState.new()
    KittyParser.parse_control_data(data, state)
  end

  # ============================================================================
  # Encoding Benchmarks
  # ============================================================================

  @doc """
  Benchmark encoding performance for various image sizes.
  """
  def run_encoding_benchmark(opts \\ []) do
    IO.puts("\n--- Encoding Benchmarks ---\n")

    iterations = Keyword.get(opts, :iterations, 1000)
    warmup = Keyword.get(opts, :warmup, 100)

    small_image = create_test_image(@small_image_size)
    medium_image = create_test_image(@medium_image_size)
    large_image = create_test_image(@large_image_size)

    benchmarks = %{
      "Encode 16x16 (1KB)" => fn -> KittyGraphics.encode(small_image) end,
      "Encode 100x100 (40KB)" => fn -> KittyGraphics.encode(medium_image) end,
      "Encode 500x500 (1MB)" => fn -> KittyGraphics.encode(large_image) end
    }

    results = run_benchmark_set(benchmarks, iterations, warmup)
    print_results("Encoding", results)
    results
  end

  # ============================================================================
  # Compression Benchmarks
  # ============================================================================

  @doc """
  Benchmark compression/decompression performance.
  """
  def run_compression_benchmark(opts \\ []) do
    IO.puts("\n--- Compression Benchmarks ---\n")

    iterations = Keyword.get(opts, :iterations, 1000)
    warmup = Keyword.get(opts, :warmup, 100)

    small_data = generate_pixel_data(@small_image_size)
    medium_data = generate_pixel_data(@medium_image_size)
    large_data = generate_pixel_data(@large_image_size)

    # Pre-compress for decompression benchmarks
    small_compressed = :zlib.compress(small_data)
    medium_compressed = :zlib.compress(medium_data)
    large_compressed = :zlib.compress(large_data)

    benchmarks = %{
      "Compress 1KB" => fn -> :zlib.compress(small_data) end,
      "Compress 40KB" => fn -> :zlib.compress(medium_data) end,
      "Compress 1MB" => fn -> :zlib.compress(large_data) end,
      "Decompress 1KB" => fn -> KittyParser.decompress(small_compressed, :zlib) end,
      "Decompress 40KB" => fn -> KittyParser.decompress(medium_compressed, :zlib) end,
      "Decompress 1MB" => fn -> KittyParser.decompress(large_compressed, :zlib) end
    }

    results = run_benchmark_set(benchmarks, iterations, warmup)
    print_results("Compression", results)
    results
  end

  # ============================================================================
  # Chunking Benchmarks
  # ============================================================================

  @doc """
  Benchmark chunked transmission handling.
  """
  def run_chunking_benchmark(opts \\ []) do
    IO.puts("\n--- Chunking Benchmarks ---\n")

    iterations = Keyword.get(opts, :iterations, 1000)
    warmup = Keyword.get(opts, :warmup, 100)

    # Create images that will require chunking (>4KB encoded)
    medium_image = create_test_image(@medium_image_size)
    large_image = create_test_image(@large_image_size)
    xlarge_image = create_test_image(@xlarge_image_size)

    benchmarks = %{
      "Chunk 40KB (10 chunks)" => fn -> KittyGraphics.encode(medium_image) end,
      "Chunk 1MB (256 chunks)" => fn -> KittyGraphics.encode(large_image) end,
      "Chunk 8MB (2048 chunks)" => fn -> KittyGraphics.encode(xlarge_image) end
    }

    results = run_benchmark_set(benchmarks, iterations, warmup)
    print_results("Chunking", results)
    results
  end

  # ============================================================================
  # Roundtrip Benchmarks
  # ============================================================================

  @doc """
  Benchmark full encode/decode roundtrip.
  """
  def run_roundtrip_benchmark(opts \\ []) do
    IO.puts("\n--- Roundtrip Benchmarks ---\n")

    iterations = Keyword.get(opts, :iterations, 500)
    warmup = Keyword.get(opts, :warmup, 50)

    small_image = create_test_image(@small_image_size)
    medium_image = create_test_image(@medium_image_size)

    # Pre-encode for decode benchmarks
    small_encoded = KittyGraphics.encode(small_image)
    medium_encoded = KittyGraphics.encode(medium_image)

    benchmarks = %{
      "Roundtrip 16x16" => fn -> roundtrip(small_image) end,
      "Roundtrip 100x100" => fn -> roundtrip(medium_image) end,
      "Decode 16x16" => fn -> KittyGraphics.decode(small_encoded) end,
      "Decode 100x100" => fn -> KittyGraphics.decode(medium_encoded) end
    }

    results = run_benchmark_set(benchmarks, iterations, warmup)
    print_results("Roundtrip", results)
    results
  end

  defp roundtrip(image) do
    encoded = KittyGraphics.encode(image)
    KittyGraphics.decode(encoded)
  end

  # ============================================================================
  # Memory Benchmarks
  # ============================================================================

  @doc """
  Benchmark memory usage for various operations.
  """
  def run_memory_benchmark(opts \\ []) do
    IO.puts("\n--- Memory Benchmarks ---\n")

    iterations = Keyword.get(opts, :iterations, 100)

    small_image = create_test_image(@small_image_size)
    medium_image = create_test_image(@medium_image_size)
    large_image = create_test_image(@large_image_size)

    results = %{
      "Image 16x16" => measure_memory(fn -> KittyGraphics.encode(small_image) end, iterations),
      "Image 100x100" => measure_memory(fn -> KittyGraphics.encode(medium_image) end, iterations),
      "Image 500x500" => measure_memory(fn -> KittyGraphics.encode(large_image) end, iterations)
    }

    print_memory_results(results)
    results
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp create_test_image({width, height}) do
    data = generate_pixel_data({width, height})

    KittyGraphics.new(width, height)
    |> KittyGraphics.set_data(data)
  end

  defp generate_pixel_data({width, height}) do
    # Generate RGBA pixel data (4 bytes per pixel)
    pixel_count = width * height

    for _ <- 1..pixel_count, into: <<>> do
      # Random-ish but deterministic pixel data
      <<:rand.uniform(255), :rand.uniform(255), :rand.uniform(255), 255>>
    end
  end

  defp run_benchmark_set(benchmarks, iterations, warmup) do
    Enum.map(benchmarks, fn {name, fun} ->
      # Warmup
      for _ <- 1..warmup, do: fun.()

      # Measure
      times =
        for _ <- 1..iterations do
          start = System.monotonic_time(:nanosecond)
          fun.()
          System.monotonic_time(:nanosecond) - start
        end

      {name, calculate_stats(times)}
    end)
    |> Map.new()
  end

  defp calculate_stats(times) do
    sorted = Enum.sort(times)
    count = length(times)
    sum = Enum.sum(times)

    %{
      min: Enum.min(times) / 1000,
      max: Enum.max(times) / 1000,
      mean: sum / count / 1000,
      median: Enum.at(sorted, div(count, 2)) / 1000,
      p95: Enum.at(sorted, round(count * 0.95) - 1) / 1000,
      p99: Enum.at(sorted, round(count * 0.99) - 1) / 1000,
      total_us: sum / 1000,
      iterations: count
    }
  end

  defp measure_memory(fun, iterations) do
    :erlang.garbage_collect()
    {:memory, memory_before} = :erlang.process_info(self(), :memory)

    for _ <- 1..iterations, do: fun.()

    :erlang.garbage_collect()
    {:memory, memory_after} = :erlang.process_info(self(), :memory)

    diff = max(0, memory_after - memory_before)

    %{
      bytes_per_iteration: diff / iterations,
      total_bytes: diff,
      iterations: iterations
    }
  end

  defp print_results(category, results) do
    IO.puts("#{category} Performance:")
    IO.puts(String.duplicate("-", 70))

    results
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {name, stats} ->
      IO.puts("  #{String.pad_trailing(name, 30)} | " <>
        "mean: #{format_time(stats.mean)} | " <>
        "p95: #{format_time(stats.p95)} | " <>
        "p99: #{format_time(stats.p99)}")
    end)

    IO.puts("")
  end

  defp print_memory_results(results) do
    IO.puts("Memory Usage:")
    IO.puts(String.duplicate("-", 70))

    results
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {name, stats} ->
      IO.puts("  #{String.pad_trailing(name, 30)} | " <>
        "~#{format_bytes(stats.bytes_per_iteration)} per operation")
    end)

    IO.puts("")
  end

  defp format_time(us) when us < 1, do: "#{Float.round(us * 1000, 2)}ns"
  defp format_time(us) when us < 1000, do: "#{Float.round(us, 2)}us"
  defp format_time(us) when us < 1_000_000, do: "#{Float.round(us / 1000, 2)}ms"
  defp format_time(us), do: "#{Float.round(us / 1_000_000, 2)}s"

  defp format_bytes(bytes) when bytes < 1024, do: "#{round(bytes)}B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 2)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 2)}MB"

  @doc """
  Generate a performance report as a map.
  """
  def generate_report(opts \\ []) do
    %{
      timestamp: DateTime.utc_now(),
      parsing: run_parsing_benchmark(opts),
      encoding: run_encoding_benchmark(opts),
      compression: run_compression_benchmark(opts),
      chunking: run_chunking_benchmark(opts),
      roundtrip: run_roundtrip_benchmark(opts),
      memory: run_memory_benchmark(opts)
    }
  end
end

# Run benchmarks when script is executed directly
# Seed random for reproducible pixel data
:rand.seed(:exsss, {1, 2, 3})

Raxol.Bench.KittyGraphicsBenchmark.run_all()
