defmodule Raxol.Terminal.Commands.Executor do
  @moduledoc """
  Executes parsed terminal commands (CSI, OSC, DCS).

  This module takes parsed command details and the current emulator state,
  and returns the updated emulator state after applying the command's effects.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Commands.Parser
  alias Raxol.Terminal.Commands.CSIHandlers
  alias Raxol.Terminal.Commands.OSCHandlers
  alias Raxol.Terminal.Commands.DCSHandlers
  require Raxol.Core.Runtime.Log

  @basic_commands [?m, ?H, ?r, ?J, ?K]
  @cursor_commands [?A, ?B, ?C, ?D, ?E, ?F, ?G, ?d]
  @screen_commands [?L, ?M, ?P, ?@, ?S, ?T, ?X]
  @device_commands [?c, ?n, ?s, ?u, ?t]
  @scs_commands [?(, ?), ?*, ?+]

  @doc """
  Executes a CSI (Control Sequence Introducer) command.

  This function delegates to handler modules (e.g., CSIHandlers, CursorHandlers, etc.).
  To add support for new CSI commands, implement them in the appropriate handler module.
  """
  @spec execute_csi_command(
          Emulator.t(),
          String.t(),
          String.t(),
          non_neg_integer()
        ) :: Emulator.t()
  def execute_csi_command(
        emulator,
        params_buffer,
        intermediates_buffer,
        final_byte
      ) do
    Raxol.Core.Runtime.Log.debug(
      "[Executor.execute_csi_command] BEFORE: scroll_region=#{inspect(emulator.scroll_region)}, final_byte=#{inspect(final_byte)}"
    )

    params = Parser.parse_params(params_buffer)
    result = dispatch_csi_command(emulator, params, intermediates_buffer, final_byte, params_buffer)
    log_and_return_result(result, final_byte)
  end

  defp dispatch_csi_command(emulator, params, intermediates_buffer, final_byte, params_buffer) do
    case final_byte do
      byte when byte in @basic_commands ->
        CSIHandlers.handle_basic_command(emulator, params, byte)
      byte when byte in [?h, ?l] ->
        CSIHandlers.handle_h_or_l(emulator, params, intermediates_buffer, byte)
      byte when byte in @cursor_commands ->
        CSIHandlers.handle_cursor_command(emulator, params, byte)
      byte when byte in @screen_commands ->
        CSIHandlers.handle_screen_command(emulator, params, byte)
      byte when byte in @device_commands ->
        CSIHandlers.handle_device_command(emulator, params, intermediates_buffer, byte)
      ?q when intermediates_buffer == " " ->
        CSIHandlers.handle_q_deccusr(emulator, params)
      byte when byte in @scs_commands ->
        CSIHandlers.handle_scs(emulator, params_buffer, byte)
      _ ->
        log_unknown_csi(final_byte)
        {:error, :unhandled_csi, emulator}
    end
  end

  defp log_and_return_result(result, final_byte) do
    case result do
      {:ok, new_emulator} ->
        log_after_execution(new_emulator, final_byte)
        new_emulator
      {:error, _reason, new_emulator} ->
        log_after_execution(new_emulator, final_byte)
        new_emulator
    end
  end

  defp log_unknown_csi(final_byte) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Unknown CSI command: #{inspect(final_byte)}",
      %{}
    )
  end

  defp log_after_execution(emulator, final_byte) do
    Raxol.Core.Runtime.Log.debug(
      "[Executor.execute_csi_command] AFTER: scroll_region=#{inspect(emulator.scroll_region)}, final_byte=#{inspect(final_byte)}"
    )
  end

  @doc """
  Executes an OSC (Operating System Command).

  Params: `command_string` (the content between OSC and ST).
  """
  @spec execute_osc_command(Emulator.t(), String.t()) :: Emulator.t()
  def execute_osc_command(emulator, command_string) do
    Raxol.Core.Runtime.Log.debug("Executing OSC command: #{inspect(command_string)}")
    handle_osc_command(emulator, command_string)
  end

  defp handle_osc_command(emulator, command_string) do
    with [ps_str, pt] <- String.split(command_string, ";", parts: 2),
         {ps_code, ""} <- Integer.parse(ps_str) do
      dispatch_osc_command(emulator, ps_code, pt)
    else
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "OSC: Unexpected command format: '#{command_string}'",
          %{}
        )
        {:error, :malformed_osc, emulator}
    end
  end

  defp dispatch_osc_command(emulator, ps_code, pt) do
    case ps_code do
      0 -> OSCHandlers.handle_0_or_2(emulator, pt)
      1 -> OSCHandlers.handle_1(emulator, pt)
      2 -> OSCHandlers.handle_0_or_2(emulator, pt)
      4 -> OSCHandlers.handle_4(emulator, pt)
      7 -> OSCHandlers.handle_7(emulator, pt)
      8 -> OSCHandlers.handle_8(emulator, pt)
      52 -> OSCHandlers.handle_52(emulator, pt)
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unknown OSC command code: #{ps_code}, String: '#{pt}'",
          %{}
        )
        {:error, :unhandled_osc, emulator}
    end
  end

  @doc """
  Executes a DCS (Device Control String) command.

  Params: `params_buffer`, `intermediates_buffer`, `data_string` (content between DCS and ST).
  """
  @spec execute_dcs_command(
          Emulator.t(),
          String.t(),
          String.t(),
          String.t()
        ) :: Emulator.t()
  def execute_dcs_command(emulator, params_buffer, intermediates_buffer, data_string) do
    Raxol.Core.Runtime.Log.debug("Executing DCS command: #{inspect(data_string)}")
    handle_dcs_command(emulator, params_buffer, intermediates_buffer, data_string)
  end

  defp handle_dcs_command(emulator, params_buffer, intermediates_buffer, data_string) do
    case intermediates_buffer do
      "" ->
        DCSHandlers.handle_dcs(emulator, params_buffer, data_string)
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "DCS: Unhandled intermediate: '#{intermediates_buffer}'",
          %{}
        )
        {:error, :unhandled_dcs, emulator}
    end
  end
end
