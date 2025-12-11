defmodule Raxol.Terminal.Input.ControlSequenceHandler do
  @moduledoc """
  Handles various control sequences for the terminal emulator.
  Includes CSI, OSC, DCS, PM, and APC sequence handling.
  """

  alias Raxol.Terminal.Commands.{CSIHandler, OSCHandler}

  require Raxol.Core.Runtime.Log

  @doc """
  Handles a CSI (Control Sequence Introducer) sequence.
  """
  def handle_csi_sequence(emulator, command, params) do
    CSIHandler.handle_csi_sequence(emulator, command, params)
  end

  @doc """
  Handles an OSC (Operating System Command) sequence.
  """
  def handle_osc_sequence(emulator, command, data) do
    OSCHandler.handle_osc_sequence(emulator, command, data)
  end

  @doc """
  Handles a DCS (Device Control String) sequence.
  """
  def handle_dcs_sequence(emulator, command, data) do
    case command do
      # Sixel graphics
      "q" ->
        handle_sixel_graphics(emulator, data)

      # DECRQSS (Request Status String)
      "r" ->
        handle_status_string_request(emulator, data)

      # Unknown DCS command
      _ ->
        Raxol.Core.Runtime.Log.debug(
          "Unhandled DCS command: #{command} with data: #{inspect(data)}"
        )

        emulator
    end
  end

  @doc """
  Handles a PM (Privacy Message) sequence.
  """
  def handle_pm_sequence(emulator, command, data) do
    # PM sequences are typically ignored by terminals
    Raxol.Core.Runtime.Log.debug(
      "Ignoring PM sequence: #{command} with data: #{inspect(data)}"
    )

    emulator
  end

  @doc """
  Handles an APC (Application Program Command) sequence.
  """
  def handle_apc_sequence(emulator, command, data) do
    # APC sequences are typically ignored by terminals
    Raxol.Core.Runtime.Log.debug(
      "Ignoring APC sequence: #{command} with data: #{inspect(data)}"
    )

    emulator
  end

  # Private helper functions for DCS handlers

  defp handle_sixel_graphics(emulator, data) do
    # Basic Sixel graphics handling - currently just logs and returns
    # Full implementation will be added in a future update
    Raxol.Core.Runtime.Log.info(
      "Sixel graphics received: #{byte_size(data)} bytes"
    )

    emulator
  end

  defp handle_status_string_request(emulator, data) do
    # Handle DECRQSS (Request Status String) command
    case data do
      # SGR (Select Graphic Rendition)
      "m" ->
        response = "\eP1$r#{emulator.style}\e\\"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      # DECSTBM (Set Top and Bottom Margins)
      "r" ->
        {top, bottom} = emulator.scroll_region
        response = "\eP1$r#{top};#{bottom}r\e\\"
        %{emulator | output_buffer: emulator.output_buffer <> response}

      _ ->
        emulator
    end
  end
end
