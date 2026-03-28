defmodule Raxol.Test.Terminal.SixelTestHelper do
  @moduledoc false

  # Returns a sample sixel data string for testing
  def sixel_data do
    # This should match the expected format used in your tests
    # Example: a simple sixel string for a 1x1 black pixel
    "#0;2;0;0;0#0?"
  end

  # Optionally, define expected_char_grid/0 if needed by your tests
  # def expected_char_grid do
  #   [[{0, 0, 0}]] # Example: 1x1 grid with black color
  # end
end
