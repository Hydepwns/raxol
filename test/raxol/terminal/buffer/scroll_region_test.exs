defmodule Raxol.Terminal.Buffer.ScrollRegionTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.ScrollRegion

  setup do
    buffer = ScreenBuffer.new(10, 5)
    %{buffer: buffer}
  end

  describe "set_region/3" do
    test "sets valid scroll region", %{buffer: buffer} do
      buffer = ScrollRegion.set_region(buffer, 1, 3)
      assert ScrollRegion.get_region(buffer) == {1, 3}
    end

    test "ignores invalid scroll region", %{buffer: buffer} do
      # top > bottom
      buffer = ScrollRegion.set_region(buffer, 3, 1)
      assert ScrollRegion.get_region(buffer) == nil

      # negative top
      buffer = ScrollRegion.set_region(buffer, -1, 3)
      assert ScrollRegion.get_region(buffer) == nil

      # bottom >= height
      buffer = ScrollRegion.set_region(buffer, 1, 5)
      assert ScrollRegion.get_region(buffer) == nil
    end
  end

  describe "clear_region/1" do
    test "clears scroll region", %{buffer: buffer} do
      buffer = ScrollRegion.set_region(buffer, 1, 3)
      buffer = ScrollRegion.clear_region(buffer)
      assert ScrollRegion.get_region(buffer) == nil
    end
  end

  describe "scroll_up/2" do
    test "scrolls content up within region", %{buffer: buffer} do
      # Set up content
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = ScrollRegion.set_region(buffer, 1, 3)

      # Scroll up by 1
      buffer = ScrollRegion.scroll_up(buffer, 1)
      assert get_content(buffer) == "ABCDE\nKLMNO\nPQRST\n          \nUVWXY"
    end

    test "scrolls entire screen when no region set", %{buffer: buffer} do
      # Set up content
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")

      # Scroll up by 1
      buffer = ScrollRegion.scroll_up(buffer, 1)
      assert get_content(buffer) == "FGHIJ\nKLMNO\nPQRST\nUVWXY\n          "
    end

    test "ignores invalid scroll amount", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = ScrollRegion.scroll_up(original, 0)
      assert buffer == original
    end
  end

  describe "scroll_down/2" do
    test "scrolls content down within region", %{buffer: buffer} do
      # Set up content
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = ScrollRegion.set_region(buffer, 1, 3)

      # Scroll down by 1
      buffer = ScrollRegion.scroll_down(buffer, 1)
      assert get_content(buffer) == "ABCDE\n          \nFGHIJ\nKLMNO\nUVWXY"
    end

    test "scrolls entire screen when no region set", %{buffer: buffer} do
      # Set up content
      buffer = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")

      # Scroll down by 1
      buffer = ScrollRegion.scroll_down(buffer, 1)
      assert get_content(buffer) == "          \nABCDE\nFGHIJ\nKLMNO\nPQRST"
    end

    test "ignores invalid scroll amount", %{buffer: buffer} do
      original = put_content(buffer, "ABCDE\nFGHIJ\nKLMNO\nPQRST\nUVWXY")
      buffer = ScrollRegion.scroll_down(original, 0)
      assert buffer == original
    end
  end

  # Helper functions

  defp put_content(buffer, text) do
    text
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, y}, buffer ->
      line
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.reduce(buffer, fn {char, x}, buffer ->
        Raxol.Terminal.Buffer.Content.write_char(buffer, x, y, char)
      end)
    end)
  end

  defp get_content(buffer) do
    buffer.cells
    |> Enum.map(fn row ->
      original_line = row |> Enum.map_join("", & &1.char)
      trimmed_line = String.trim_trailing(original_line)

      # If the original line was all spaces, preserve it as spaces
      if String.trim(original_line) == "" and original_line != "" do
        String.duplicate(" ", String.length(original_line))
      else
        trimmed_line
      end
    end)
    |> Enum.join("\n")
  end
end
