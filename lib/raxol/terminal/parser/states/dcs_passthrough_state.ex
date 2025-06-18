defmodule Raxol.Terminal.Parser.States.DCSPassthroughState do
  @moduledoc '''
  Handles the :dcs_passthrough state of the terminal parser.
  '''

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  require Raxol.Core.Runtime.Log

  @behaviour Raxol.Terminal.Parser.StateBehaviour

  @impl Raxol.Terminal.Parser.StateBehaviour
  @doc '''
  Processes input when the parser is in the :dcs_passthrough state.
  Collects the DCS data string until ST (ESC \).
  '''
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:finished, Emulator.t(), State.t()}
          | {:incomplete, Emulator.t(), State.t()}
  def handle(
        emulator,
        %State{state: :dcs_passthrough} = parser_state,
        input
      ) do
    case input do
      <<>> ->
        # Incomplete DCS string - return current state
        Raxol.Core.Runtime.Log.debug(
          "[Parser] Incomplete DCS string, input ended."
        )

        {:incomplete, emulator, parser_state}

      # String Terminator (ST - ESC \) -- Use escape_char check first
      <<27, rest_after_esc::binary>> ->
        {:continue, emulator,
         %{parser_state | state: :dcs_passthrough_maybe_st}, rest_after_esc}

      # Collect payload bytes (>= 0x20), excluding DEL (0x7F)
      <<byte, rest_after_byte::binary>> when byte >= 0x20 and byte != 0x7F ->
        next_parser_state = %{
          parser_state
          | payload_buffer: parser_state.payload_buffer <> <<byte>>
        }

        {:continue, emulator, next_parser_state, rest_after_byte}

      # CAN/SUB abort DCS passthrough
      <<abort_byte, rest_after_abort::binary>>
      when abort_byte == 0x18 or abort_byte == 0x1A ->
        Raxol.Core.Runtime.Log.debug("Aborting DCS Passthrough due to CAN/SUB")
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_abort}

      # Ignore C0 bytes (0x00-0x1F) and DEL (0x7F) during DCS passthrough
      # (ESC, CAN, SUB handled explicitly)
      <<_ignored_byte, rest_after_ignored::binary>> ->
        Raxol.Core.Runtime.Log.debug("Ignoring C0/DEL byte in DCS Passthrough")
        {:continue, emulator, parser_state, rest_after_ignored}
    end
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_byte(_byte, emulator, state) do
    {:ok, emulator, state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_escape(emulator, state) do
    {:ok, emulator, state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_control_sequence(emulator, state) do
    {:ok, emulator, state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_osc_string(emulator, state) do
    {:ok, emulator, state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_dcs_string(emulator, state) do
    {:ok, emulator, state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_apc_string(emulator, state) do
    {:ok, emulator, state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_pm_string(emulator, state) do
    {:ok, emulator, state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_sos_string(emulator, state) do
    {:ok, emulator, state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_unknown(emulator, state) do
    {:ok, emulator, state}
  end
end
