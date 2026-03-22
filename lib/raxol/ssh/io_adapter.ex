defmodule Raxol.SSH.IOAdapter do
  @moduledoc """
  I/O adapter for SSH sessions.

  Replaces `Terminal.Driver` for SSH context:
  - Reads from SSH channel data, parses via InputParser
  - Writes ANSI output to SSH channel instead of stdout
  """

  alias Raxol.Terminal.ANSI.InputParser

  @doc """
  Creates a writer function that sends output to an SSH channel.

  Returns a function `(binary -> :ok)` suitable for the `:io_writer`
  option in Lifecycle/Rendering.Engine.
  """
  @spec make_writer(reference(), non_neg_integer()) :: (binary() -> :ok)
  def make_writer(connection_ref, channel_id) do
    fn data when is_binary(data) ->
      :ssh_connection.send(connection_ref, channel_id, data)
      :ok
    end
  end

  @doc """
  Parses raw SSH channel input data into Raxol Event structs.

  Delegates to `Raxol.Terminal.ANSI.InputParser` which handles
  ANSI escape sequences, UTF-8 characters, and control codes.
  """
  @spec parse_input(binary()) :: [Raxol.Core.Events.Event.t()]
  def parse_input(data) when is_binary(data) do
    InputParser.parse(data)
  end
end
