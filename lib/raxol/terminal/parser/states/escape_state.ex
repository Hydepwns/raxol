defmodule Raxol.Terminal.Parser.States.EscapeState do
  @moduledoc """
  Handles the :escape state of the terminal parser.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Parser.State
  require Raxol.Core.Runtime.Log

  @behaviour Raxol.Terminal.Parser.StateBehaviour

  @impl Raxol.Terminal.Parser.StateBehaviour

  @doc """
  Processes input when the parser is in the :escape state.
  """
  @spec handle(Emulator.t(), State.t(), binary()) ::
          {:continue, Emulator.t(), State.t(), binary()}
          | {:handled, Emulator.t()}
  def handle(emulator, %State{state: :escape} = parser_state, input) do
    case input do
      # Handle CAN/SUB bytes first (abort sequence)
      <<ignored_byte, rest_after_ignored::binary>>
      when ignored_byte == 0x18 or ignored_byte == 0x1A ->
        Raxol.Core.Runtime.Log.debug(
          "Ignoring CAN/SUB byte during Escape state"
        )

        # Abort sequence, go to ground
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_ignored}

      # Handle CSI sequence
      <<"[", rest_after_csi::binary>> ->
        next_parser_state = %{parser_state | state: :csi_entry}
        {:continue, emulator, next_parser_state, rest_after_csi}

      # Handle DCS sequence
      <<"P", rest_after_dcs::binary>> ->
        next_parser_state = %{parser_state | state: :dcs_entry}
        {:continue, emulator, next_parser_state, rest_after_dcs}

      # Handle OSC sequence
      <<"]", rest_after_osc::binary>> ->
        next_parser_state = %{parser_state | state: :osc_string}
        {:continue, emulator, next_parser_state, rest_after_osc}

      # Handle PM sequence
      <<"^", rest_after_pm::binary>> ->
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_pm}

      # Handle APC sequence
      <<"_", rest_after_apc::binary>> ->
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_apc}

      # Handle SS3 sequence
      <<"O", rest_after_ss3::binary>> ->
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_ss3}

      # Handle unhandled escape sequence bytes
      <<_unhandled_byte, rest_after_unhandled::binary>> ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unhandled escape sequence byte: #{inspect(_unhandled_byte)}",
          %{}
        )

        # Go to ground state
        next_parser_state = %{parser_state | state: :ground}
        {:continue, emulator, next_parser_state, rest_after_unhandled}

      # Handle incomplete sequence
      <<>> ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Incomplete escape sequence",
          %{}
        )

        # Stay in escape state
        {:incomplete, emulator, parser_state}
    end
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

      # Other bytes
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unhandled escape sequence byte: #{inspect(byte)}",
          %{}
        )

        {:ok, emulator, %{state | state: :ground}}
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
