defmodule Raxol.Terminal.Buffer.Content do
  @moduledoc """
  Compatibility adapter for buffer content operations.
  Forwards calls to Raxol.Terminal.ScreenBuffer.Operations.
  """

  alias Raxol.Terminal.ScreenBuffer.Operations

  @doc """
  Writes content at a specific position in the buffer.
  """
  @spec write_at(
          term(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          map()
        ) :: term()
  def write_at(buffer, x, y, text, style \\ %{}) do
    Operations.write_text(buffer, x, y, text, style)
  end
end
