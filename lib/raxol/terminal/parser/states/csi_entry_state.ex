defmodule Raxol.Terminal.Parser.States.CSIEntryState do
  @moduledoc """
  Handles the CSI Entry state in the terminal parser.
  This state is entered after receiving an ESC [ sequence.
  """

  alias Raxol.Terminal.Parser.States.{
    GroundState,
    CSIIntermediateState,
    CSIState
  }

  @doc """
  Handles input in CSI Entry state.
  Returns the next state and any accumulated data.
  """
  @spec handle(byte(), map()) :: {module(), map()}
  def handle(byte, data) do
    case byte do
      # Parameter bytes (0x30-0x3F)
      b when b in 0x30..0x3F ->
        {CSIState, Map.put(data, :params, [b])}

      # Intermediate bytes (0x20-0x2F)
      b when b in 0x20..0x2F ->
        {CSIIntermediateState, Map.put(data, :intermediates, [b])}

      # Final bytes (0x40-0x7E)
      b when b in 0x40..0x7E ->
        {GroundState, Map.put(data, :final, b)}

      # Invalid bytes
      b ->
        require Raxol.Core.Runtime.Log

        Raxol.Core.Runtime.Log.warning(
          "Invalid byte in CSI Entry state: #{inspect(b)}"
        )

        {GroundState, data}
    end
  end
end
