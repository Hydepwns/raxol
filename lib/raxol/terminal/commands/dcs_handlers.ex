defmodule Raxol.Terminal.Commands.DCSHandlers do
  @moduledoc '''
  Handles Device Control String (DCS) commands for the terminal emulator.
  '''

  @doc '''
  Handles DCS commands.
  Returns {:ok, updated_emulator} or {:error, reason}.
  '''
  def handle_dcs(emulator, params, data_string) do
    case params do
      # DECRQSS - Request Status String
      [0] ->
        handle_decrqss(emulator, data_string)

      # DECDLD - Download Character Set
      [1] ->
        handle_decdld(emulator, data_string)

      _ ->
        {:error, :unknown_dcs, emulator}
    end
  end

  defp handle_decrqss(emulator, data_string) do
    case data_string do
      # SGR
      "m" ->
        {:ok, %{emulator | output_buffer: "\x1b[0m"}}

      # DECSTBM
      "r" ->
        {:ok, %{emulator | output_buffer: "\x1b[r"}}

      _ ->
        {:error, :unhandled_decrqss, emulator}
    end
  end

  defp handle_decdld(emulator, _data_string) do
    {:error, :decdld_not_implemented, emulator}
  end
end
