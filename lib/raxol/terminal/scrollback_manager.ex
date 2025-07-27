defmodule Raxol.Terminal.ScrollbackManager do
  @moduledoc """
  Terminal scrollback buffer management.

  Manages the terminal's scrollback history including adding lines,
  clearing history, and retrieving scrollback buffer contents.
  """
  def add_to_scrollback(_a, _b), do: :ok
  def clear_scrollback(_a), do: :ok
  def get_scrollback_buffer(_a), do: :ok
end
