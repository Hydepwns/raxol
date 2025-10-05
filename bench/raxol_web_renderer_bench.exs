# Performance benchmarks for RaxolWeb.Renderer
#
# Run with: mix run bench/raxol_web_renderer_bench.exs
#
# These benchmarks measure the performance of the core rendering engine
# to ensure it can handle 60fps updates (< 16.67ms per frame).

alias RaxolWeb.Renderer

# Helper to create buffers of various sizes
defmodule BenchHelper do
  def create_buffer(width, height, opts \\ []) do
    styled = Keyword.get(opts, :styled, false)
    varied = Keyword.get(opts, :varied, false)

    lines =
      for _y <- 1..height do
        cells =
          for x <- 1..width do
            char = if varied, do: Enum.random(~w(a b c d e f g h i j)), else: " "

            style =
              if styled do
                %{
                  bold: rem(x, 3) == 0,
                  italic: rem(x, 5) == 0,
                  underline: false,
                  reverse: false,
                  fg_color: Enum.random([:red, :green, :blue, :yellow, nil]),
                  bg_color: nil
                }
              else
                %{bold: false, italic: false, underline: false, reverse: false, fg_color: nil, bg_color: nil}
              end

            %{char: char, style: style}
          end

        %{cells: cells}
      end

    %{lines: lines, width: width, height: height}
  end

  def modify_buffer(buffer, change_percent) do
    # Modify a percentage of cells in the buffer
    num_cells = buffer.width * buffer.height
    num_changes = max(1, round(num_cells * change_percent / 100))
    change_interval = max(1, div(num_cells, num_changes))

    modified_lines =
      Enum.with_index(buffer.lines)
      |> Enum.map(fn {line, y} ->
        modified_cells =
          Enum.with_index(line.cells)
          |> Enum.map(fn {cell, x} ->
            # Change cells in a deterministic pattern
            if rem(x + y * buffer.width, change_interval) == 0 do
              %{cell | char: "X"}
            else
              cell
            end
          end)

        %{cells: modified_cells}
      end)

    %{buffer | lines: modified_lines}
  end
end

IO.puts("\n=== RaxolWeb Renderer Performance Benchmarks ===\n")

# Benchmark 1: First render (cold cache)
IO.puts("1. First Render (Cold Cache)")
IO.puts("   Target: < 16.67ms (60fps)")

for {width, height} <- [{80, 24}, {120, 40}, {200, 50}] do
  buffer = BenchHelper.create_buffer(width, height)

  {time_us, {_html, _renderer}} =
    :timer.tc(fn ->
      renderer = Renderer.new()
      Renderer.render(renderer, buffer)
    end)

  time_ms = time_us / 1000
  fps = 1000 / time_ms
  status = if time_ms < 16.67, do: "✓", else: "✗"

  IO.puts("   #{width}x#{height}: #{Float.round(time_ms, 2)}ms (#{Float.round(fps, 1)}fps) #{status}")
end

# Benchmark 2: Subsequent renders (warm cache, no changes)
IO.puts("\n2. Cached Render (No Changes)")
IO.puts("   Target: < 1ms (should be instant)")

for {width, height} <- [{80, 24}, {120, 40}, {200, 50}] do
  buffer = BenchHelper.create_buffer(width, height)
  renderer = Renderer.new()
  {_html, renderer} = Renderer.render(renderer, buffer)

  {time_us, {_html, _renderer}} =
    :timer.tc(fn ->
      Renderer.render(renderer, buffer)
    end)

  time_ms = time_us / 1000
  status = if time_ms < 1.0, do: "✓", else: "✗"

  IO.puts("   #{width}x#{height}: #{Float.round(time_ms, 3)}ms #{status}")
end

# Benchmark 3: Re-render with changes
IO.puts("\n3. Re-render with Changes")
IO.puts("   Target: < 16.67ms (60fps)")

for {width, height, change_pct} <- [{80, 24, 10}, {80, 24, 50}, {120, 40, 10}] do
  buffer1 = BenchHelper.create_buffer(width, height)
  buffer2 = BenchHelper.modify_buffer(buffer1, change_pct)

  renderer = Renderer.new()
  {_html, renderer} = Renderer.render(renderer, buffer1)

  {time_us, {_html, _renderer}} =
    :timer.tc(fn ->
      Renderer.render(renderer, buffer2)
    end)

  time_ms = time_us / 1000
  fps = 1000 / time_ms
  status = if time_ms < 16.67, do: "✓", else: "✗"

  IO.puts("   #{width}x#{height} (#{change_pct}% changed): #{Float.round(time_ms, 2)}ms (#{Float.round(fps, 1)}fps) #{status}")
end

# Benchmark 4: Styled content rendering
IO.puts("\n4. Styled Content Rendering")
IO.puts("   Target: < 16.67ms (60fps)")

for {width, height} <- [{80, 24}, {120, 40}] do
  buffer = BenchHelper.create_buffer(width, height, styled: true, varied: true)

  {time_us, {_html, _renderer}} =
    :timer.tc(fn ->
      renderer = Renderer.new()
      Renderer.render(renderer, buffer)
    end)

  time_ms = time_us / 1000
  fps = 1000 / time_ms
  status = if time_ms < 16.67, do: "✓", else: "✗"

  IO.puts("   #{width}x#{height} (styled): #{Float.round(time_ms, 2)}ms (#{Float.round(fps, 1)}fps) #{status}")
end

# Benchmark 5: Cache hit ratio
IO.puts("\n5. Cache Performance")
IO.puts("   Target: > 90% hit ratio")

for {width, height, styled} <- [{80, 24, false}, {80, 24, true}] do
  buffer = BenchHelper.create_buffer(width, height, styled: styled)

  renderer = Renderer.new()
  {_html, renderer} = Renderer.render(renderer, buffer)

  stats = Renderer.stats(renderer)
  hit_ratio_pct = stats.hit_ratio * 100
  status = if hit_ratio_pct > 90, do: "✓", else: "✗"

  styled_label = if styled, do: " (styled)", else: ""
  IO.puts("   #{width}x#{height}#{styled_label}: #{Float.round(hit_ratio_pct, 1)}% hit ratio #{status}")
end

# Benchmark 6: Sustained rendering (simulate animation)
IO.puts("\n6. Sustained Rendering (100 frames)")
IO.puts("   Target: Avg < 16.67ms, P99 < 20ms")

for {width, height} <- [{80, 24}, {120, 40}] do
  renderer = Renderer.new()

  times =
    for i <- 1..100 do
      # Create slightly different buffer each time (simulates animation)
      buffer = BenchHelper.create_buffer(width, height)
      buffer = BenchHelper.modify_buffer(buffer, rem(i, 10))

      {time_us, {_html, updated_renderer}} =
        :timer.tc(fn ->
          Renderer.render(renderer, buffer)
        end)

      # Update renderer for next iteration
      renderer = updated_renderer

      time_us / 1000
    end

  avg_time = Enum.sum(times) / length(times)
  p99_time = Enum.sort(times) |> Enum.at(99)
  min_time = Enum.min(times)
  max_time = Enum.max(times)

  avg_status = if avg_time < 16.67, do: "✓", else: "✗"
  p99_status = if p99_time < 20.0, do: "✓", else: "✗"

  IO.puts("   #{width}x#{height}:")
  IO.puts("     Avg: #{Float.round(avg_time, 2)}ms #{avg_status}")
  IO.puts("     P99: #{Float.round(p99_time, 2)}ms #{p99_status}")
  IO.puts("     Min: #{Float.round(min_time, 2)}ms")
  IO.puts("     Max: #{Float.round(max_time, 2)}ms")
end

# Summary
IO.puts("\n=== Summary ===")
IO.puts("✓ = Passed")
IO.puts("✗ = Failed")
IO.puts("\nTarget: 60fps rendering (<16.67ms per frame)")
IO.puts("Cache target: >90% hit ratio for common content")
IO.puts("\nRun `mix profile.fprof bench/raxol_web_renderer_bench.exs` for detailed profiling.")
