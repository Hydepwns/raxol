defmodule Raxol.Terminal.Parser.States.CSIParamState do
  @moduledoc """
  Handles the :csi_param state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  alias Raxol.Terminal.Commands.Executor
  require Raxol.Core.Runtime.Log
  require Logger

  @doc """
  Processes input when the parser is in the :csi_param state.
  Collects parameter digits (0-9) and semicolons (;).
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(emulator, %State{state: :csi_param} = parser_state, input) do
    Logger.debug(
      "CSIParamState.handle: input=#{inspect(input)}, params_buffer=#{inspect(parser_state.params_buffer)}"
    )

    dispatch_input(input, emulator, parser_state)
  end

  defp dispatch_input(<<>>, emulator, parser_state),
    do: handle_empty_input(emulator, parser_state)

  defp dispatch_input(<<digit, rest::binary>>, emulator, parser_state)
       when digit >= ?0 and digit <= ?9,
       do: handle_digit(emulator, parser_state, digit, rest)

  defp dispatch_input(<<?;, rest::binary>>, emulator, parser_state),
    do: handle_separator(emulator, parser_state, rest)

  defp dispatch_input(
         <<intermediate_byte, rest::binary>>,
         emulator,
         parser_state
       )
       when intermediate_byte?(intermediate_byte),
       do: handle_intermediate(emulator, parser_state, intermediate_byte, rest)

  defp dispatch_input(<<final_byte, rest::binary>>, emulator, parser_state)
       when final_byte >= ?@ and final_byte <= ?~,
       do: handle_final_byte(emulator, parser_state, final_byte, rest)

  defp dispatch_input(<<ignored_byte, rest::binary>>, emulator, parser_state)
       when can_sub_byte?(ignored_byte),
       do: handle_can_sub(emulator, parser_state, rest)

  defp dispatch_input(<<ignored_byte, rest::binary>>, emulator, parser_state)
       when ignored_byte?(ignored_byte),
       do: handle_ignored_byte(emulator, parser_state, ignored_byte, rest)

  defp dispatch_input(<<unhandled_byte, rest::binary>>, emulator, parser_state),
    do: handle_unhandled_byte(emulator, parser_state, unhandled_byte, rest)

  # Private helper functions
  defp handle_empty_input(emulator, parser_state),
    do: {:incomplete, emulator, parser_state}

  defp handle_digit(emulator, parser_state, digit, rest) do
    next_parser_state = %{
      parser_state
      | params_buffer: parser_state.params_buffer <> <<digit>>
    }

    {:continue, emulator, next_parser_state, rest}
  end

  defp handle_separator(emulator, parser_state, rest) do
    next_parser_state = %{
      parser_state
      | params_buffer: parser_state.params_buffer <> <<?;>>
    }

    {:continue, emulator, next_parser_state, rest}
  end

  defp handle_intermediate(emulator, parser_state, intermediate_byte, rest) do
    next_parser_state = %{
      parser_state
      | intermediates_buffer:
          parser_state.intermediates_buffer <> <<intermediate_byte>>,
        state: :csi_intermediate
    }

    {:continue, emulator, next_parser_state, rest}
  end

  defp handle_final_byte(emulator, parser_state, final_byte, rest) do
    final_emulator =
      Executor.execute_csi_command(
        emulator,
        parser_state.params_buffer,
        parser_state.intermediates_buffer,
        final_byte
      )

    next_parser_state = %{
      parser_state
      | state: :ground,
        params_buffer: "",
        intermediates_buffer: "",
        final_byte: nil
    }

    {:continue, final_emulator, next_parser_state, rest}
  end

  defp handle_can_sub(emulator, parser_state, rest) do
    Raxol.Core.Runtime.Log.debug("Ignoring CAN/SUB byte in CSI Param")
    next_parser_state = %{parser_state | state: :ground}
    {:continue, emulator, next_parser_state, rest}
  end

  defp handle_ignored_byte(emulator, parser_state, ignored_byte, rest) do
    Raxol.Core.Runtime.Log.debug(
      "Ignoring C0/DEL byte #{ignored_byte} in CSI Param"
    )

    {:continue, emulator, parser_state, rest}
  end

  defp handle_unhandled_byte(emulator, parser_state, unhandled_byte, rest) do
    msg =
      "Unhandled byte #{unhandled_byte} in CSI Param state, returning to ground."

    Raxol.Core.Runtime.Log.warning_with_context(msg, %{})
    next_parser_state = %{parser_state | state: :ground}
    {:continue, emulator, next_parser_state, rest}
  end

  # Guard functions
  defp intermediate_byte?(byte),
    do: (byte >= 0x20 and byte <= 0x2F) or byte == ??

  defp can_sub_byte?(byte), do: byte == 0x18 or byte == 0x1A

  defp ignored_byte?(byte) do
    (byte >= 0 and byte <= 23 and byte != 0x18 and byte != 0x1A) or
      (byte >= 27 and byte <= 31) or byte == 127
  end
end
