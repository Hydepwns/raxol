defmodule Raxol.Terminal.Commands.DeviceHandler do
  @moduledoc """
  Handles device-specific terminal commands like Device Attributes (DA) and Device Status Report (DSR).
  This module provides direct implementations.
  """

  @doc """
  Handles Device Attributes (DA) request - CSI c command.

  Primary DA (CSI 0 c or CSI c): Reports terminal capabilities
  Secondary DA (CSI > 0 c): Reports terminal version and features
  """
  def handle_c(emulator, params, intermediates \\ "") do
    case {intermediates, params} do
      {">", []} ->
        # CSI > c (Secondary DA)
        response = "\e[>0;0;0c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      {">", [0]} ->
        # CSI > 0 c (Secondary DA)
        response = "\e[>0;0;0c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      {"", []} ->
        # CSI c (Primary DA)
        response = "\e[?6c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      {"", [0]} ->
        # CSI 0 c (Primary DA)
        response = "\e[?6c"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      _ ->
        # Ignore all other params
        {:ok, emulator}
    end
  end

  @doc """
  Handles Device Status Report (DSR) request - CSI n command.

  CSI 5 n: Device Status Report - reports "OK" status
  CSI 6 n: Cursor Position Report - reports current cursor position
  """
  def handle_n(emulator, params) do
    case params do
      [5] ->
        # DSR 5n - Report device status (OK)
        response = "\e[0n"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      [] ->
        # DSR with no parameters - Report device status (OK)
        response = "\e[0n"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      [6] ->
        # DSR 6n - Report cursor position
        response = "\e[#{emulator.cursor.row + 1};#{emulator.cursor.col + 1}R"
        {:ok, %{emulator | output_buffer: emulator.output_buffer <> response}}

      _ ->
        # Unknown parameter, ignore
        {:ok, emulator}
    end
  end
end
