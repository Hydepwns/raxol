defmodule Raxol.Terminal.Parser.State do
  @moduledoc """
  Parser state for the terminal emulator.
  """

  defstruct [
    :state,
    :params_buffer,
    :intermediates_buffer,
    :payload_buffer,
    :final_byte,
    :designating_gset,
    :single_shift
    # Add other fields as needed by your parser
  ]
end
