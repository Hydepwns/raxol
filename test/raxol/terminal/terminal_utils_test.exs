defmodule Raxol.Terminal.TerminalUtilsTest do
  use ExUnit.Case, async: true

  alias Raxol.Terminal.TerminalUtils
  import ExUnit.CaptureLog

  describe "get_terminal_dimensions/0" do
    test "returns valid dimensions" do
      {width, height} = TerminalUtils.get_terminal_dimensions()

      # Basic structural assertions
      assert is_integer(width)
      assert is_integer(height)

      # Basic range validations
      assert width > 0
      assert height > 0

      # Check reasonable terminal size bounds
      assert width >= 20, "Terminal width should be at least 20 columns"
      assert height >= 10, "Terminal height should be at least 10 rows"
    end
  end

  describe "get_dimensions_map/0" do
    test "returns map with width and height" do
      dimensions = TerminalUtils.get_dimensions_map()

      assert is_map(dimensions)
      assert Map.has_key?(dimensions, :width)
      assert Map.has_key?(dimensions, :height)
      assert is_integer(dimensions.width)
      assert is_integer(dimensions.height)
    end
  end

  describe "get_bounds_map/0" do
    test "returns map with x, y, width, and height" do
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
    end
  end

  # Test the fallback mechanism when dimensions can't be determined
  describe "dimension fallback" do
    test "uses default dimensions when all methods fail" do
      # Mock the private functions to always return errors
      # Note: This is somewhat of a hacky way to test private functions, but it's
      # useful here to validate the fallback mechanism. In most cases, avoid
      # testing private functions directly.
      with_mock_functions = fn test_function ->
        original_try_io = :erlang.make_fun(TerminalUtils, :try_io_dimensions, 0)
        original_try_termbox = :erlang.make_fun(TerminalUtils, :try_termbox_dimensions, 0)
        original_try_system = :erlang.make_fun(TerminalUtils, :try_system_command, 0)

        try do
          # Patch the module to always return errors from the helper functions
          :meck.new(TerminalUtils, [:passthrough])
          :meck.expect(TerminalUtils, :try_io_dimensions, fn -> {:error, :test_mock} end)
          :meck.expect(TerminalUtils, :try_termbox_dimensions, fn -> {:error, :test_mock} end)
          :meck.expect(TerminalUtils, :try_system_command, fn -> {:error, :test_mock} end)

          # Run the test function
          test_function.()
        after
          # Clean up the mocks
          :meck.unload(TerminalUtils)
        end
      end

      # Test if fallback to default dimensions happens correctly
      log = capture_log(fn ->
        with_mock_functions.(fn ->
          {width, height} = TerminalUtils.get_terminal_dimensions()
          assert width == 80
          assert height == 24
        end)
      end)

      # We're not testing the exact log content here to keep the test simpler
      # and less brittle, but you could add assertions on the log output if needed
    end
  end
end
