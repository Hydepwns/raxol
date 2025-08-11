defmodule Raxol.Terminal.ParserState do
  @moduledoc """
  Terminal parser state management.

  Manages parser state for processing terminal escape sequences
  and character input.
  """

  @type t :: term()

  def new, do: :ok
  def process_char(_a, _b), do: :ok
end
