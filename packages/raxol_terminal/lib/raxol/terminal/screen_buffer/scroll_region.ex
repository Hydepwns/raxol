defmodule Raxol.Terminal.ScreenBuffer.ScrollRegion do
  @moduledoc """
  Manages scroll region boundaries for the screen buffer.
  """

  def get_boundaries(_scroll_state), do: {0, 0}
end
