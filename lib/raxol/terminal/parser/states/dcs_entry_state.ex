defmodule Raxol.Terminal.Parser.States.DCSEntryState do
  @moduledoc """
  Handles the :dcs_entry state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  require Raxol.Core.Runtime.Log

  @doc """
  Processes input when the parser is in the :dcs_entry state.
  Similar to CSI Entry - collects params/intermediates/final byte.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(emulator, %State{state: :dcs_entry} = parser_state, input) do
    case input do
      <<>> -> {:incomplete, emulator, parser_state}
      <<byte, rest::binary>> -> handle_byte(emulator, parser_state, byte, rest)
    end
  end

  defp handle_byte(emulator, parser_state, byte, rest) do
    byte_handlers = [
      {&param_byte?/1,
       fn -> handle_param_byte(emulator, parser_state, byte, rest) end},
      {fn b -> b == ?; end,
       fn -> handle_separator(emulator, parser_state, rest) end},
      {&intermediate_byte?/1,
       fn -> handle_intermediate_byte(emulator, parser_state, byte, rest) end},
      {&final_byte?/1,
       fn -> handle_final_byte(emulator, parser_state, byte, rest) end},
      {&can_sub?/1, fn -> handle_can_sub(emulator, parser_state, rest) end},
      {&ignored_byte?/1,
       fn -> handle_ignored_byte(emulator, parser_state, byte, rest) end}
    ]

    Enum.find_value(byte_handlers, fn {check, handler} ->
      case check.(byte) do
        true -> handler.()
        false -> nil
      end
    end) || handle_unhandled_byte(emulator, parser_state, byte, rest)
  end

  defp param_byte?(byte), do: byte >= ?0 and byte <= ?9
  defp intermediate_byte?(byte), do: byte >= 0x20 and byte <= 0x2F
  defp final_byte?(byte), do: byte >= 0x40 and byte <= 0x7E
  defp can_sub?(byte), do: byte == 0x18 or byte == 0x1A

  defp ignored_byte?(byte),
    do:
      (byte >= 0 and byte <= 23 and byte != 0x18 and byte != 0x1A) or
        (byte >= 27 and byte <= 31) or byte == 127

  defp handle_param_byte(emulator, parser_state, byte, rest) do
    next_state = %{
      parser_state
      | params_buffer: parser_state.params_buffer <> <<byte>>
    }

    {:continue, emulator, next_state, rest}
  end

  defp handle_separator(emulator, parser_state, rest) do
    next_state = %{
      parser_state
      | params_buffer: parser_state.params_buffer <> <<?;>>
    }

    {:continue, emulator, next_state, rest}
  end

  defp handle_intermediate_byte(emulator, parser_state, byte, rest) do
    next_state = %{
      parser_state
      | intermediates_buffer: parser_state.intermediates_buffer <> <<byte>>
    }

    {:continue, emulator, next_state, rest}
  end

  defp handle_final_byte(emulator, parser_state, byte, rest) do
    Raxol.Core.Runtime.Log.debug(
      "DCSEntryState: Found final byte #{byte}, transitioning to dcs_passthrough with rest=#{inspect(rest)}"
    )

    next_state = %{
      parser_state
      | state: :dcs_passthrough,
        final_byte: byte,
        payload_buffer: ""
    }

    {:continue, emulator, next_state, rest}
  end

  defp handle_can_sub(emulator, parser_state, rest) do
    Raxol.Core.Runtime.Log.debug("Ignoring CAN/SUB byte in DCS Entry")
    next_state = %{parser_state | state: :ground}
    {:continue, emulator, next_state, rest}
  end

  defp handle_ignored_byte(emulator, parser_state, byte, rest) do
    Raxol.Core.Runtime.Log.debug("Ignoring C0/DEL byte #{byte} in DCS Entry")
    {:continue, emulator, parser_state, rest}
  end

  defp handle_unhandled_byte(emulator, parser_state, byte, rest) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Unhandled byte #{byte} in DCS Entry state, returning to ground.",
      %{}
    )

    next_state = %{parser_state | state: :ground}
    {:continue, emulator, next_state, rest}
  end
end
