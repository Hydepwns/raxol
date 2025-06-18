defmodule Raxol.Terminal.TerminalUtilsTest do
  # Run tests serially now
  use ExUnit.Case, async: false

  alias Raxol.Terminal.TerminalUtils

  # Define a mock IO facade
  defmodule MockIO do
    def columns, do: {:ok, 120}
    def rows, do: {:ok, 40}
  end

  defmodule ErrorIO do
    def columns, do: {:error, :enoent}
    def rows, do: {:error, :enoent}
  end

  describe "get_dimensions_map/0" do
    # This test might be flaky as it relies on the real detect_dimensions
    # which uses multiple fallbacks (IO, termbox, stty).
    # It's better to test the internal components like detect_with_io.
    @tag :flaky
    test 'returns map with width and height (using real detection)' do
      dimensions = TerminalUtils.get_dimensions_map()

      assert is_map(dimensions)
      assert Map.has_key?(dimensions, :width)
      assert Map.has_key?(dimensions, :height)
      assert is_integer(dimensions.width)
      assert is_integer(dimensions.height)
      assert dimensions.width > 0
      assert dimensions.height > 0
    end
  end

  describe "get_bounds_map/0" do
    # Similar to above, this relies on real detection.
    @tag :flaky
    test 'returns map with x, y, width, and height (using real detection)' do
      bounds = TerminalUtils.get_bounds_map()

      assert is_map(bounds)
      assert Map.has_key?(bounds, :x)
      assert Map.has_key?(bounds, :y)
      assert Map.has_key?(bounds, :width)
      assert Map.has_key?(bounds, :height)

      assert bounds.x == 0
      assert bounds.y == 0
      assert is_integer(bounds.width)
      assert is_integer(bounds.height)
      assert bounds.width > 0
      assert bounds.height > 0
    end
  end
end
