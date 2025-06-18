defmodule Raxol.Terminal.Parser.State do
  @moduledoc """
  Parser state for the terminal emulator.
  """

  defstruct state: :ground,
            params: [],
            params_buffer: "",
            intermediates_buffer: "",
            payload_buffer: "",
            final_byte: nil,
            designating_gset: nil,
            single_shift: nil

  # Add other fields as needed by your parser
end
