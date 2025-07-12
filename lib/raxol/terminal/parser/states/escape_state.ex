defmodule Raxol.Terminal.Parser.States.EscapeState do
  @moduledoc """
  Handles the :escape state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  require Raxol.Core.Runtime.Log
  require Logger

  @behaviour Raxol.Terminal.Parser.StateBehaviour

  @impl Raxol.Terminal.Parser.StateBehaviour

  @doc """
  Processes input when the parser is in the :escape state.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:handled, Emulator.t()}
  def handle(emulator, _parser_state, <<"[", rest::binary>>) do
    require Logger
    Logger.debug("EscapeState.handle: Detected CSI, rest=#{inspect(rest)}")

    case rest do
      <<final_byte, rest2::binary>> when final_byte in ?@..?~ ->
        # No params, direct CSI final byte
        Logger.debug(
          "EscapeState.handle: CSI with no params, final_byte=#{inspect(final_byte)}"
        )

        # Build a parser state for CSI param with empty params_buffer
        csi_parser_state = %Raxol.Terminal.Parser.State{
          state: :csi_param,
          params_buffer: ""
        }

        # Call CSIParamState.handle directly
        Raxol.Terminal.Parser.States.CSIParamState.handle(
          emulator,
          csi_parser_state,
          <<final_byte, rest2::binary>>
        )

      _ ->
        # Existing logic: transition to CSIEntryState for param accumulation
        next_parser_state = %Raxol.Terminal.Parser.State{state: :csi_entry}
        {:continue, emulator, next_parser_state, rest}
    end
  end

  def handle(emulator, %State{state: :escape} = parser_state, input) do
    Logger.debug(
      "EscapeState.handle: input=#{inspect(input)}, parser_state=#{inspect(parser_state)}"
    )

    dispatch_escape_input(input, emulator, parser_state)
  end

  defp dispatch_escape_input(
         <<ignored_byte, rest::binary>>,
         emulator,
         parser_state
       )
       when ignored_byte == 0x18 or ignored_byte == 0x1A do
    Raxol.Core.Runtime.Log.debug("Ignoring CAN/SUB byte during Escape state")
    next_parser_state = %{parser_state | state: :ground}
    {:continue, emulator, next_parser_state, rest}
  end

  defp dispatch_escape_input(<<"P", rest::binary>>, emulator, parser_state) do
    next_parser_state = %{parser_state | state: :dcs_entry}
    {:continue, emulator, next_parser_state, rest}
  end

  defp dispatch_escape_input(<<"]", rest::binary>>, emulator, parser_state) do
    next_parser_state = %{parser_state | state: :osc_string}
    {:continue, emulator, next_parser_state, rest}
  end

  defp dispatch_escape_input(<<"^", rest::binary>>, emulator, parser_state) do
    next_parser_state = %{parser_state | state: :ground}
    {:continue, emulator, next_parser_state, rest}
  end

  defp dispatch_escape_input(<<"_", rest::binary>>, emulator, parser_state) do
    next_parser_state = %{parser_state | state: :ground}
    {:continue, emulator, next_parser_state, rest}
  end

  defp dispatch_escape_input(<<"O", rest::binary>>, emulator, parser_state) do
    next_parser_state = %{parser_state | state: :ground}
    {:continue, emulator, next_parser_state, rest}
  end

  defp dispatch_escape_input(<<byte, rest::binary>>, emulator, parser_state) do
    new_emulator = Raxol.Terminal.ControlCodes.handle_escape(emulator, byte)
    next_parser_state = %{parser_state | state: :ground}
    {:continue, new_emulator, next_parser_state, rest}
  end

  defp dispatch_escape_input(<<>>, emulator, parser_state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Incomplete escape sequence",
      %{}
    )

    {:incomplete, emulator, parser_state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_byte(byte, emulator, state) do
    case byte do
      # CAN/SUB bytes
      0x18..0x1A ->
        {:ok, emulator, %{state | state: :ground}}

      # CSI sequence
      ?[ ->
        {:ok, emulator, %{state | state: :csi_entry}}

      # DCS sequence
      ?P ->
        {:ok, emulator, %{state | state: :dcs_entry}}

      # OSC sequence
      ?] ->
        {:ok, emulator, %{state | state: :osc_string}}

      # PM sequence
      ?^ ->
        {:ok, emulator, %{state | state: :ground}}

      # APC sequence
      ?_ ->
        {:ok, emulator, %{state | state: :ground}}

      # SS3 sequence
      ?O ->
        {:ok, emulator, %{state | state: :ground}}

      # Simple escape sequences (DECSC, DECRC, etc.)
      byte ->
        # Process the escape sequence byte as a control code
        new_emulator = Raxol.Terminal.ControlCodes.handle_escape(emulator, byte)
        {:ok, new_emulator, %{state | state: :ground}}
    end
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_escape(emulator, state) do
    {:ok, emulator, state}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_control_sequence(emulator, state) do
    {:ok, emulator, %{state | state: :control_sequence}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_osc_string(emulator, state) do
    {:ok, emulator, %{state | state: :osc_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_dcs_string(emulator, state) do
    {:ok, emulator, %{state | state: :dcs_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_apc_string(emulator, state) do
    {:ok, emulator, %{state | state: :apc_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_pm_string(emulator, state) do
    {:ok, emulator, %{state | state: :pm_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_sos_string(emulator, state) do
    {:ok, emulator, %{state | state: :sos_string}}
  end

  @impl Raxol.Terminal.Parser.StateBehaviour
  def handle_unknown(emulator, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "EscapeState received unknown command",
      %{emulator: emulator, state: state}
    )

    {:ok, emulator, %{state | state: :ground}}
  end
end
