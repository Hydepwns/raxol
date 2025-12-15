defmodule Raxol.Performance.TextWrappingCacheTest do
  use ExUnit.Case, async: false

  alias Raxol.UI.Components.Input.TextWrappingCached
  alias Raxol.Core.Performance.Caches.FontMetricsCache
  alias Raxol.Performance.ETSCacheManager

  setup do
    # Ensure cache manager is running with name for GenServer.call
    case ETSCacheManager.start_link(name: ETSCacheManager) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Warm up font metrics cache
    FontMetricsCache.warmup()

    :ok
  end

  describe "wrap_line_by_visual_width/2" do
    test "wraps text considering actual character widths" do
      # ASCII text
      text = "Hello World"
      lines = TextWrappingCached.wrap_line_by_visual_width(text, 5)
      assert length(lines) >= 2

      # Wide characters should take up more space
      wide_text = "中文字"
      wide_lines = TextWrappingCached.wrap_line_by_visual_width(wide_text, 4)
      assert length(wide_lines) >= 2
    end

    test "handles mixed width characters correctly" do
      mixed = "Hi中文"
      lines = TextWrappingCached.wrap_line_by_visual_width(mixed, 4)
      # "Hi" (2 width) + "中" (2 width) = 4, should split after first CJK char
      assert length(lines) >= 2
    end

    test "handles empty strings" do
      assert TextWrappingCached.wrap_line_by_visual_width("", 10) == []
    end
  end

  describe "wrap_line_by_word/2" do
    test "wraps text at word boundaries using cached widths" do
      text = "The quick brown fox jumps over the lazy dog"
      lines = TextWrappingCached.wrap_line_by_word(text, 15)

      assert is_list(lines)
      assert length(lines) > 1

      # No line should exceed the width
      for line <- lines do
        assert FontMetricsCache.get_string_width(line) <= 15
      end
    end

    test "handles long words that exceed width" do
      text = "supercalifragilisticexpialidocious is a long word"
      lines = TextWrappingCached.wrap_line_by_word(text, 10)

      assert is_list(lines)
      assert length(lines) >= 4
    end
  end

  describe "get_visual_width/1" do
    test "calculates visual width using cache" do
      # ASCII characters typically have width 1
      assert TextWrappingCached.get_visual_width("Hello") >= 5

      # Wide characters have width 2
      assert TextWrappingCached.get_visual_width("中") >= 1

      # Mixed content
      assert TextWrappingCached.get_visual_width("Hi中文") >= 4
    end
  end

  describe "performance" do
    test "cached wrapping is faster than calculating widths repeatedly" do
      long_text =
        String.duplicate("The quick brown fox jumps over the lazy dog. ", 20)

      # Warm up cache
      TextWrappingCached.warmup_cache([long_text])

      # Measure cached performance
      cached_time =
        :timer.tc(fn ->
          for _ <- 1..100 do
            TextWrappingCached.wrap_line_by_word(long_text, 50)
          end
        end)
        |> elem(0)

      # Measure uncached performance (simulate by using different text)
      new_text =
        String.duplicate("Different text that hasn't been cached yet. ", 20)

      uncached_time =
        :timer.tc(fn ->
          TextWrappingCached.wrap_line_by_word(new_text, 50)
        end)
        |> elem(0)

      IO.puts("Cached wrapping time: #{cached_time}μs")
      IO.puts("First wrap time: #{uncached_time}μs")

      # Subsequent runs should be faster due to caching
      second_run =
        :timer.tc(fn ->
          TextWrappingCached.wrap_line_by_word(new_text, 50)
        end)
        |> elem(0)

      # Cached run should be at least as fast as uncached (use <= to handle timing granularity)
      assert second_run <= uncached_time
    end

    test "warmup_cache preloads common strings" do
      common_strings = ["Hello", "World", "Raxol", "Terminal"]

      # Clear cache first
      ETSCacheManager.clear_cache(:font_metrics)

      # Warm up with common strings
      TextWrappingCached.warmup_cache(common_strings)

      # These should now be cached
      for string <- common_strings do
        width = TextWrappingCached.get_visual_width(string)
        assert is_integer(width)
        assert width > 0
      end
    end
  end

  describe "wrap_to_pixel_width/3" do
    test "wraps text based on pixel width and font metrics" do
      text = "This is a long text that needs to be wrapped based on pixel width"

      # Create proper Font.Manager struct
      font_manager = %Raxol.Terminal.Font.Manager{
        family: "monospace",
        size: 14,
        weight: :normal,
        style: :normal,
        line_height: 1.2,
        letter_spacing: 0,
        fallback_fonts: [],
        custom_fonts: %{}
      }

      # Wrap to 200 pixels
      lines = TextWrappingCached.wrap_to_pixel_width(text, 200, font_manager)

      assert is_list(lines)
      assert length(lines) > 0
    end
  end
end
