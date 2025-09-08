defmodule Raxol.Terminal.Commands.CSIHandler.Main do
  @moduledoc """
  Main coordinator module for CSI (Control Sequence Introducer) commands.
  Routes commands to the appropriate handler modules.
  """

  alias Raxol.Terminal.Commands.CSIHandler.{Basic, Cursor, Screen, Device}

  @doc """
  Handles CSI commands by routing them to the appropriate handler module.
  """
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
    command_checkers = [
      {&basic_command?/1, :basic},
      {&cursor_command?/1, :cursor},
      {&screen_command?/1, :screen},
      {&device_command?/1, :device}
    ]

    Enum.find_value(command_checkers, nil, fn {checker, type} ->
      case checker.(byte) do
        true -> {type, byte}
        false -> nil
      end
    end)
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
