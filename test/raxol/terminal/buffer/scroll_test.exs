defmodule Raxol.Terminal.Buffer.ScrollTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Buffer.Scroll
  alias Raxol.Terminal.Cell

  describe "new/2" do
    test "creates a new scroll buffer with default values" do
      scroll = Scroll.new(1000)
      assert scroll.buffer == []
      assert scroll.position == 0
      assert scroll.height == 0
      assert scroll.max_height == 1000
      assert scroll.compression_ratio == 1.0
      assert scroll.memory_limit == 5_000_000
      assert scroll.memory_usage == 0
    end

    test "creates a new scroll buffer with custom memory limit" do
      scroll = Scroll.new(1000, 1_000_000)
      assert scroll.memory_limit == 1_000_000
    end
  end

  describe "add_line/2" do
    test "adds a line to the scroll buffer" do
      scroll = Scroll.new(1000)
      line = [Cell.new("A"), Cell.new("B")]
      scroll = Scroll.add_line(scroll, line)
      
      assert scroll.height == 1
      assert length(scroll.buffer) == 1
      assert hd(scroll.buffer) == line
    end

    test "trims buffer when it exceeds max height" do
      scroll = Scroll.new(2)  # Small max height for testing
      
      # Add three lines
      scroll = Scroll.add_line(scroll, [Cell.new("A")])
      scroll = Scroll.add_line(scroll, [Cell.new("B")])
      scroll = Scroll.add_line(scroll, [Cell.new("C")])
      
      assert scroll.height == 2
      assert length(scroll.buffer) == 2
      assert hd(scroll.buffer) == [Cell.new("C")]
      assert hd(tl(scroll.buffer)) == [Cell.new("B")]
    end

    test "compresses buffer when memory usage exceeds limit" do
      scroll = Scroll.new(1000, 100)  # Very low memory limit
      
      # Add a line with many cells to exceed memory limit
      line = Enum.map(1..100, fn _ -> Cell.new("A", %{foreground: :white, background: :black}) end)
      scroll = Scroll.add_line(scroll, line)
      
      assert scroll.compression_ratio < 1.0
      assert scroll.memory_usage <= scroll.memory_limit
    end
  end

  describe "get_view/2" do
    test "gets a view of the scroll buffer at the current position" do
      scroll = Scroll.new(1000)
      
      # Add three lines
      scroll = Scroll.add_line(scroll, [Cell.new("A")])
      scroll = Scroll.add_line(scroll, [Cell.new("B")])
      scroll = Scroll.add_line(scroll, [Cell.new("C")])
      
      # Get a view of height 2
      view = Scroll.get_view(scroll, 2)
      
      assert length(view) == 2
      assert hd(view) == [Cell.new("C")]
      assert hd(tl(view)) == [Cell.new("B")]
    end

    test "returns empty list when position is beyond buffer height" do
      scroll = Scroll.new(1000)
      scroll = Scroll.add_line(scroll, [Cell.new("A")])
      scroll = Scroll.scroll(scroll, 10)  # Scroll beyond buffer height
      
      view = Scroll.get_view(scroll, 2)
      assert view == []
    end

    test "returns partial view when near the end of the buffer" do
      scroll = Scroll.new(1000)
      
      # Add three lines
      scroll = Scroll.add_line(scroll, [Cell.new("A")])
      scroll = Scroll.add_line(scroll, [Cell.new("B")])
      scroll = Scroll.add_line(scroll, [Cell.new("C")])
      
      # Get a view of height 5 (larger than buffer)
      view = Scroll.get_view(scroll, 5)
      
      assert length(view) == 3
      assert hd(view) == [Cell.new("C")]
      assert hd(tl(view)) == [Cell.new("B")]
      assert hd(tl(tl(view))) == [Cell.new("A")]
    end
  end

  describe "scroll/2" do
    test "scrolls the buffer by the given amount" do
      scroll = Scroll.new(1000)
      scroll = Scroll.scroll(scroll, 5)
      assert scroll.position == 5
    end

    test "does not scroll beyond buffer bounds" do
      scroll = Scroll.new(1000)
      scroll = Scroll.add_line(scroll, [Cell.new("A")])
      scroll = Scroll.scroll(scroll, 10)
      assert scroll.position == 0  # Cannot scroll beyond buffer height
    end

    test "handles negative scroll amounts" do
      scroll = Scroll.new(1000)
      scroll = Scroll.scroll(scroll, 5)
      scroll = Scroll.scroll(scroll, -3)
      assert scroll.position == 2
    end
  end

  describe "get_position/1" do
    test "gets the current scroll position" do
      scroll = Scroll.new(1000)
      scroll = Scroll.scroll(scroll, 5)
      assert Scroll.get_position(scroll) == 5
    end
  end

  describe "get_height/1" do
    test "gets the total height of the scroll buffer" do
      scroll = Scroll.new(1000)
      scroll = Scroll.add_line(scroll, [Cell.new("A")])
      scroll = Scroll.add_line(scroll, [Cell.new("B")])
      assert Scroll.get_height(scroll) == 2
    end
  end

  describe "clear/1" do
    test "clears the scroll buffer" do
      scroll = Scroll.new(1000)
      scroll = Scroll.add_line(scroll, [Cell.new("A")])
      scroll = Scroll.add_line(scroll, [Cell.new("B")])
      scroll = Scroll.scroll(scroll, 1)
      
      scroll = Scroll.clear(scroll)
      
      assert scroll.buffer == []
      assert scroll.position == 0
      assert scroll.height == 0
      assert scroll.memory_usage == 0
    end
  end
end 