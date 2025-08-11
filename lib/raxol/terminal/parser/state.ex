defmodule Raxol.Terminal.Parser.State do
  @moduledoc """
  Parser state for the terminal emulator.
  """

  @type t :: %__MODULE__{
          state: atom(),
          params: list(),
          params_buffer: binary(),
          intermediates_buffer: binary(),
          payload_buffer: binary(),
          final_byte: byte() | nil,
          designating_gset: term() | nil,
          single_shift: term() | nil
        }

  defstruct state: :ground,
            params: [],
            params_buffer: "",
            intermediates_buffer: "",
            payload_buffer: "",
            final_byte: nil,
            designating_gset: nil,
            single_shift: nil
end
