defmodule Raxol.Terminal.Input.Types do
  @moduledoc """
  Defines shared types for the Raxol terminal input subsystem.
  """

  @typedoc "Represents the state of the terminal input buffer."
  @type input_buffer :: %{
    contents: String.t(),
    max_size: non_neg_integer(),
    overflow_mode: :truncate | :error | :wrap,
    escape_sequence: String.t(),
    escape_sequence_mode: boolean(),
    cursor_pos: non_neg_integer(),
    width: non_neg_integer()
  }

  # Add other shared input-related types here if needed in the future.
end
