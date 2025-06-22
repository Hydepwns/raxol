defmodule Raxol.Test.WindowTestHelper do
  @moduledoc """
  Helper functions for window-related tests.
  """
  import Raxol.Guards

  @doc """
  Creates a test emulator with default window state.
  """
  def create_test_emulator do
    emu = Raxol.Terminal.Emulator.new(80, 24)

    if map?(emu),
      do:
        emu
        |> Map.put_new(:style, %{})
        |> Map.put_new(:disabled, false)
        |> Map.put_new(:focused, false)
        |> Map.put_new(:attrs, %{}),
      else: emu
  end

  @doc """
  Returns a list of basic window operations for testing.
  """
  def basic_window_operations do
    [
      {[1], "deiconify"},
      {[2], "iconify"},
      {[3, 10, 20], "move"},
      {[4, 100, 50], "resize"},
      {[5], "raise"},
      {[6], "lower"},
      {[7], "refresh"},
      {[9], "maximize"},
      {[10], "restore"}
    ]
  end

  @doc """
  Returns a list of window reporting operations for testing.
  """
  def reporting_operations do
    [
      {[11], "state report"},
      {[13], "size report"},
      {[14], "position report"},
      {[18], "screen size report"},
      {[19], "screen size pixels report"}
    ]
  end

  @doc """
  Returns a list of invalid parameters for testing.
  """
  def invalid_parameters do
    [
      {[], "empty parameters"},
      {[nil], "nil operation"},
      {["invalid"], "non-integer operation"},
      {[-1], "negative operation"},
      {[3, -10, -20], "negative position"},
      {[4, -100, -50], "negative size"},
      {[3, "invalid", "invalid"], "non-integer position"},
      {[4, "invalid", "invalid"], "non-integer size"}
    ]
  end

  @doc """
  Returns a list of test window sizes for resize operations.
  """
  def test_window_sizes do
    [
      {100, 50},
      {200, 100},
      {500, 250},
      {1000, 500}
    ]
  end
end
