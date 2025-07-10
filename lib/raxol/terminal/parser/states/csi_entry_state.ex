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
  @spec handle(byte(), map()) :: {atom(), map()}
  def handle(byte, data) do
    case byte do
      # Parameter bytes (0x30-0x3E)
      b when b in 0x30..0x3E ->
        {:csi_param, Map.update(data, :params_buffer, <<b>>, &(&1 <> <<b>>))}

      # Intermediate bytes (0x20-0x2F) and '?' (0x3F)
      b when b in 0x20..0x2F or b == 0x3F ->
        {:csi_intermediate,
         Map.update(data, :intermediates_buffer, <<b>>, &(&1 <> <<b>>))}

      # Final bytes (0x40-0x7E)
      b when b in 0x40..0x7E ->
        {:ground, Map.put(data, :final_byte, b)}

      # Invalid bytes
      b ->
        require Raxol.Core.Runtime.Log

        Raxol.Core.Runtime.Log.warning(
          "Invalid byte in CSI Entry state: #{inspect(b)}"
        )

        {:ground, data}
    end
  end

  @doc """
  Handles input in CSI Entry state with emulator context.
  Returns {:continue, emulator, parser_state, input} or {:incomplete, emulator, parser_state}.
  """
  @spec handle(
          Raxol.Terminal.Emulator.t(),
          Raxol.Terminal.Parser.State.t(),
          binary()
        ) ::
          {:continue, Raxol.Terminal.Emulator.t(),
           Raxol.Terminal.Parser.State.t(), binary()}
          | {:incomplete, Raxol.Terminal.Emulator.t(),
             Raxol.Terminal.Parser.State.t()}
  def handle(emulator, parser_state, input) do
    case input do
      # Process each byte in the input
      <<byte, rest::binary>> ->
        # Convert parser_state to map for handle/2
        state_map = %{
          params_buffer: parser_state.params_buffer,
          intermediates_buffer: parser_state.intermediates_buffer,
          final_byte: parser_state.final_byte
        }

        {next_state_module, updated_data} = handle(byte, state_map)

        # Update parser state with the new state and data
        next_parser_state = %{
          parser_state
          | state: next_state_module,
            params_buffer: Map.get(updated_data, :params_buffer, ""),
            intermediates_buffer:
              Map.get(updated_data, :intermediates_buffer, ""),
            final_byte: Map.get(updated_data, :final_byte)
        }

        case next_state_module do
          :ground ->
            # Transition back to ground state
            {:continue, emulator, next_parser_state, rest}

          _ ->
            # Continue with the next state
            {:continue, emulator, next_parser_state, rest}
        end

      # Empty input - incomplete sequence
      <<>> ->
        {:incomplete, emulator, parser_state}
    end
  end
end
