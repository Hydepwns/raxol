defmodule Raxol.Terminal.Commands.CSIHandlers.Main do
  @moduledoc '''
  Main coordinator module for CSI (Control Sequence Introducer) commands.
  Routes commands to the appropriate handler modules.
  '''

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.CSIHandlers.{Basic, Cursor, Screen, Device}

  @doc '''
  Handles CSI commands by routing them to the appropriate handler module.
  '''
  def handle_command(emulator, params, intermediates_buffer, byte) do
    case route_command(byte) do
      {:basic, cmd} ->
        Basic.handle_command(emulator, params, cmd)

      {:cursor, cmd} ->
        Cursor.handle_command(emulator, params, cmd)

      {:screen, cmd} ->
        Screen.handle_command(emulator, params, cmd)

      {:device, cmd} ->
        Device.handle_command(emulator, params, intermediates_buffer, cmd)

      nil ->
        {:ok, emulator}
    end
  end

  defp route_command(byte) do
    cond do
      basic_command?(byte) -> {:basic, byte}
      cursor_command?(byte) -> {:cursor, byte}
      screen_command?(byte) -> {:screen, byte}
      device_command?(byte) -> {:device, byte}
      true -> nil
    end
  end

  defp basic_command?(byte) do
    byte in [?m, ?H, ?r, ?J, ?K]
  end

  defp cursor_command?(byte) do
    byte in [?A, ?B, ?C, ?D, ?E, ?F, ?G, ?d]
  end

  defp screen_command?(byte) do
    byte in [?L, ?M, ?P, ?@, ?S, ?T, ?X]
  end

  defp device_command?(byte) do
    byte in [?c, ?n, ?s, ?u, ?t]
  end
end
