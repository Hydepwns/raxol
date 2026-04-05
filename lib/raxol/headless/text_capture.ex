defmodule Raxol.Headless.TextCapture do
  @moduledoc """
  Converts a `Raxol.Terminal.ScreenBuffer` into a plain text string.

  Used by `Raxol.Headless` to produce text screenshots of headless sessions.
  """

  alias Raxol.Terminal.Buffer.Queries
  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Captures the screen buffer content as a trimmed text string.

  Each row is joined with newlines, trailing whitespace per line is trimmed,
  and trailing empty lines are removed.
  """
  @spec capture(ScreenBuffer.t() | nil) :: String.t()
  def capture(%ScreenBuffer{} = buffer) do
    Queries.get_text(buffer)
    |> String.split("\n")
    |> Enum.map_join("\n", &String.trim_trailing/1)
    |> String.trim_trailing("\n")
  end

  def capture(nil), do: ""
end
