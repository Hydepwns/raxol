defmodule Raxol.Terminal.Scroll.ScrollBufferTest do
  use ExUnit.Case
  alias Raxol.Terminal.Buffer.Scroll
  alias Raxol.Terminal.Cell

  describe "new/2" do
    test ~c"creates a new scroll buffer with default values" do
      scroll = Scroll.new(1000)
      assert scroll.max_height == 1000
      assert scroll.position == 0
      assert scroll.height == 0
      assert scroll.buffer == []
      assert scroll.scroll_region == nil
      assert scroll.memory_limit == 5_000_000
      assert scroll.memory_usage == 0
      assert scroll.cache == %{}
    end

    test ~c"creates a new scroll buffer with custom memory limit" do
      scroll = Scroll.new(1000, 10_000_000)
      assert scroll.memory_limit == 10_000_000
    end
  end

  describe "add_line/2" do
    test ~c"adds a line to the buffer" do
      scroll = Scroll.new(1000)
      line = [Cell.new("A"), Cell.new("B")]
      scroll = Scroll.add_line(scroll, line)
      assert scroll.height == 1
      assert hd(scroll.buffer) == line
    end

    test ~c"trims buffer when it exceeds max height" do
      scroll = Scroll.new(2)
      line1 = [Cell.new("A")]
      line2 = [Cell.new("B")]
      line3 = [Cell.new("C")]

      scroll = Scroll.add_line(scroll, line1)
      scroll = Scroll.add_line(scroll, line2)
      scroll = Scroll.add_line(scroll, line3)

      assert scroll.height == 2
      assert scroll.buffer == [line3, line2]
    end
  end

  describe "get_view/2" do
    test ~c"returns a view of the buffer at current position" do
      scroll = Scroll.new(1000)
      line1 = [Cell.new("A")]
      line2 = [Cell.new("B")]
      line3 = [Cell.new("C")]

      scroll = Scroll.add_line(scroll, line1)
      scroll = Scroll.add_line(scroll, line2)
      scroll = Scroll.add_line(scroll, line3)

      {view, _scroll} = Scroll.get_view(scroll, 2)
      assert length(view) == 2
      assert hd(view) == line3
      assert hd(tl(view)) == line2
    end

    test ~c"caches view results" do
      scroll = Scroll.new(1000)
      line = [Cell.new("A")]
      scroll = Scroll.add_line(scroll, line)

      {view1, scroll} = Scroll.get_view(scroll, 1)
      {view2, _scroll} = Scroll.get_view(scroll, 1)

      assert view1 == view2
      assert scroll.cache != %{}
    end
  end

  describe "scroll/2" do
    test ~c"scrolls the buffer by the given amount" do
      scroll = Scroll.new(1000)
      line1 = [Cell.new("A")]
      line2 = [Cell.new("B")]
      line3 = [Cell.new("C")]

      scroll = Scroll.add_line(scroll, line1)
      scroll = Scroll.add_line(scroll, line2)
      scroll = Scroll.add_line(scroll, line3)

      scroll = Scroll.scroll(scroll, 1)
      assert scroll.position == 1
    end

    test ~c"does not scroll beyond buffer bounds" do
      scroll = Scroll.new(1000)
      line = [Cell.new("A")]
      scroll = Scroll.add_line(scroll, line)

      scroll = Scroll.scroll(scroll, 10)
      assert scroll.position == 1
    end
  end

  describe "scroll/3" do
    test ~c"scrolls up" do
      scroll = Scroll.new(1000)
      line1 = [Cell.new("A")]
      line2 = [Cell.new("B")]

      scroll = Scroll.add_line(scroll, line1)
      scroll = Scroll.add_line(scroll, line2)
      scroll = Scroll.scroll(scroll, 1)

      scroll = Scroll.scroll(scroll, :up, 1)
      assert scroll.position == 0
    end

    test ~c"scrolls down" do
      scroll = Scroll.new(1000)
      line1 = [Cell.new("A")]
      line2 = [Cell.new("B")]

      scroll = Scroll.add_line(scroll, line1)
      scroll = Scroll.add_line(scroll, line2)

      scroll = Scroll.scroll(scroll, :down, 1)
      assert scroll.position == 1
    end
  end

  describe "set_scroll_region/3" do
    test ~c"sets valid scroll region" do
      scroll = Scroll.new(1000)
      scroll = Scroll.set_scroll_region(scroll, 1, 5)
      assert scroll.scroll_region == {1, 5}
    end

    test ~c"ignores invalid scroll region" do
      scroll = Scroll.new(1000)
      scroll = Scroll.set_scroll_region(scroll, 5, 1)
      assert scroll.scroll_region == nil
    end
  end

  describe "clear_scroll_region/1" do
    test ~c"clears scroll region" do
      scroll = Scroll.new(1000)
      scroll = Scroll.set_scroll_region(scroll, 1, 5)
      scroll = Scroll.clear_scroll_region(scroll)
      assert scroll.scroll_region == nil
    end
  end

  describe "get_visible_region/1" do
    test ~c"returns full range when no scroll region" do
      scroll = Scroll.new(1000)
      line = [Cell.new("A")]
      scroll = Scroll.add_line(scroll, line)

      assert Scroll.get_visible_region(scroll) == {0, 0}
    end

    test ~c"returns scroll region when set" do
      scroll = Scroll.new(1000)
      scroll = Scroll.set_scroll_region(scroll, 1, 5)
      assert Scroll.get_visible_region(scroll) == {1, 5}
    end
  end

  describe "clear/1" do
    test ~c"clears the buffer" do
      scroll = Scroll.new(1000)
      line = [Cell.new("A")]
      scroll = Scroll.add_line(scroll, line)

      scroll = Scroll.clear(scroll)
      assert scroll.buffer == []
      assert scroll.height == 0
      assert scroll.position == 0
      assert scroll.memory_usage == 0
      assert scroll.cache == %{}
    end
  end

  describe "set_max_height/2" do
    test ~c"updates max height and trims buffer if needed" do
      scroll = Scroll.new(3)
      line1 = [Cell.new("A")]
      line2 = [Cell.new("B")]
      line3 = [Cell.new("C")]

      scroll = Scroll.add_line(scroll, line1)
      scroll = Scroll.add_line(scroll, line2)
      scroll = Scroll.add_line(scroll, line3)

      scroll = Scroll.set_max_height(scroll, 2)
      assert scroll.max_height == 2
      assert scroll.height == 2
      assert scroll.buffer == [line3, line2]
    end
  end

  describe "resize/2" do
    test ~c"updates height" do
      scroll = Scroll.new(1000)
      scroll = Scroll.resize(scroll, 50)
      assert scroll.height == 50
      assert scroll.cache == %{}
    end
  end
end
